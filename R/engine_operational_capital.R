# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

calculate_operational <- function(t, ctx, out) {
  p <- ctx$parameters; b <- t$business_indicator_item
  years <- tail(sort(unique(as.numeric(stats::na.omit(b$financial_year)))),
                as.integer(parameter_get(p, "BIC", "HISTORY_YEARS")))
  values <- function(kind) {
    subset <- b[as.character(b$bi_item_type) == kind, , drop = FALSE]
    vapply(years, function(year) {
      hit <- subset$amount[as.numeric(subset$financial_year) == year]
      if (length(hit)) rwa_num(hit[[1L]]) else 0
    }, numeric(1))
  }
  bic <- bic_from_components(
    values("INTEREST_INCOME"), values("INTEREST_EXPENSE"), values("INTEREST_EARNING_ASSETS"),
    values("DIVIDEND_INCOME"), values("OTHER_OPERATING_INCOME"), values("OTHER_OPERATING_EXPENSE"),
    values("FEE_INCOME"), values("FEE_EXPENSE"), values("TRADING_BOOK_PNL"),
    values("BANKING_BOOK_PNL"), p)
  ilm <- parameter_get(p, "OPRISK", "EU_ILM")
  out$results$Operational_Risk <- data.frame(
    years = paste(years, collapse = ","), ildc = unname(bic["ildc"]), sc = unname(bic["sc"]),
    fc = unname(bic["fc"]), bi = unname(bic["bi"]), bic = unname(bic["bic"]), ilm_eu = ilm,
    capital_requirement = unname(bic["bic"]) * ilm,
    rwea = parameter_get(p, "RWA_MULTIPLIER", "PILLAR1") * unname(bic["bic"]) * ilm,
    formula_id = "OPRISK_BIC", stringsAsFactors = FALSE)
  out$metrics$K_OPERATIONAL <- unname(bic["bic"])
  invisible(out)
}

calculate_trea <- function(ctx, out, fully_loaded = FALSE) {
  p <- ctx$parameters; rwa_factor <- parameter_get(p, "RWA_MULTIPLIER", "PILLAR1")
  credit_actual <- sum(vapply(c("RWEA_KSA", "RWEA_IRB", "RWEA_CRYPTO", "RWEA_CCR", "RWEA_SFT",
                                "RWEA_CCP", "RWEA_SECURITISATION"),
                              function(k) rwa_num(out$metrics[[k]]), numeric(1)))
  credit_shadow <- sum(vapply(c("RWEA_KSA_SHADOW_ALL", "RWEA_CRYPTO", "RWEA_CCR", "RWEA_SFT",
                                "RWEA_CCP", "RWEA_SECURITISATION"),
                              function(k) rwa_num(out$metrics[[k]]), numeric(1)))
  k_market <- rwa_num(out$metrics[[if (fully_loaded) "K_MARKET_FRTB" else "K_MARKET_LEGACY"]])
  k_cva <- rwa_num(out$metrics[[if (fully_loaded) "K_CVA_SA" else "K_CVA"]])
  other_k <- k_market + k_cva + rwa_num(out$metrics$K_SETTLEMENT) +
    rwa_num(out$metrics$K_LARGE_EXPOSURE) + rwa_num(out$metrics$K_OPERATIONAL)
  u <- credit_actual + rwa_factor * other_k; s <- credit_shadow + rwa_factor * other_k
  floor_result <- output_floor(u, s, ctx$output_floor_factor, FALSE,
                               parameter_get(p, "OUTPUT_FLOOR", "OPTIONAL_CAP"))
  out$metrics$U_TREA <- u; out$metrics$S_TREA <- s
  out$metrics$OUTPUT_FLOOR_FACTOR <- ctx$output_floor_factor
  out$metrics$TREA <- floor_result$trea; out$metrics$FLOOR_UPLIFT <- floor_result$uplift
  out$metrics$FLOOR_BINDING <- floor_result$binding
  out$results$TREA_Summary <- data.frame(
    view = if (fully_loaded) "FULLY_LOADED" else "APPLIED",
    credit_rwea_actual = credit_actual, credit_rwea_shadow = credit_shadow,
    other_k = other_k, u_trea = u, s_trea = s, floor_factor = ctx$output_floor_factor,
    floor_base = ctx$output_floor_factor * s, floor_uplift = floor_result$uplift,
    floor_binding = floor_result$binding, trea = floor_result$trea,
    formula_id = "OUTPUT_FLOOR", stringsAsFactors = FALSE)
  components <- list(CREDIT = c(u = credit_actual, s = credit_shadow),
                     MARKET_AND_OTHER = c(u = rwa_factor * other_k, s = rwa_factor * other_k))
  gaps <- vapply(components, function(x) max(ctx$output_floor_factor * x[["s"]] - x[["u"]], 0), numeric(1))
  total_gap <- sum(gaps)
  out$results$Floor_Allocation <- rows_frame(lapply(names(components), function(k) {
    x <- components[[k]]; weight <- if (total_gap) gaps[[k]] / total_gap else 0
    list(component = k, u_trea_component = x[["u"]], s_trea_component = x[["s"]],
         positive_gap = gaps[[k]], allocation_weight = weight,
         allocated_floor_uplift = floor_result$uplift * weight, formula_id = "OUTPUT_FLOOR")
  }))
  expected <- max(u, ctx$output_floor_factor * s)
  add_control(out, "OUTPUT_FLOOR",
              abs(floor_result$trea - expected) < parameter_get(p, "CONTROL", "ABSOLUTE_TOLERANCE_EUR"),
              expected, floor_result$trea, "Output floor identity")
  invisible(out)
}

calculate_capital <- function(t, ctx, out) {
  p <- ctx$parameters; exp <- t$exposure_lot
  re_df <- t$real_estate_exposure[, c("exposure_id", "property_type"), drop = FALSE]
  npe_base <- exp[vapply(exp$npe_flag, rwa_bool, logical(1)), , drop = FALSE]
  npe <- merge(npe_base, re_df, by = "exposure_id", all.x = TRUE, sort = FALSE)
  npe_rows <- lapply(seq_len(nrow(npe)), function(i) {
    r <- npe[i, , drop = FALSE]
    classification <- if (is.na(r$npe_classification_date)) ctx$as_of_date else as.Date(r$npe_classification_date)
    year <- max(as.integer(as.numeric(ctx$as_of_date - classification) /
                             parameter_get(p, "TIME_CONVENTION", "DAYS_PER_YEAR")) + 1L, 1L)
    gross <- rwa_num(r$gross_carrying_amount); property_secured <- !is.na(r$property_type)
    secured <- if (property_secured) gross * parameter_get(p, "NPE", "PROPERTY_SECURED_SHARE") else 0
    unsecured <- gross - secured
    required <- secured * npe_secured_factor(year, property_secured, p) +
      unsecured * npe_unsecured_factor(year, p)
    available <- sum(vapply(c("specific_credit_adjustments", "additional_valuation_adjustments",
                               "other_own_funds_reductions", "partial_write_offs"),
                             function(x) rwa_num(r[[x]]), numeric(1)))
    list(exposure_id = as.character(r$exposure_id), npe_year = year, secured_part = secured,
         unsecured_part = unsecured, required_coverage = required, available_coverage = available,
         npe_shortfall = max(required - available, 0), formula_id = "NPE_BACKSTOP")
  })
  npe_result <- rows_frame(npe_rows, c("exposure_id", "npe_year", "secured_part", "unsecured_part",
                                       "required_coverage", "available_coverage", "npe_shortfall", "formula_id"))
  out$results$NPE_Backstop <- npe_result; npe_deduction <- sum_column(npe_result, "npe_shortfall")
  ava <- t$valuation_adjustment
  ava_total <- if (!nrow(ava)) 0 else if (setequal(unique(as.character(ava$method)), "SIMPLIFIED")) {
    parameter_get(p, "PRUDENT_VALUATION", "SIMPLIFIED_RATE") *
      sum(abs(as.numeric(ava$fair_value)) * as.numeric(ava$cet1_impact_share), na.rm = TRUE)
  } else sum(as.numeric(ava$category_ava), na.rm = TRUE)
  out$results$Prudent_Valuation <- data.frame(
    method = if (nrow(ava)) "CORE" else "NOT_APPLICABLE",
    fair_value_scope = if (nrow(ava)) sum(abs(as.numeric(ava$fair_value)), na.rm = TRUE) else 0,
    ava_total = ava_total, formula_id = "PRUDENT_VALUATION", stringsAsFactors = FALSE)
  comp <- t$own_funds_component
  comp$signed_amount <- ifelse(is.na(as.numeric(comp$amount)), 0, as.numeric(comp$amount)) *
    ifelse(is.na(as.numeric(comp$sign)), 0, as.numeric(comp$sign))
  cet1_components <- comp[comp$capital_class == "CET1" & comp$component_type != "DEDUCTION", , drop = FALSE]
  deductions <- comp[comp$capital_class == "CET1" & comp$component_type == "DEDUCTION" & comp$component_id != "AVA", , drop = FALSE]
  cet1 <- sum(cet1_components$signed_amount) + sum(deductions$signed_amount) - ava_total -
    rwa_num(out$metrics$IRB_SHORTFALL) - npe_deduction
  instruments <- t$capital_instrument
  at1_mask <- instruments$capital_class == "AT1" & vapply(instruments$eligible_flag, rwa_bool, logical(1))
  at1 <- sum(as.numeric(instruments$carrying_amount[at1_mask]), na.rm = TRUE)
  t2_mask <- instruments$capital_class == "T2" & vapply(instruments$eligible_flag, rwa_bool, logical(1))
  t2_amounts <- vapply(which(t2_mask), function(i) {
    r <- instruments[i, , drop = FALSE]
    t2_eligible_amount(rwa_num(r$carrying_amount), rwa_num(r$first_day_final_five_years_amount),
                       if (is.na(r$maturity_date)) NULL else as.Date(r$maturity_date), ctx$as_of_date, p)
  }, numeric(1))
  eligible_general <- min(sum(as.numeric(exp$general_credit_adjustments), na.rm = TRUE),
                          parameter_get(p, "T2", "GENERAL_ADJUSTMENT_CAP") * rwa_num(out$metrics$RWEA_KSA))
  eligible_irb_excess <- min(rwa_num(out$metrics$IRB_EXCESS),
                             parameter_get(p, "T2", "IRB_EXCESS_CAP") * rwa_num(out$metrics$RWEA_IRB))
  tier2 <- sum(t2_amounts) + eligible_general + eligible_irb_excess
  tier1 <- cet1 + at1; total <- tier1 + tier2; trea <- max(rwa_num(out$metrics$TREA), 1)
  req <- t$capital_requirement
  requirement_rows <- function(kind) req[as.character(req$requirement_type) == kind, , drop = FALSE]
  rate <- function(kind, default = 0, basis = NULL) {
    x <- requirement_rows(kind)
    if (!is.null(basis)) x <- x[as.character(x$basis) == basis, , drop = FALSE]
    if (nrow(x)) rwa_num(x$rate[[1L]], default) else default
  }
  p2r_row <- requirement_rows("P2R")
  if (!nrow(p2r_row)) {
    p2r_amount <- 0; p2r <- 0; p2r_cet1_share <- parameter_get(p, "P2R_SHARE", "CET1")
    p2r_t1_share <- parameter_get(p, "P2R_SHARE", "TIER1")
  } else {
    pr <- p2r_row[1L, , drop = FALSE]; basis <- as.character(pr$basis)
    p2r_amount <- if (basis %in% c("TREA", "TREA_RATE")) rwa_num(pr$rate) * trea else rwa_num(pr$fixed_amount)
    p2r <- p2r_amount / trea
    p2r_cet1_share <- max(rwa_num(pr$cet1_share), parameter_get(p, "P2R_SHARE", "CET1"))
    p2r_t1_share <- max(rwa_num(pr$tier1_share), parameter_get(p, "P2R_SHARE", "TIER1"))
  }
  cbr <- rate("CCB", parameter_get(p, "CAPITAL_BUFFER", "CCB_DEFAULT")) + rate("CCYB") +
    max(rate("GSII"), rate("OSII")) + rate("SYRB"); p2g <- rate("P2G")
  required_cet1 <- (parameter_get(p, "CAPITAL_RATE", "CET1") + p2r_cet1_share * p2r + cbr) * trea
  required_t1 <- (parameter_get(p, "CAPITAL_RATE", "TIER1") + p2r_t1_share * p2r + cbr) * trea
  required_total <- (parameter_get(p, "CAPITAL_RATE", "TOTAL") + p2r + cbr) * trea
  leverage_exposure <- sum(as.numeric(exp$gross_carrying_amount), na.rm = TRUE) +
    sum(as.numeric(exp$committed_undrawn), na.rm = TRUE) * parameter_get(p, "LEVERAGE", "OFF_BALANCE_CCF") +
    rwa_num(out$metrics$RWEA_CCR)
  leverage_ratio <- tier1 / max(leverage_exposure, 1)
  eligible_liabilities <- sum(comp$signed_amount[comp$capital_class == "ELIGIBLE_LIABILITY"])
  eligible_mrel <- total + eligible_liabilities
  mrel_risk_req <- rate("MREL", basis = "TREA") * trea; mrel_lev_req <- rate("MREL", basis = "LEVERAGE_EXPOSURE") * leverage_exposure
  tlac_risk_req <- rate("TLAC", basis = "TREA") * trea; tlac_lev_req <- rate("TLAC", basis = "LEVERAGE_EXPOSURE") * leverage_exposure
  mrel_headroom <- if (mrel_lev_req) min(eligible_mrel - mrel_risk_req, eligible_mrel - mrel_lev_req) else eligible_mrel - mrel_risk_req
  tlac_headroom <- if (tlac_lev_req) min(eligible_mrel - tlac_risk_req, eligible_mrel - tlac_lev_req) else eligible_mrel - tlac_risk_req
  reference_rate <- parameter_get(p, "RWA_EQUIVALENT", "REFERENCE_RATE")
  out$metrics <- modifyList(out$metrics, list(
    CET1 = cet1, AT1 = at1, T2 = tier2, TIER1 = tier1, TOTAL_OWN_FUNDS = total,
    CET1_RATIO = cet1 / trea, TIER1_RATIO = tier1 / trea, TOTAL_CAPITAL_RATIO = total / trea,
    P2R_RATE = p2r, P2R_AMOUNT = p2r_amount, P2R_CET1_SHARE = p2r_cet1_share,
    P2R_TIER1_SHARE = p2r_t1_share, CBR_RATE = cbr, P2G_RATE = p2g,
    CET1_HEADROOM = cet1 - required_cet1, TIER1_HEADROOM = tier1 - required_t1,
    TOTAL_HEADROOM = total - required_total, LEVERAGE_EXPOSURE = leverage_exposure,
    LEVERAGE_RATIO = leverage_ratio, MREL_HEADROOM = mrel_headroom, TLAC_HEADROOM = tlac_headroom,
    P2R_RWA_EQUIVALENT = p2r_amount / reference_rate))
  out$results$Capital_Stack <- data.frame(
    capital_layer = c("CET1", "TIER1", "TOTAL", "P2G_TARGET"),
    available = c(cet1, tier1, total, total),
    required = c(required_cet1, required_t1, required_total, required_total + p2g * trea),
    headroom = c(cet1 - required_cet1, tier1 - required_t1, total - required_total,
                 total - required_total - p2g * trea), ratio = c(cet1, tier1, total, total) / trea,
    formula_id = "OWN_FUNDS", stringsAsFactors = FALSE)
  out$results$Parallel_Constraints <- data.frame(
    constraint = c("LEVERAGE", "MREL", "TLAC"), eligible = c(tier1, eligible_mrel, eligible_mrel),
    requirement = c(rate("LEVERAGE", parameter_get(p, "LEVERAGE", "DEFAULT_REQUIREMENT")) * leverage_exposure,
                    max(mrel_risk_req, mrel_lev_req), max(tlac_risk_req, tlac_lev_req)),
    headroom = c(tier1 - rate("LEVERAGE", parameter_get(p, "LEVERAGE", "DEFAULT_REQUIREMENT")) * leverage_exposure,
                 mrel_headroom, tlac_headroom), ratio = c(leverage_ratio, eligible_mrel / trea, eligible_mrel / trea),
    formula_id = "LEVERAGE_MREL_TLAC", stringsAsFactors = FALSE)
  out$results$RWA_Equivalents <- data.frame(
    equivalent_type = "P2R_EQUIVALENT", capital_amount = p2r_amount,
    reference_rate = reference_rate, rwa_equivalent = p2r_amount / reference_rate,
    official = FALSE, additive_to_legal_trea = FALSE, formula_id = "P2R_RWA_EQ",
    stringsAsFactors = FALSE)
  add_control(out, "CAPITAL_ORDER", cet1 <= tier1 && tier1 <= total, TRUE,
              cet1 <= tier1 && tier1 <= total, "CET1 <= T1 <= Total")
  invisible(out)
}

