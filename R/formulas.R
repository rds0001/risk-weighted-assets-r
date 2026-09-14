# Pure formula layer. Regulatory coefficients are read from a parameter store;
# no business data or fallback regulatory values are embedded here.
# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

RWA_EPSILON <- 1e-12

clip <- function(x, lo, hi) min(max(as.numeric(x), lo), hi)
normal_cdf <- function(x) stats::pnorm(x)
normal_ppf <- function(p) stats::qnorm(clip(p, RWA_EPSILON, 1 - RWA_EPSILON))

sa_ead <- function(gross_carrying_amount, specific_adjustments,
                   additional_valuation_adjustments,
                   other_own_funds_reductions, committed_undrawn,
                   annex_i_class, data_path,
                   net_carrying_amount_article_111 = NULL, params) {
  if (identical(data_path, "NET_ARTICLE_111")) {
    if (is.null(net_carrying_amount_article_111)) {
      stop("NET_ARTICLE_111 requires net_carrying_amount_article_111", call. = FALSE)
    }
    ead_on <- max(as.numeric(net_carrying_amount_article_111), 0)
  } else {
    ead_on <- max(as.numeric(gross_carrying_amount) - as.numeric(specific_adjustments) -
                    as.numeric(additional_valuation_adjustments) -
                    as.numeric(other_own_funds_reductions), 0)
  }
  ccf <- parameter_get(params, "SA_CCF", annex_i_class)
  ead_off <- max(as.numeric(committed_undrawn) - as.numeric(specific_adjustments), 0) * ccf
  c(ead_on = ead_on, ead_off = ead_off, ead = ead_on + ead_off)
}

sa_base_risk_weight <- function(exposure_class, cqs = NULL, short_term = FALSE,
                                transactor = FALSE, retail_eligible = FALSE,
                                defaulted = FALSE, default_coverage_ratio = 0,
                                specialised_lending_type = "", params) {
  if (isTRUE(defaulted)) {
    threshold <- parameter_get(params, "SA_RW_DEFAULT", "COVERAGE_THRESHOLD")
    return(parameter_get(params, "SA_RW_DEFAULT",
                         if (default_coverage_ratio >= threshold) "ABOVE_THRESHOLD" else "BELOW_THRESHOLD"))
  }
  if (nzchar(specialised_lending_type %||% "")) {
    return(parameter_get(params, "SPECIALISED_RW", specialised_lending_type))
  }
  if (exposure_class %in% c("RETAIL", "RETAIL_REAL_ESTATE")) {
    kind <- if (isTRUE(transactor)) "RETAIL_TRANSACTOR" else
      if (isTRUE(retail_eligible)) "RETAIL_ELIGIBLE" else "RETAIL_OTHER"
    return(parameter_get(params, "SA_RW_FIXED", kind))
  }
  if (exposure_class %in% c("CENTRAL_BANK", "CENTRAL_GOVERNMENT")) {
    exposure_class <- "CENTRAL_GOVERNMENT"
  }
  key <- if (identical(exposure_class, "INSTITUTION") && isTRUE(short_term)) "SA_RW_SHORT" else "SA_RW"
  quality <- if (!is.null(cqs) && !is.na(cqs) && cqs != 0) sprintf("CQS_%d", as.integer(cqs)) else "UNRATED"
  if (parameter_has(params, key, exposure_class, quality)) {
    return(parameter_get(params, key, exposure_class, quality))
  }
  fixed <- if (parameter_has(params, "SA_RW_FIXED", exposure_class)) exposure_class else "OTHER"
  parameter_get(params, "SA_RW_FIXED", fixed)
}

real_estate_weighted_rw <- function(ead, property_value, property_type, ipre,
                                    counterparty_rw, senior_liens = 0, adc = FALSE,
                                    params) {
  if (ead <= 0) return(list(risk_weight = 0, segments = data.frame()))
  if (isTRUE(adc)) {
    rw <- parameter_get(params, "RE_SPLIT", "ADC_RW")
    return(list(risk_weight = rw,
                segments = data.frame(segment = "ADC", amount = ead, risk_weight = rw)))
  }
  value <- max(as.numeric(property_value), RWA_EPSILON)
  etv <- (as.numeric(ead) + as.numeric(senior_liens)) / value
  if (isTRUE(ipre)) {
    if (identical(property_type, "RESIDENTIAL")) {
      bounds <- vapply(1:5, function(i) parameter_get(params, "RE_IPRE_BOUND", property_type,
                                                               paste0("BAND_", i)), numeric(1))
      labels <- c("ETV_LE_050", "ETV_LE_060", "ETV_LE_080", "ETV_LE_090", "ETV_LE_100")
      hit <- which(etv <= bounds)
      band <- if (length(hit)) labels[[hit[[1L]]]] else "ETV_GT_100"
    } else {
      bounds <- vapply(1:2, function(i) parameter_get(params, "RE_IPRE_BOUND", property_type,
                                                               paste0("BAND_", i)), numeric(1))
      band <- if (etv <= bounds[[1L]]) "ETV_LE_060" else if (etv <= bounds[[2L]]) "ETV_LE_080" else "ETV_GT_080"
    }
    rw <- parameter_get(params, "RE_IPRE_RW", property_type, band)
    return(list(risk_weight = rw,
                segments = data.frame(segment = "WHOLE_LOAN", amount = ead, risk_weight = rw)))
  }
  capacity <- max(parameter_get(params, "RE_SPLIT", "PRIVILEGED_VALUE_SHARE") * value - senior_liens, 0)
  privileged <- min(ead, capacity)
  remainder <- max(ead - privileged, 0)
  privileged_rw <- parameter_get(params, "RE_SPLIT", paste0(property_type, "_RW"))
  segments <- data.frame(segment = c("PRIVILEGED", "REMAINDER"),
                         amount = c(privileged, remainder),
                         risk_weight = c(privileged_rw, counterparty_rw))
  list(risk_weight = sum(segments$amount * segments$risk_weight) / ead, segments = segments)
}

crm_maturity_mismatch_factor <- function(t_protection, t_exposure, minimum_t, maximum_T) {
  t <- min(max(t_protection, 0), max(t_exposure, 0))
  T <- min(max(t_exposure, 0), maximum_T)
  if (t < minimum_t || T <= minimum_t) return(0)
  clip((t - minimum_t) / (T - minimum_t), 0, 1)
}

comprehensive_crm <- function(exposure, collateral, he, hc, hfx) {
  max(exposure * (1 + he) - collateral * (1 - hc - hfx), 0)
}

irb_correlation <- function(pd, annual_sales_million = NULL,
                            financial_multiplier = FALSE, params) {
  decay <- parameter_get(params, "IRB_CORP", "DECAY")
  weight <- (1 - exp(-decay * pd)) / (1 - exp(-decay))
  result <- parameter_get(params, "IRB_CORP", "R_LOW") * weight +
    parameter_get(params, "IRB_CORP", "R_HIGH") * (1 - weight)
  if (!is.null(annual_sales_million) && !is.na(annual_sales_million)) {
    low <- parameter_get(params, "IRB_CORP", "SME_SALES_MIN_M")
    high <- parameter_get(params, "IRB_CORP", "SME_SALES_MAX_M")
    sales <- clip(annual_sales_million, low, high)
    result <- result - parameter_get(params, "IRB_CORP", "SME_ADJUSTMENT") *
      (1 - (sales - low) / (high - low))
  }
  result * if (isTRUE(financial_multiplier)) parameter_get(params, "IRB_CORP", "FINANCIAL_MULTIPLIER") else 1
}

retail_correlation <- function(pd, subclass, params) {
  if (identical(subclass, "RETAIL_RESIDENTIAL")) return(parameter_get(params, "IRB_RETAIL", "RESIDENTIAL_R"))
  if (identical(subclass, "RETAIL_QRRE")) return(parameter_get(params, "IRB_RETAIL", "QRRE_R"))
  decay <- parameter_get(params, "IRB_RETAIL", "DECAY")
  weight <- (1 - exp(-decay * pd)) / (1 - exp(-decay))
  parameter_get(params, "IRB_RETAIL", "R_LOW") * weight +
    parameter_get(params, "IRB_RETAIL", "R_HIGH") * (1 - weight)
}

irb_maturity_b <- function(pd, params) {
  (parameter_get(params, "IRB_MATURITY", "A") -
     parameter_get(params, "IRB_MATURITY", "B") * log(max(pd, RWA_EPSILON)))^2
}

irb_maturity_adjustment <- function(pd, maturity, params) {
  b <- irb_maturity_b(pd, params)
  m <- clip(maturity, parameter_get(params, "IRB_MATURITY", "MIN_YEARS"),
            parameter_get(params, "IRB_MATURITY", "MAX_YEARS"))
  (1 + (m - parameter_get(params, "IRB_MATURITY", "CENTER")) * b) /
    (1 - parameter_get(params, "IRB_MATURITY", "DENOMINATOR_FACTOR") * b)
}

irb_k <- function(pd, lgd, correlation, maturity, apply_maturity_adjustment,
                  defaulted, elbe, params) {
  if (isTRUE(defaulted) || pd >= 1) return(max(lgd - elbe, 0))
  if (pd <= 0) return(0)
  z <- normal_ppf(pd) / sqrt(1 - correlation) +
    sqrt(correlation / (1 - correlation)) * normal_ppf(parameter_get(params, "IRB", "CONFIDENCE_LEVEL"))
  ul <- lgd * normal_cdf(z) - pd * lgd
  ma <- if (isTRUE(apply_maturity_adjustment)) irb_maturity_adjustment(pd, maturity, params) else 1
  max(ul * ma, 0)
}

sa_ccr_multiplier <- function(V, C, addon, params) {
  if (addon <= 0) return(1)
  floor <- parameter_get(params, "SA_CCR", "MULTIPLIER_FLOOR")
  min(1, floor + (1 - floor) * exp((V - C) / (2 * (1 - floor) * addon)))
}

sa_ccr_ead <- function(V, C, addon, alpha, params) {
  rc <- max(V - C, 0)
  multiplier <- sa_ccr_multiplier(V, C, addon, params)
  pfe <- multiplier * addon
  c(rc = rc, multiplier = multiplier, pfe = pfe, ead = alpha * (rc + pfe))
}

sft_ead <- function(cash_leg, security_value, security_haircut, fx_haircut) {
  max(cash_leg - security_value * (1 - security_haircut - fx_haircut), 0)
}

sec_k_irb <- function(rwea_pool_irb_ul, el_pool_irb, pool_ead, params) {
  if (pool_ead) (parameter_get(params, "SEC", "CAPITAL_RATE") * rwea_pool_irb_ul + el_pool_irb) / pool_ead else 0
}

sec_k_sa <- function(rwea_pool_sa, pool_ead, params) {
  if (pool_ead) parameter_get(params, "SEC", "CAPITAL_RATE") * rwea_pool_sa / pool_ead else 0
}

ssfa_k <- function(ka, attachment, detachment, p) {
  if (ka <= 0) return(0)
  a <- -1 / (p * ka)
  upper <- detachment - ka
  lower <- max(attachment - ka, 0)
  if (abs(upper - lower) < RWA_EPSILON) exp(a * upper) else
    (exp(a * upper) - exp(a * lower)) / (a * (upper - lower))
}

securitisation_ssfa_rw <- function(pool_k, attachment, detachment, p, floor, params) {
  cap <- parameter_get(params, "SEC", "RW_CAP")
  mult <- parameter_get(params, "RWA_MULTIPLIER", "PILLAR1")
  if (!(0 <= attachment && attachment < detachment && detachment <= 1)) {
    stop("Securitisation requires 0 <= A < D <= 1", call. = FALSE)
  }
  if (detachment <= pool_k) {
    rw <- cap
  } else if (attachment >= pool_k) {
    rw <- mult * ssfa_k(pool_k, attachment, detachment, p)
  } else {
    thickness <- detachment - attachment
    rw <- ((pool_k - attachment) / thickness) * cap +
      ((detachment - pool_k) / thickness) * mult * ssfa_k(pool_k, attachment, detachment, p)
  }
  clip(rw, floor, cap)
}

sec_irba_p <- function(pool_type, senior, effective_number, pool_k,
                       average_lgd, tranche_maturity, sts, params) {
  threshold <- parameter_get(params, "SEC_IRBA", "GRANULARITY_THRESHOLD")
  retail <- identical(pool_type, "RETAIL")
  granular <- effective_number >= threshold
  if (retail && !granular) stop(sprintf("SEC-IRBA retail coefficients require N >= %g", threshold), call. = FALSE)
  key <- paste0(if (retail) "RETAIL" else "NON_RETAIL",
                if (isTRUE(senior)) "_SENIOR" else "_NONSENIOR", "_NGE25")
  if (!retail && !granular) key <- sub("NGE25", "NLT25", key, fixed = TRUE)
  coefficients <- setNames(vapply(strsplit("ABCDE", "")[[1]], function(letter) {
    parameter_get(params, "SEC_IRBA_COEFF", key, letter)
  }, numeric(1)), strsplit("ABCDE", "")[[1]])
  raw <- coefficients[["A"]] + coefficients[["B"]] / effective_number +
    coefficients[["C"]] * pool_k + coefficients[["D"]] * average_lgd +
    coefficients[["E"]] * tranche_maturity
  floor <- parameter_get(params, "SEC_SSFA", "P_FLOOR")
  p <- max(floor, if (isTRUE(sts)) parameter_get(params, "SEC_SSFA", "STS_P_MULTIPLIER") * raw else raw)
  c(raw = raw, p = p)
}

sec_erba_rw <- function(cqs, maturity, senior, sts, attachment, detachment, params) {
  quality <- if (parameter_has(params, "SEC_ERBA_LONG", as.character(cqs), "NORMAL_SENIOR_1Y")) as.character(cqs) else "OTHER"
  prefix <- if (isTRUE(sts)) "STS" else "NORMAL"
  rank <- if (isTRUE(senior)) "SENIOR" else "NONSENIOR"
  one <- parameter_get(params, "SEC_ERBA_LONG", quality, paste(prefix, rank, "1Y", sep = "_"))
  five <- parameter_get(params, "SEC_ERBA_LONG", quality, paste(prefix, rank, "5Y", sep = "_"))
  minimum <- parameter_get(params, "SEC_ERBA", "MATURITY_MIN")
  maximum <- parameter_get(params, "SEC_ERBA", "MATURITY_MAX")
  bounded <- clip(maturity, minimum, maximum)
  rw <- one + (bounded - minimum) / (maximum - minimum) * (five - one)
  if (!isTRUE(senior)) {
    thickness <- detachment - attachment
    rw <- rw * (1 - min(thickness, parameter_get(params, "SEC_ERBA", "THICKNESS_CAP")))
    hypothetical_one <- parameter_get(params, "SEC_ERBA_LONG", quality, paste(prefix, "SENIOR", "1Y", sep = "_"))
    hypothetical_five <- parameter_get(params, "SEC_ERBA_LONG", quality, paste(prefix, "SENIOR", "5Y", sep = "_"))
    hypothetical <- hypothetical_one + (bounded - minimum) / (maximum - minimum) *
      (hypothetical_five - hypothetical_one)
    rw <- max(rw, parameter_get(params, "SEC_FLOOR", "NON_STS"), hypothetical)
  }
  min(rw, parameter_get(params, "SEC", "RW_CAP"))
}

securitisation_rw <- function(approach, pool_k, attachment, detachment, p,
                              sts, senior, resecuritisation, cqs, params) {
  if (approach %in% c("SEC_IRBA", "SEC_SA")) {
    floor_key <- if (isTRUE(resecuritisation)) "RESECURITISATION" else
      if (isTRUE(sts) && isTRUE(senior)) "STS" else if (isTRUE(sts)) "STS_NONSENIOR" else "NON_STS"
    return(securitisation_ssfa_rw(pool_k, attachment, detachment, p,
                                  parameter_get(params, "SEC_FLOOR", floor_key), params))
  }
  sec_erba_rw(cqs, parameter_get(params, "SEC_ERBA", "MATURITY_MIN"), TRUE,
              sts, attachment, detachment, params)
}

ba_cva_capital <- function(items, params) {
  if (is.data.frame(items)) items <- split(items, seq_len(nrow(items)))
  rho <- parameter_get(params, "BA_CVA", "RHO")
  discount_rate <- parameter_get(params, "BA_CVA", "DISCOUNT_RATE")
  alpha <- parameter_get(params, "BA_CVA", "ALPHA")
  scva_values <- numeric()
  net_values <- numeric()
  index_hedge_total <- 0
  hedge_mismatch <- 0
  for (item in items) {
    x <- unname(unlist(item, use.names = FALSE))
    if (length(x) != 9L) stop("BA-CVA item must contain nine numeric values", call. = FALSE)
    rw <- x[1]; maturity <- x[2]; ead <- x[3]; single <- x[4]
    single_maturity <- x[5]; hedge_correlation <- x[6]; index <- x[7]
    index_maturity <- x[8]; index_rw <- x[9]
    df <- if (maturity > 0) (1 - exp(-discount_rate * maturity)) / (discount_rate * maturity) else 1
    scva <- rw * maturity * ead * df / alpha
    single_df <- if (single_maturity > 0) (1 - exp(-discount_rate * single_maturity)) /
      (discount_rate * single_maturity) else 1
    index_df <- if (index_maturity > 0) (1 - exp(-discount_rate * index_maturity)) /
      (discount_rate * index_maturity) else 1
    hma <- rw * single_maturity * single * single_df / alpha
    single_hedge <- hedge_correlation * hma
    index_hedge <- index_rw * index_maturity * index * index_df / alpha
    scva_values <- c(scva_values, scva)
    net_values <- c(net_values, scva - single_hedge)
    index_hedge_total <- index_hedge_total + index_hedge
    hedge_mismatch <- hedge_mismatch + max(hma^2 - single_hedge^2, 0)
  }
  unhedged <- sqrt((rho * sum(scva_values))^2 + (1 - rho^2) * sum(scva_values^2))
  hedged <- sqrt(max((rho * sum(net_values) - index_hedge_total)^2 +
                       (1 - rho^2) * sum(net_values^2) + hedge_mismatch, 0))
  unhedged_weight <- parameter_get(params, "BA_CVA", "UNHEDGED_WEIGHT")
  unhedged_weight * unhedged + parameter_get(params, "BA_CVA", "HEDGED_WEIGHT") *
    (1 - unhedged_weight) * hedged
}

settlement_factor <- function(days_late, params) {
  bounds <- vapply(1:4, function(i) as.integer(parameter_get(params, "SETTLEMENT_BOUND", paste0("BAND_", i))), integer(1))
  band <- if (days_late <= bounds[1]) "DAYS_0_4" else if (days_late <= bounds[2]) "DAYS_5_15" else
    if (days_late <= bounds[3]) "DAYS_16_30" else if (days_late <= bounds[4]) "DAYS_31_45" else "DAYS_46_PLUS"
  parameter_get(params, "SETTLEMENT_FACTOR", band)
}

bic_from_components <- function(il, ie, assets, dividends, oi, oe, fi, fe,
                                trading_pnl, banking_pnl, params) {
  average <- function(values) sum(values) / length(values)
  ildc <- min(average(abs(il - ie)), parameter_get(params, "BIC", "ASSET_CAP") * average(assets)) + average(dividends)
  sc <- max(average(oi), average(oe)) + max(average(fi), average(fe))
  fc <- average(abs(trading_pnl)) + average(abs(banking_pnl))
  bi <- ildc + sc + fc
  billion <- parameter_get(params, "UNIT_SCALE", "EUR_BILLION")
  x <- bi / billion
  first <- parameter_get(params, "BIC", "BUCKET_1_LIMIT_BN")
  second <- parameter_get(params, "BIC", "BUCKET_2_LIMIT_BN")
  bic <- (parameter_get(params, "BIC", "COEFFICIENT_1") * min(x, first) +
            parameter_get(params, "BIC", "COEFFICIENT_2") * min(max(x - first, 0), second - first) +
            parameter_get(params, "BIC", "COEFFICIENT_3") * max(x - second, 0)) * billion
  c(ildc = ildc, sc = sc, fc = fc, bi = bi, bic = bic)
}

output_floor_factor <- function(as_of, fully_loaded, params) {
  if (isTRUE(fully_loaded)) return(parameter_get(params, "OUTPUT_FLOOR", "FULLY_LOADED"))
  year <- format(as.Date(as_of), "%Y")
  parameter_get(params, "OUTPUT_FLOOR", if (parameter_has(params, "OUTPUT_FLOOR", year)) year else "FULLY_LOADED")
}

output_floor <- function(u_trea, s_trea, factor, optional_cap, cap_multiplier) {
  uncapped <- max(u_trea, factor * s_trea)
  final <- if (isTRUE(optional_cap)) min(uncapped, cap_multiplier * u_trea) else uncapped
  list(trea = final, uplift = final - u_trea, binding = final > u_trea)
}

npe_unsecured_factor <- function(year, params) {
  last <- as.integer(parameter_get(params, "NPE_MILESTONE", "UNSECURED_LAST_INITIAL_YEAR"))
  parameter_get(params, "NPE_UNSECURED", if (year <= last) paste0("YEAR_", year) else paste0("YEAR_", last + 1, "_PLUS"))
}

npe_secured_factor <- function(year, property_security, params) {
  key <- if (isTRUE(property_security)) "NPE_SECURED_PROPERTY" else "NPE_SECURED_OTHER"
  initial <- as.integer(parameter_get(params, "NPE_MILESTONE", "SECURED_INITIAL_YEARS"))
  last <- as.integer(parameter_get(params, "NPE_MILESTONE",
                                   if (isTRUE(property_security)) "PROPERTY_LAST_YEAR" else "OTHER_SECURED_LAST_YEAR"))
  band <- if (year <= initial) paste0("YEAR_1_", initial) else if (year <= last) paste0("YEAR_", year) else paste0("YEAR_", last + 1, "_PLUS")
  parameter_get(params, key, band)
}

t2_eligible_amount <- function(current_amount, first_day_amount, maturity, as_of, params) {
  if (is.null(maturity) || is.na(maturity)) return(current_amount)
  remaining <- max(as.numeric(as.Date(maturity) - as.Date(as_of)), 0)
  period_days <- round(parameter_get(params, "T2", "AMORTISATION_YEARS") *
                         parameter_get(params, "TIME_CONVENTION", "DAYS_PER_YEAR"))
  if (remaining > period_days) current_amount else first_day_amount / period_days * remaining
}

irrbb_shock <- function(scenario, t, parallel, short, long, params) {
  decay <- parameter_get(params, "IRRBB_SHOCK", "DECAY_YEARS")
  short_component <- short * exp(-t / decay)
  long_component <- long * (1 - exp(-t / decay))
  switch(scenario,
         PARALLEL_UP = parallel,
         PARALLEL_DOWN = -parallel,
         SHORT_UP = short_component,
         SHORT_DOWN = -short_component,
         STEEPENER = parameter_get(params, "IRRBB_SHOCK", "STEEPENER_SHORT_WEIGHT") * abs(short_component) +
           parameter_get(params, "IRRBB_SHOCK", "STEEPENER_LONG_WEIGHT") * abs(long_component),
         FLATTENER = parameter_get(params, "IRRBB_SHOCK", "FLATTENER_SHORT_WEIGHT") * abs(short_component) +
           parameter_get(params, "IRRBB_SHOCK", "FLATTENER_LONG_WEIGHT") * abs(long_component),
         stop(sprintf("Unknown IRRBB scenario: %s", scenario), call. = FALSE))
}

shocked_zero_rate <- function(base, shock, t, params) {
  floor <- min(parameter_get(params, "IRRBB_FLOOR", "BASE") +
                 parameter_get(params, "IRRBB_FLOOR", "SLOPE") * t, 0)
  max(base + shock, min(base, floor))
}

discount_factor <- function(continuous_zero_rate, t) exp(-continuous_zero_rate * t)

correlated_capital <- function(capitals, correlation) {
  capitals <- as.numeric(capitals)
  correlation <- as.matrix(correlation)
  if (!all(dim(correlation) == c(length(capitals), length(capitals)))) {
    stop("Correlation matrix dimensions do not match capitals", call. = FALSE)
  }
  sqrt(max(drop(t(capitals) %*% correlation %*% capitals), 0))
}
