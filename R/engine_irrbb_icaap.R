# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

interpolate_curve <- function(curve, t) {
  ordered <- curve[order(as.numeric(curve$tenor_years)), , drop = FALSE]
  as.numeric(stats::approx(as.numeric(ordered$tenor_years), as.numeric(ordered$zero_rate),
                           xout = t, rule = 2, ties = "ordered")$y)
}

deterministic_normals <- function(n, standard_deviation, seed) {
  reference_path <- package_resource("extdata", "canonical",
                                     "irrbb_numpy_reference.rds")
  if (file.exists(reference_path)) {
    reference <- readRDS(reference_path)
    if (as.integer(n) == as.integer(reference$paths) &&
        as.integer(seed) == as.integer(reference$seed)) {
      return(as.numeric(reference$values) * standard_deviation)
    }
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  on.exit({
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv) else
      if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) rm(".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)
  set.seed(as.integer(seed), kind = "Mersenne-Twister", normal.kind = "Inversion")
  stats::rnorm(as.integer(n), 0, standard_deviation)
}

calculate_irrbb <- function(t, ctx, out) {
  p <- ctx$parameters; cf <- t$cashflow; curve <- t$yield_curve; scenarios <- t$irrbb_scenario
  cf$payment_date <- as.Date(cf$payment_date); cf$repricing_date <- as.Date(cf$repricing_date)
  days_per_year <- parameter_get(p, "TIME_CONVENTION", "DAYS_PER_YEAR")
  cf$t <- as.numeric(cf$payment_date - ctx$as_of_date) / days_per_year
  cf <- cf[cf$t > 0, , drop = FALSE]
  cf$signed_cf <- (ifelse(is.na(as.numeric(cf$principal_amount)), 0, as.numeric(cf$principal_amount)) +
                     ifelse(is.na(as.numeric(cf$interest_amount)), 0, as.numeric(cf$interest_amount)) +
                     ifelse(is.na(as.numeric(cf$fee_margin_amount)), 0, as.numeric(cf$fee_margin_amount))) *
    ifelse(is.na(as.numeric(cf$sign)), 1, as.numeric(cf$sign))
  cf$repricing_t <- as.numeric(cf$repricing_date - ctx$as_of_date) / days_per_year
  band_edges <- sort(unique(as.numeric(stats::na.omit(t$behavioural_assumption$time_band_years))))
  if (!length(band_edges)) band_edges <- sort(unique(as.numeric(stats::na.omit(curve$tenor_years))))
  assign_band <- function(value) {
    hit <- band_edges[value <= band_edges]
    if (length(hit)) sprintf("LE_%gY", hit[[1L]]) else sprintf("GT_%gY", tail(band_edges, 1))
  }
  cf$repricing_band <- vapply(cf$repricing_t, assign_band, character(1))
  gap_rows <- lapply(split(cf, factor(cf$repricing_band, levels = unique(cf$repricing_band))), function(g) {
    signed <- ifelse(is.na(as.numeric(g$principal_amount)), 0, as.numeric(g$principal_amount)) *
      ifelse(is.na(as.numeric(g$sign)), 0, as.numeric(g$sign))
    assets <- sum(signed[signed > 0]); liabilities <- sum(-signed[signed < 0])
    list(repricing_band = as.character(g$repricing_band[[1L]]), asset_principal = assets,
         liability_principal = liabilities, net_gap = assets - liabilities,
         cashflow_count = nrow(g), behavioural_cashflow_count = sum(vapply(g$behavioural_flag, rwa_bool, logical(1))),
         formula_id = "IRRBB_NII")
  })
  out$results$IRRBB_Repricing_Gap <- rows_frame(gap_rows)
  currency_groups <- split(cf, cf$currency)
  base_pv_by_currency <- vapply(names(currency_groups), function(currency) {
    g <- currency_groups[[currency]]; currency_curve <- curve[as.character(curve$currency) == currency, , drop = FALSE]
    if (!nrow(currency_curve)) stop(sprintf("IRRBB yield curve missing for %s", currency), call. = FALSE)
    sum(vapply(seq_len(nrow(g)), function(i) {
      rwa_num(g$signed_cf[[i]]) * discount_factor(interpolate_curve(currency_curve, rwa_num(g$t[[i]])), rwa_num(g$t[[i]]))
    }, numeric(1)))
  }, numeric(1))
  base_pv <- sum(base_pv_by_currency); currency_rows <- list(); nii_band_rows <- list()
  for (i in seq_len(nrow(scenarios))) {
    s <- scenarios[i, , drop = FALSE]; scenario <- as.character(s$scenario_type); currency <- as.character(s$currency)
    currency_cf <- cf[as.character(cf$currency) == currency, , drop = FALSE]
    if (!nrow(currency_cf)) next
    currency_curve <- curve[as.character(curve$currency) == currency, , drop = FALSE]
    bp_unit <- parameter_get(p, "IRRBB_MODEL", "BASIS_POINTS_PER_UNIT")
    parallel <- rwa_num(s$parallel_bp) / bp_unit; short <- rwa_num(s$short_bp) / bp_unit
    long <- rwa_num(s$long_bp) / bp_unit; pv <- 0
    for (j in seq_len(nrow(currency_cf))) {
      r <- currency_cf[j, , drop = FALSE]; tv <- rwa_num(r$t)
      base <- interpolate_curve(currency_curve, tv)
      shock <- irrbb_shock(scenario, tv, parallel, short, long, p)
      pv <- pv + rwa_num(r$signed_cf) * discount_factor(shocked_zero_rate(base, shock, tv, p), tv)
    }
    delta <- pv - base_pv_by_currency[[currency]]; nii_delta <- 0
    band_contributions <- setNames(numeric(length(unique(currency_cf$repricing_band))), unique(currency_cf$repricing_band))
    for (j in seq_len(nrow(currency_cf))) {
      r <- currency_cf[j, , drop = FALSE]
      repr_t <- max(as.numeric(as.Date(r$repricing_date) - ctx$as_of_date) / days_per_year, 0)
      horizon <- parameter_get(p, "IRRBB_MODEL", "HORIZON_YEARS")
      if (repr_t <= horizon) {
        shock <- irrbb_shock(scenario, max(repr_t, RWA_EPSILON), parallel, short, long, p)
        contribution <- rwa_num(r$principal_amount) * rwa_num(r$sign, 1) * shock * max(horizon - repr_t, 0)
        nii_delta <- nii_delta + contribution
        band <- as.character(r$repricing_band); band_contributions[[band]] <- band_contributions[[band]] + contribution
      }
    }
    for (band in names(band_contributions)) nii_band_rows[[length(nii_band_rows) + 1L]] <- list(
      scenario = scenario, currency = currency, repricing_band = band,
      delta_nii = band_contributions[[band]], ear_contribution = max(-band_contributions[[band]], 0),
      formula_id = "IRRBB_NII")
    currency_rows[[length(currency_rows) + 1L]] <- list(
      scenario = scenario, currency = currency, eve_base = base_pv_by_currency[[currency]],
      eve_shocked = pv, delta_eve = delta, eve_loss = max(-delta, 0), delta_nii = nii_delta,
      ear = max(-nii_delta, 0), formula_id = "IRRBB_EVE/IRRBB_NII")
  }
  currency_result <- rows_frame(currency_rows)
  if (nrow(currency_result)) {
    result <- rows_frame(lapply(split(currency_result, currency_result$scenario), function(g) {
      delta_eve <- sum(g$delta_eve); delta_nii <- sum(g$delta_nii)
      list(scenario = as.character(g$scenario[[1L]]), eve_base = sum(g$eve_base),
           eve_shocked = sum(g$eve_shocked), delta_eve = delta_eve, delta_nii = delta_nii,
           eve_loss = max(-delta_eve, 0), ear = max(-delta_nii, 0), formula_id = "IRRBB_EVE/IRRBB_NII")
    }))
  } else result <- empty_frame(c("scenario", "eve_base", "eve_shocked", "delta_eve", "delta_nii",
                                  "eve_loss", "ear", "formula_id"))
  worst_eve <- if (nrow(result)) max(result$eve_loss) else 0
  parallel_rows <- result[result$scenario %in% c("PARALLEL_UP", "PARALLEL_DOWN"), , drop = FALSE]
  worst_nii <- if (nrow(parallel_rows)) max(parallel_rows$ear) else 0
  tier1 <- max(rwa_num(out$metrics$TIER1), 1)
  z <- deterministic_normals(parameter_get(p, "IRRBB_MODEL", "SIMULATION_PATHS"),
                             parameter_get(p, "IRRBB_MODEL", "RATE_VOLATILITY"),
                             parameter_get(p, "IRRBB_MODEL", "RANDOM_SEED"))
  duration_proxy <- sum(vapply(seq_len(nrow(cf)), function(i) {
    r <- cf[i, , drop = FALSE]; currency_curve <- curve[as.character(curve$currency) == as.character(r$currency), , drop = FALSE]
    abs(rwa_num(r$signed_cf)) * rwa_num(r$t) *
      discount_factor(interpolate_curve(currency_curve, rwa_num(r$t)), rwa_num(r$t))
  }, numeric(1)))
  losses <- pmax(z * duration_proxy, 0)
  var <- as.numeric(stats::quantile(losses, parameter_get(p, "IRRBB_MODEL", "VAR_CONFIDENCE"), names = FALSE, type = 7))
  es <- if (any(losses >= var)) mean(losses[losses >= var]) else var
  csrbb <- abs(base_pv) * parameter_get(p, "CSRBB_MODEL", "STRESS_FACTOR")
  out$results$IRRBB_Scenarios <- result; out$results$IRRBB_Currency_Scenarios <- currency_result
  out$results$IRRBB_NII_Bands <- rows_frame(nii_band_rows)
  out$results$IRRBB_Risk_Measures <- data.frame(
    worst_eve_loss = worst_eve, eve_sot_ratio = worst_eve / tier1,
    eve_outlier = worst_eve / tier1 > parameter_get(p, "IRRBB_SOT", "EVE"),
    worst_nii_decline = worst_nii, nii_sot_ratio = worst_nii / tier1,
    nii_outlier = worst_nii / tier1 > parameter_get(p, "IRRBB_SOT", "NII"),
    eve_var_99 = var, eve_es_99 = es, csrbb_stress_loss = csrbb,
    formula_id = "IRRBB_EVE/IRRBB_NII")
  out$metrics <- modifyList(out$metrics, list(
    WORST_EVE_LOSS = worst_eve, EVE_SOT_RATIO = worst_eve / tier1,
    WORST_NII_DECLINE = worst_nii, NII_SOT_RATIO = worst_nii / tier1,
    EVE_VAR_99 = var, EVE_ES_99 = es, CSRBB_LOSS = csrbb))
  behaviour_groups <- split(t$behavioural_assumption,
                            interaction(t$behavioural_assumption$segment,
                                        t$behavioural_assumption$assumption_type, drop = TRUE))
  for (g in behaviour_groups) {
    total <- sum(as.numeric(g$weight), na.rm = TRUE)
    add_control(out, paste("BEHAVIOUR_WEIGHTS", g$segment[[1L]], g$assumption_type[[1L]], sep = "_"),
                abs(total - 1) < parameter_get(p, "CONTROL", "RATE_TOLERANCE"), 1, total,
                "Behavioural weights sum to one")
  }
  invisible(out)
}

calculate_icaap <- function(t, ctx, out) {
  p <- ctx$parameters; ec <- t$economic_capital_input
  ec$ec_diversifiable <- pmax(as.numeric(ec$var_loss) - as.numeric(ec$provisions), 0) + as.numeric(ec$model_risk_addon)
  ec$ec_standalone <- ec$ec_diversifiable + as.numeric(ec$non_diversifiable_addon)
  ids <- as.character(ec$risk_id); caps <- as.numeric(ec$ec_diversifiable); corr_in <- t$risk_correlation
  corr <- matrix(0, nrow = length(ids), ncol = length(ids), dimnames = list(ids, ids))
  for (i in seq_along(ids)) for (j in seq_along(ids)) {
    hit <- corr_in$correlation[as.character(corr_in$risk_id_a) == ids[[i]] &
                                 as.character(corr_in$risk_id_b) == ids[[j]]]
    corr[i, j] <- if (length(hit)) rwa_num(hit[[1L]], if (i == j) 1 else 0) else if (i == j) 1 else 0
  }
  tolerance <- parameter_get(p, "CONTROL", "RATE_TOLERANCE")
  symmetric <- isTRUE(all.equal(corr, t(corr), tolerance = tolerance))
  min_eigenvalue <- min(eigen((corr + t(corr)) / 2, symmetric = TRUE, only.values = TRUE)$values)
  add_control(out, "ICAAP_CORRELATION_SYMMETRIC", symmetric, TRUE, symmetric, "Correlation matrix is symmetric")
  add_control(out, "ICAAP_CORRELATION_PSD", min_eigenvalue >= -tolerance, ">=0", min_eigenvalue,
              "Correlation matrix is positive semidefinite")
  raw <- correlated_capital(caps, corr); linear_diversifiable <- sum(caps)
  diversification <- min(linear_diversifiable - raw,
                         parameter_get(p, "ICAAP", "DIVERSIFICATION_CAP") * linear_diversifiable)
  nondiv <- sum(as.numeric(ec$non_diversifiable_addon)); linear <- sum(as.numeric(ec$ec_standalone))
  aggregate <- linear_diversifiable - diversification + nondiv; rb <- t$risk_bearing_capacity
  capacity <- if (nrow(rb)) sum(as.numeric(rb$amount) * as.numeric(rb$eligibility_factor) *
                                  (1 - as.numeric(rb$haircut)) - as.numeric(rb$management_reserve)) else
    rwa_num(out$metrics$CET1) + parameter_get(p, "ICAAP", "FALLBACK_AT1_SHARE") * rwa_num(out$metrics$AT1) -
      parameter_get(p, "ICAAP", "FALLBACK_MANAGEMENT_RESERVE")
  standalone_columns <- c("risk_id", "expected_loss", "var_loss", "stress_loss", "provisions",
                          "model_risk_addon", "non_diversifiable_addon", "ec_diversifiable", "ec_standalone")
  out$results$EC_Standalone <- ec[, standalone_columns, drop = FALSE]; out$results$EC_Standalone$formula_id <- "ICAAP_EC"
  reference_rate <- parameter_get(p, "RWA_EQUIVALENT", "REFERENCE_RATE")
  out$results$EC_Aggregation <- data.frame(
    ec_linear = linear, ec_correlated_raw = raw, recognized_diversification = diversification,
    ec_aggregate = aggregate, economic_capacity = capacity, economic_headroom = capacity - aggregate,
    economic_utilisation = aggregate / max(capacity, 1), ec_rwa_equivalent = aggregate / reference_rate,
    formula_id = "ICAAP_EC")
  projections <- list(); base_cet1 <- rwa_num(out$metrics$CET1); base_trea <- rwa_num(out$metrics$TREA)
  base_lev <- rwa_num(out$metrics$LEVERAGE_EXPOSURE)
  projection_groups <- split(t$normative_projection, t$normative_projection$scenario_id)
  for (scenario in names(projection_groups)) {
    g <- projection_groups[[scenario]][order(as.numeric(projection_groups[[scenario]]$projection_year)), , drop = FALSE]
    cet1 <- base_cet1
    for (i in seq_len(nrow(g))) {
      r <- g[i, , drop = FALSE]
      cet1 <- cet1 + rwa_num(r$profit_after_tax) - rwa_num(r$distributions) + rwa_num(r$oci_change) +
        rwa_num(r$cet1_issuance) - rwa_num(r$cet1_redemption)
      trea <- base_trea * rwa_num(r$trea_multiplier, 1); leverage <- base_lev * rwa_num(r$leverage_exposure_multiplier, 1)
      required <- (parameter_get(p, "CAPITAL_RATE", "CET1") + rwa_num(out$metrics$P2R_CET1_SHARE) *
                     rwa_num(out$metrics$P2R_RATE) + rwa_num(out$metrics$CBR_RATE)) * trea
      projections[[length(projections) + 1L]] <- list(
        scenario = scenario, projection_year = as.integer(r$projection_year), cet1 = cet1, trea = trea,
        cet1_ratio = cet1 / max(trea, 1), cet1_required = required, cet1_headroom = cet1 - required,
        leverage_ratio = (rwa_num(out$metrics$TIER1) + cet1 - base_cet1) / max(leverage, 1))
    }
  }
  norm <- rows_frame(projections); if (nrow(norm)) norm$formula_id <- "ICAAP_NORMATIVE"
  out$results$Normative_Projection <- norm
  out$metrics <- modifyList(out$metrics, list(
    EC_LINEAR = linear, EC_AGGREGATE = aggregate, ECONOMIC_CAPACITY = capacity,
    ECONOMIC_HEADROOM = capacity - aggregate, EC_RWA_EQUIVALENT = aggregate / reference_rate,
    NORMATIVE_MIN_HEADROOM = if (nrow(norm)) min(norm$cet1_headroom) else 0))
  out$results$RWA_Equivalents <- rbind(out$results$RWA_Equivalents,
    data.frame(equivalent_type = "EC_EQUIVALENT", capital_amount = aggregate,
               reference_rate = reference_rate, rwa_equivalent = aggregate / reference_rate,
               official = FALSE, additive_to_legal_trea = FALSE, formula_id = "EC_RWA_EQ"))
  irrbb_management_capital <- max(rwa_num(out$metrics$WORST_EVE_LOSS), rwa_num(out$metrics$WORST_NII_DECLINE),
                                  rwa_num(out$metrics$EVE_ES_99)) + rwa_num(out$metrics$CSRBB_LOSS)
  out$results$Pillar2_Bridge <- data.frame(
    measure = "IRRBB_CSRBB_MANAGEMENT_CAPITAL", normative_amount = rwa_num(out$metrics$WORST_NII_DECLINE),
    economic_amount = max(rwa_num(out$metrics$WORST_EVE_LOSS), rwa_num(out$metrics$EVE_ES_99)),
    csrbb_amount = rwa_num(out$metrics$CSRBB_LOSS), selected_capital = irrbb_management_capital,
    supervisory_p2r_amount = rwa_num(out$metrics$P2R_AMOUNT), automatic_p2r_translation = FALSE,
    formula_id = "PILLAR2_BRIDGE")
  out$results$RWA_Equivalents <- rbind(out$results$RWA_Equivalents,
    data.frame(equivalent_type = "IRRBB_CSRBB_MANAGEMENT_EQUIVALENT",
               capital_amount = irrbb_management_capital, reference_rate = reference_rate,
               rwa_equivalent = irrbb_management_capital / reference_rate, official = FALSE,
               additive_to_legal_trea = FALSE, formula_id = "IRRBB_RWA_EQ"))
  out$metrics$IRRBB_MANAGEMENT_CAPITAL <- irrbb_management_capital
  out$metrics$IRRBB_RWA_EQUIVALENT <- irrbb_management_capital / reference_rate
  add_control(out, "EC_CAPACITY", capacity - aggregate >= 0, ">=0", capacity - aggregate,
              "Economic risk-bearing capacity")
  invisible(out)
}
