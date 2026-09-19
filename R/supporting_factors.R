# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

support_fields <- function(table) {
  fields <- list(sme_supporting_eligible = NA, infrastructure_supporting_eligible = NA,
    sme_total_amount_owed_eur = NA_real_, supporting_factor_reference = "",
    supporting_factor_approved_by = "")
  if (table == "irb_parameter") return(c(list(supporting_factor_type = "NONE",
                                             supporting_factor = NA_real_), fields))
  if (table == "sa_classification") return(fields)
  list()
}

normalize_support_columns <- function(frame, table) {
  defaults <- support_fields(table)
  for (name in setdiff(names(defaults), names(frame))) frame[[name]] <- rep(defaults[[name]], nrow(frame))
  frame
}

support_number <- function(x, name, positive = FALSE) {
  if (is.logical(x) || length(x) != 1L) stop(paste(name, "must be a finite number"), call. = FALSE)
  value <- suppressWarnings(as.numeric(x))
  if (!is.finite(value) || value < 0 || (positive && value == 0)) {
    stop(paste(name, "must be finite and", if (positive) "positive" else "non-negative"), call. = FALSE)
  }
  value
}

support_rate <- function(x) {
  value <- support_number(x, "supporting factor", TRUE)
  if (value > 1) stop("supporting factor must be in (0, 1]", call. = FALSE)
  value
}

support_flag <- function(x) {
  value <- toupper(rwa_text(x))
  if (value %in% c("", "FALSE", "0", "NO", "NEIN")) return(FALSE)
  if (value %in% c("TRUE", "1", "YES", "JA")) return(TRUE)
  stop("Eligibility flags must be explicit booleans", call. = FALSE)
}

#' SME Supporting Factor under Article 501 CRR
#'
#' @param total_amount_owed_eur Positive Article 501 E* amount in EUR, including
#'   the prescribed connected-client/institution-group aggregation and residential
#'   collateral exclusion/fallback. This is not necessarily the individual EAD.
#' @param parameters Optional governed parameter table or parameter store.
#' @return Numeric weighted SME supporting factor.
#' @details This pure numeric function does not certify legal eligibility.
#'   The threshold and lower/upper rates are read from SUPPORTING_FACTOR parameters.
#' @examples
#' sme_supporting_factor(5000000)
#' @export
sme_supporting_factor <- function(total_amount_owed_eur, parameters = NULL) {
  p <- as_public_parameter_store(parameters)
  amount <- support_number(total_amount_owed_eur, "Article 501 E*", TRUE)
  threshold <- support_number(parameter_get(p, "SUPPORTING_FACTOR", "SME_THRESHOLD_EUR"), "SME threshold", TRUE)
  low <- support_rate(parameter_get(p, "SUPPORTING_FACTOR", "SME_LOWER"))
  high <- support_rate(parameter_get(p, "SUPPORTING_FACTOR", "SME_UPPER"))
  (min(amount, threshold) * low + max(amount - threshold, 0) * high) / amount
}

#' Infrastructure Supporting Factor under Article 501a CRR
#'
#' @param parameters Optional governed parameter table or parameter store.
#' @return Numeric infrastructure supporting factor.
#' @details Eligibility under all Article 501a criteria must be established
#'   separately. This function returns the configured factor, not an approval.
#' @examples
#' infrastructure_supporting_factor()
#' @export
infrastructure_supporting_factor <- function(parameters = NULL) {
  support_rate(parameter_get(as_public_parameter_store(parameters), "SUPPORTING_FACTOR", "INFRASTRUCTURE"))
}

#' Apply Credit Supporting Factors
#'
#' @param rwea Non-negative risk-weighted exposure amount before supporting factors.
#' @param sme_factor,infrastructure_factor Separate factors in (0, 1].
#' @return RWEA after multiplying the factors once.
#' @details Both factors may apply together if both sets of legal criteria are
#'   fulfilled. This arithmetic helper does not attest eligibility.
#' @examples
#' apply_credit_supporting_factors(100, 0.7619, 0.75)
#' @export
apply_credit_supporting_factors <- function(rwea, sme_factor = 1, infrastructure_factor = 1) {
  support_number(rwea, "RWEA") * support_rate(sme_factor) * support_rate(infrastructure_factor)
}

#' IRB Risk-Weighted Exposure Amount including Supporting Factors
#'
#' @param ead Non-negative exposure at default.
#' @param capital_requirement Non-negative unadjusted K rate, for example from
#'   [irb_capital_requirement()].
#' @param sme_factor,infrastructure_factor Separate factors in (0, 1].
#' @param parameters Optional governed parameter table or parameter store.
#' @return EAD times configured RWA multiplier times K times both factors.
#' @details This helper does not change K, PD, LGD or expected loss. Its caller
#'   establishes eligibility; the table calculation API requires supporting evidence.
#' @examples
#' irb_risk_weighted_assets(1000000, 0.08, infrastructure_factor = 0.75)
#' @export
irb_risk_weighted_assets <- function(ead, capital_requirement, sme_factor = 1,
                                    infrastructure_factor = 1, parameters = NULL) {
  p <- as_public_parameter_store(parameters)
  base <- support_number(ead, "EAD") * support_number(capital_requirement, "K") *
    support_number(parameter_get(p, "RWA_MULTIPLIER", "PILLAR1"), "RWA multiplier", TRUE)
  apply_credit_supporting_factors(base, sme_factor, infrastructure_factor)
}

resolve_support <- function(row, params, approach) {
  sme <- support_flag(row[["sme_supporting_eligible"]])
  infra <- support_flag(row[["infrastructure_supporting_eligible"]])
  reference <- rwa_text(row[["supporting_factor_reference"]])
  approver <- rwa_text(row[["supporting_factor_approved_by"]])
  declared <- toupper(rwa_text(row[["supporting_factor_type"]]))
  if (!nzchar(declared)) declared <- "NONE"
  supplied <- row[["supporting_factor"]]
  supplied <- if (!nzchar(rwa_text(supplied))) NULL else support_rate(supplied)
  evidence <- any(vapply(names(support_fields("sa_classification")),
    function(name) nzchar(rwa_text(row[[name]])), logical(1)))
  sf <- inf <- 1
  status <- effective_type <- "NONE"
  if (sme || infra) {
    if (support_flag(row[["default_flag"]])) stop("Supporting factors are not allowed on defaulted exposures", call. = FALSE)
    if (!nzchar(reference) || !nzchar(approver)) stop("Supporting factor requires reference and approved_by", call. = FALSE)
    cls <- rwa_text(row[[if (approach == "IRB") "irb_subclass" else "exposure_class"]])
    if (sme) {
      allowed <- startsWith(cls, "RETAIL") || cls %in% c("CORPORATE", "REAL_ESTATE")
      if (!allowed || support_flag(row[["adc_flag"]])) stop("Exposure class/ADC is not eligible for SME support", call. = FALSE)
      sales <- row[["annual_sales_eur"]]
      if (nzchar(rwa_text(sales))) {
        ceiling <- support_number(parameter_get(params, "SUPPORTING_FACTOR", "SME_SALES_MAX_EUR"), "SME turnover ceiling", TRUE)
        if (support_number(sales, "annual sales") > ceiling) stop("SME turnover exceeds the regulatory ceiling", call. = FALSE)
      }
      sf <- sme_supporting_factor(row[["sme_total_amount_owed_eur"]], params)
    }
    if (infra) {
      if (!cls %in% c("CORPORATE", "CORPORATE_SME", "SPECIALISED_LENDING")) stop("Infrastructure support requires an eligible corporate exposure class", call. = FALSE)
      inf <- infrastructure_supporting_factor(params)
    }
    effective_type <- if (sme && infra) "SME_INFRASTRUCTURE" else if (sme) "SME" else "INFRASTRUCTURE"
    if (!declared %in% c("NONE", effective_type)) stop("Declared supporting_factor_type conflicts with eligibility flags", call. = FALSE)
    if (!is.null(supplied) && abs(supplied - sf * inf) > max(1e-12, 1e-10 * max(supplied, sf * inf))) {
      stop("Supplied supporting_factor differs from the calculated factor", call. = FALSE)
    }
    status <- "VERIFIED_INPUT"
  } else if (approach == "SA" && !evidence) {
    sf <- supplied %||% 1
    effective_type <- declared
    status <- if (sf != 1) "LEGACY_SA_UNVERIFIED" else "NONE"
  } else if ((!is.null(supplied) && supplied != 1) || declared != "NONE") {
    stop("A supporting-factor reduction requires explicit eligibility", call. = FALSE)
  }
  list(sme_supporting_factor = if (status == "LEGACY_SA_UNVERIFIED") 1 else sf,
    infrastructure_supporting_factor = inf, supporting_factor = sf * inf,
    supporting_factor_type = effective_type, supporting_factor_status = status,
    supporting_factor_reference = reference, supporting_factor_approved_by = approver,
    supporting_factor_formula_id = if (status == "VERIFIED_INPUT") "CRR_501_501A" else status)
}

resolve_support_exposure <- function(tables, row, params, approach) {
  if (support_flag(row[["sme_supporting_eligible"]]) || support_flag(row[["infrastructure_supporting_eligible"]])) {
    context <- list()
    exp <- tables$exposure_lot
    matched <- exp[as.character(exp$exposure_id) == as.character(row$exposure_id), , drop = FALSE]
    if (nrow(matched) == 1L) {
      context <- as.list(matched)
      party <- tables$party
      selected <- party[as.character(party$party_id) == as.character(matched$party_id), , drop = FALSE]
      if (nrow(selected) == 1L) context$annual_sales_eur <- selected$annual_sales_eur
    }
    re <- tables$real_estate_exposure
    selected <- re[as.character(re$exposure_id) == as.character(row$exposure_id), , drop = FALSE]
    if (nrow(selected) == 1L) context$adc_flag <- selected$adc_flag
    context[names(row)] <- as.list(row)
    row <- context
  }
  resolve_support(row, params, approach)
}

support_validation_issues <- function(tables) {
  issues <- list(); params <- NULL
  for (name in c("sa_classification", "irb_parameter")) {
    frame <- tables[[name]]
    if (is.null(frame)) next
    legacy_count <- 0
    for (i in seq_len(nrow(frame))) {
      row <- as.list(frame[i, , drop = FALSE])
      result <- tryCatch({
        if (support_flag(row$sme_supporting_eligible) || support_flag(row$infrastructure_supporting_eligible)) {
          if (is.null(params)) params <- new_parameter_store(tables$regulatory_parameter)
        }
        resolve_support(row, params, if (name == "irb_parameter") "IRB" else "SA")
      }, error = function(e) e)
      if (inherits(result, "error")) {
        issues[[length(issues) + 1L]] <- validation_issue("ERROR", "INVALID_SUPPORTING_FACTOR", name,
          rwa_text(row$record_id), "supporting_factor", conditionMessage(result))
      } else {
        legacy_count <- legacy_count + as.integer(result$supporting_factor_status == "LEGACY_SA_UNVERIFIED")
      }
    }
    if (legacy_count) issues[[length(issues) + 1L]] <- validation_issue("WARNING", "LEGACY_SA_SUPPORTING_FACTOR",
      name, field = "supporting_factor", message = paste(legacy_count,
        "legacy SA rows use supplied factors without eligibility evidence; not transferred to IRB"))
  }
  issues
}
