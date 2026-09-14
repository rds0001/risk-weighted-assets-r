# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

COMMON_COLUMNS <- c(
  "record_id", "business_key", "version_no", "as_of_date", "valid_from",
  "valid_to", "known_from", "known_to", "is_official", "record_status"
)

table_contracts <- function() {
  path <- package_resource("extdata", "canonical", "table_contracts.rds")
  if (!file.exists(path)) abort_resource("Bundled table contracts are missing")
  readRDS(path)
}

canonical_date_columns <- c(
  "as_of_date", "valid_from", "valid_to", "start_date", "maturity_date",
  "npe_classification_date", "valuation_date", "event_date", "booking_date",
  "issue_date", "next_repricing_date", "payment_date", "repricing_date",
  "validation_date", "legal_opinion_date", "publication_date", "application_date"
)

canonical_datetime_columns <- c("known_from", "known_to", "approved_at")

excel_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  numeric <- suppressWarnings(as.numeric(x))
  parsed <- rep(as.Date(NA), length(x))
  numeric_like <- if (is.numeric(x)) rep(TRUE, length(x)) else
    grepl("^[0-9]+([.][0-9]+)?$", as.character(x))
  numeric_mask <- !is.na(numeric) & numeric_like
  parsed[numeric_mask] <- as.Date(numeric[numeric_mask], origin = "1899-12-30")
  text_mask <- !numeric_mask & !is.na(x) & nzchar(trimws(as.character(x)))
  parsed[text_mask] <- suppressWarnings(as.Date(as.character(x[text_mask])))
  parsed
}

excel_datetime <- function(x) {
  if (inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
  numeric <- suppressWarnings(as.numeric(x))
  out <- rep(as.POSIXct(NA, tz = "UTC"), length(x))
  numeric_like <- if (is.numeric(x)) rep(TRUE, length(x)) else
    grepl("^[0-9]+([.][0-9]+)?$", as.character(x))
  numeric_mask <- !is.na(numeric) & numeric_like
  out[numeric_mask] <- as.POSIXct(numeric[numeric_mask] * 86400,
                                  origin = "1899-12-30", tz = "UTC")
  text_mask <- !numeric_mask & !is.na(x) & nzchar(trimws(as.character(x)))
  out[text_mask] <- suppressWarnings(as.POSIXct(as.character(x[text_mask]), tz = "UTC"))
  out
}

normalize_canonical_table <- function(frame) {
  for (field in intersect(names(frame), canonical_date_columns)) frame[[field]] <- excel_date(frame[[field]])
  for (field in intersect(names(frame), canonical_datetime_columns)) frame[[field]] <- excel_datetime(frame[[field]])
  if ("is_official" %in% names(frame)) {
    frame$is_official <- if (is.logical(frame$is_official)) frame$is_official else
      toupper(trimws(as.character(frame$is_official))) %in% c("TRUE", "1", "YES", "JA")
  }
  frame
}

validation_issue <- function(severity, code, table = "", row_ref = "",
                             field = "", message = "") {
  new_validation_message(severity, code, table, row_ref, field, message)
}

validate_tables_internal <- function(tables) {
  contracts <- table_contracts()
  issues <- list()
  add <- function(issue) issues[[length(issues) + 1L]] <<- issue
  for (logical_name in names(contracts)) {
    frame <- tables[[logical_name]]
    if (is.null(frame)) next
    spec <- contracts[[logical_name]]
    if (isTRUE(spec$required) && nrow(frame) == 0L) {
      add(validation_issue("WARNING", "EMPTY_TABLE", logical_name,
                           message = "Table is empty; module may be not applicable"))
    }
    if (!nrow(frame)) next
    mandatory <- unique(c("record_id", "business_key", "version_no", "as_of_date",
                          "valid_from", "known_from", "is_official", "record_status",
                          spec$columns[[length(COMMON_COLUMNS) + 1L]]))
    for (field in intersect(mandatory, names(frame))) {
      missing <- is.na(frame[[field]]) | !nzchar(trimws(as.character(frame[[field]])))
      for (i in head(which(missing), 20L)) {
        add(validation_issue("ERROR", "MISSING_REQUIRED_VALUE", logical_name,
                             as.character(frame$record_id[[i]] %||% ""), field,
                             "Required value is missing"))
      }
    }
    if ("record_id" %in% names(frame)) {
      duplicate <- duplicated(frame$record_id) | duplicated(frame$record_id, fromLast = TRUE)
      for (i in head(which(duplicate), 20L)) {
        add(validation_issue("ERROR", "DUPLICATE_KEY", logical_name,
                             as.character(frame$record_id[[i]]), "record_id",
                             "Key is not unique"))
      }
    }
    if ("version_no" %in% names(frame) && anyNA(suppressWarnings(as.numeric(frame$version_no)))) {
      add(validation_issue("ERROR", "INVALID_VERSION", logical_name,
                           field = "version_no", message = "Version must be numeric"))
    }
    if (all(c("valid_from", "valid_to") %in% names(frame))) {
      from <- excel_date(frame$valid_from); to <- excel_date(frame$valid_to)
      invalid <- !is.na(to) & !is.na(from) & to <= from
      for (i in head(which(invalid), 20L)) {
        add(validation_issue("ERROR", "INVALID_VALIDITY_INTERVAL", logical_name,
                             as.character(frame$record_id[[i]] %||% ""), "valid_to",
                             "valid_to must be later than valid_from"))
      }
    }
  }
  references <- list(
    c("exposure_lot", "party_id", "party", "party_id"),
    c("exposure_lot", "contract_id", "product_contract", "contract_id"),
    c("sa_classification", "exposure_id", "exposure_lot", "exposure_id"),
    c("irb_parameter", "exposure_id", "exposure_lot", "exposure_id"),
    c("protection_allocation", "exposure_id", "exposure_lot", "exposure_id"),
    c("derivative_trade", "netting_set_id", "netting_set", "netting_set_id"),
    c("securitisation_tranche", "pool_id", "securitisation_pool", "pool_id"),
    c("cashflow", "contract_id", "product_contract", "contract_id")
  )
  for (ref in references) {
    child <- tables[[ref[[1L]]]]; parent <- tables[[ref[[3L]]]]
    if (is.null(child) || is.null(parent) || !nrow(child)) next
    missing <- setdiff(as.character(stats::na.omit(child[[ref[[2L]]]])),
                       as.character(stats::na.omit(parent[[ref[[4L]]]])))
    for (key in head(sort(unique(missing)), 50L)) {
      add(validation_issue("ERROR", "BROKEN_REFERENCE", ref[[1L]], key, ref[[2L]],
                           sprintf("No %s.%s=%s", ref[[3L]], ref[[4L]], key)))
    }
  }
  bounded <- list(
    pd_estimate = c(0, 1), pd_floor = c(0, 1), lgd_estimate = c(0, 1),
    lgd_floor = c(0, 1), correlation = c(-1, 1), ownership_share = c(0, 1),
    haircut = c(0, 1), probability = c(0, 1), weight = c(0, 1),
    eligibility_factor = c(0, 1), cet1_share = c(0, 1), tier1_share = c(0, 1),
    intra_bucket_correlation = c(-1, 1), inter_bucket_correlation = c(-1, 1),
    hedge_correlation = c(-1, 1), npe_share = c(0, 1), attachment = c(0, 1),
    detachment = c(0, 1)
  )
  for (logical_name in names(tables)) {
    frame <- tables[[logical_name]]
    if (is.null(frame) || !nrow(frame)) next
    for (field in intersect(names(bounded), names(frame))) {
      numeric <- suppressWarnings(as.numeric(frame[[field]])); limits <- bounded[[field]]
      invalid <- !is.na(frame[[field]]) & (is.na(numeric) | numeric < limits[[1L]] | numeric > limits[[2L]])
      for (i in head(which(invalid), 20L)) {
        add(validation_issue("ERROR", "VALUE_OUT_OF_RANGE", logical_name,
                             as.character(frame$record_id[[i]] %||% ""), field,
                             sprintf("Value must be in [%g, %g]", limits[[1L]], limits[[2L]])))
      }
    }
  }
  params <- tables$regulatory_parameter
  if (!is.null(params) && nrow(params)) {
    fields <- c("parameter_key", "dimension_1", "dimension_2", "rule_set_id")
    keys <- do.call(paste, c(lapply(params[fields], function(x) ifelse(is.na(x), "", as.character(x))), sep = "\037"))
    duplicate <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
    for (i in head(which(duplicate), 20L)) {
      add(validation_issue("ERROR", "DUPLICATE_PARAMETER", "regulatory_parameter",
                           as.character(params$record_id[[i]]), "parameter_key",
                           "Regulatory parameter is not unique within rule set"))
    }
  }
  run_config <- tables$run_config
  if (!is.null(run_config) && nrow(run_config)) {
    required <- c("as_of_date", "knowledge_time", "consolidation_scope_id",
                  "rule_set_id", "reporting_currency")
    present <- as.character(stats::na.omit(run_config$config_key))
    for (key in sort(setdiff(required, present))) {
      add(validation_issue("ERROR", "MISSING_RUN_CONFIG", "run_config",
                           field = "config_key", message = paste("Run parameter missing:", key)))
    }
    for (key in sort(unique(present[duplicated(present) | duplicated(present, fromLast = TRUE)]))) {
      add(validation_issue("ERROR", "DUPLICATE_RUN_CONFIG", "run_config", key,
                           "config_key", "Run parameter is ambiguous"))
    }
  }
  tranches <- tables$securitisation_tranche
  if (!is.null(tranches) && nrow(tranches)) {
    invalid <- suppressWarnings(as.numeric(tranches$attachment)) >= suppressWarnings(as.numeric(tranches$detachment))
    for (i in head(which(invalid), 20L)) {
      add(validation_issue("ERROR", "INVALID_TRANCHE_BOUNDS", "securitisation_tranche",
                           as.character(tranches$record_id[[i]]), "attachment,detachment",
                           "A must be less than D"))
    }
  }
  sensitivities <- tables$market_sensitivity
  if (!is.null(sensitivities) && nrow(sensitivities)) {
    invalid <- as.character(sensitivities$measure) == "CURVATURE" &
      (is.na(sensitivities$curvature_up) | is.na(sensitivities$curvature_down))
    for (i in head(which(invalid), 20L)) {
      add(validation_issue("ERROR", "MISSING_CURVATURE_REVALUATION", "market_sensitivity",
                           as.character(sensitivities$record_id[[i]]), "curvature_up,curvature_down",
                           "Curvature requires up and down revaluation"))
    }
  }
  issues
}

select_official_as_of <- function(frame, as_of_date, knowledge_time) {
  if (!nrow(frame)) return(frame)
  frame <- normalize_canonical_table(frame)
  as_of <- as.Date(as_of_date)
  known <- as.POSIXct(knowledge_time, tz = "UTC")
  mask <- !is.na(frame$is_official) & frame$is_official &
    (is.na(frame$valid_from) | frame$valid_from <= as_of) &
    (is.na(frame$valid_to) | frame$valid_to > as_of) &
    (is.na(frame$known_from) | frame$known_from <= known) &
    (is.na(frame$known_to) | frame$known_to > known) &
    !(frame$record_status %in% c("CANCELLED", "SUPERSEDED"))
  selected <- frame[mask, , drop = FALSE]
  if (!nrow(selected)) return(selected)
  ordering <- order(selected$business_key, suppressWarnings(as.numeric(selected$version_no)),
                    selected$known_from, na.last = TRUE)
  selected <- selected[ordering, , drop = FALSE]
  selected <- selected[!duplicated(selected$business_key, fromLast = TRUE), , drop = FALSE]
  rownames(selected) <- NULL
  selected
}
