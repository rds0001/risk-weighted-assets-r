# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

market_scenario_correlation <- function(base, scenario, params) {
  if (scenario == "HIGH") return(min(parameter_get(params, "FRTB_CORRELATION", "HIGH_MULTIPLIER") * base,
                                      parameter_get(params, "FRTB_CORRELATION", "HIGH_CAP")))
  if (scenario == "LOW") return(max(parameter_get(params, "FRTB_CORRELATION", "LOW_LINEAR_MULTIPLIER") * base - 1,
                                     parameter_get(params, "FRTB_CORRELATION", "LOW_FLOOR_MULTIPLIER") * base))
  base
}

market_quadratic <- function(values, correlation, curvature = FALSE) {
  values <- as.numeric(values); total <- sum(values^2)
  if (length(values) > 1L) for (i in seq_along(values)) for (j in seq_along(values)) if (i != j) {
    psi <- if (curvature && values[[i]] < 0 && values[[j]] < 0) 0 else 1
    total <- total + (if (curvature) correlation^2 else correlation) * values[[i]] * values[[j]] * psi
  }
  sqrt(max(total, 0))
}

calculate_market <- function(t, ctx, out) {
  p <- ctx$parameters; rwa_factor <- parameter_get(p, "RWA_MULTIPLIER", "PILLAR1")
  pos <- t$trading_position
  if (nrow(pos)) {
    pos$legacy_k <- ifelse(is.na(as.numeric(pos$legacy_specific_charge)), 0, as.numeric(pos$legacy_specific_charge)) +
      ifelse(is.na(as.numeric(pos$legacy_general_charge)), 0, as.numeric(pos$legacy_general_charge))
    pos$formula_id <- "MARKET_LEGACY"
    legacy <- pos[, c("position_id", "risk_class", "market_value", "legacy_specific_charge",
                      "legacy_general_charge", "legacy_k", "formula_id"), drop = FALSE]
  } else legacy <- empty_frame(c("position_id", "risk_class", "market_value", "legacy_specific_charge",
                                  "legacy_general_charge", "legacy_k", "formula_id"))
  out$results$Market_Legacy <- legacy; legacy_k <- sum_column(legacy, "legacy_k")
  out$metrics$K_MARKET_LEGACY <- legacy_k

  sens <- t$market_sensitivity
  if (nrow(sens)) sens$weighted_sensitivity <- as.numeric(sens$sensitivity) * as.numeric(sens$risk_weight)
  bucket_rows <- list(); class_rows <- list(); scenario_capitals <- list()
  for (scenario in c("LOW", "MEDIUM", "HIGH")) {
    scenario_rows <- list()
    if (nrow(sens)) {
      groups <- split(sens, interaction(sens$measure, sens$risk_class, sens$bucket, drop = TRUE))
      for (g in groups) {
        measure <- as.character(g$measure[[1L]]); risk_class <- as.character(g$risk_class[[1L]])
        bucket <- as.character(g$bucket[[1L]])
        rho <- market_scenario_correlation(as.numeric(g$intra_bucket_correlation[[1L]]), scenario, p)
        gamma <- market_scenario_correlation(as.numeric(g$inter_bucket_correlation[[1L]]), scenario, p)
        if (measure == "CURVATURE") {
          factor_groups <- split(g, g$risk_factor)
          up <- vapply(factor_groups, function(x) sum(as.numeric(x$curvature_up)), numeric(1))
          down <- vapply(factor_groups, function(x) sum(as.numeric(x$curvature_down)), numeric(1))
          k_up <- market_quadratic(up, rho, TRUE); k_down <- market_quadratic(down, rho, TRUE)
          row <- list(correlation_scenario = scenario, measure = measure, risk_class = risk_class,
                      bucket = bucket, S_b_up = sum(up), S_b_down = sum(down), K_b_up = k_up,
                      K_b_down = k_down, S_b = 0, K_b = max(k_up, k_down), rho = rho,
                      gamma = gamma, formula_id = "FRTB_SBM")
        } else {
          ws <- vapply(split(g$weighted_sensitivity, g$risk_factor), sum, numeric(1))
          k <- market_quadratic(ws, rho); raw <- sum(ws)
          row <- list(correlation_scenario = scenario, measure = measure, risk_class = risk_class,
                      bucket = bucket, S_b_up = NA_real_, S_b_down = NA_real_, K_b_up = NA_real_,
                      K_b_down = NA_real_, S_b = clip(raw, -k, k), K_b = k, rho = rho,
                      gamma = gamma, formula_id = "FRTB_SBM")
        }
        scenario_rows[[length(scenario_rows) + 1L]] <- row
        bucket_rows[[length(bucket_rows) + 1L]] <- row
      }
    }
    scenario_frame <- rows_frame(scenario_rows, c("correlation_scenario", "measure", "risk_class", "bucket",
      "S_b_up", "S_b_down", "K_b_up", "K_b_down", "S_b", "K_b", "rho", "gamma", "formula_id"))
    scenario_total <- 0
    if (nrow(scenario_frame)) {
      class_groups <- split(scenario_frame, interaction(scenario_frame$measure, scenario_frame$risk_class, drop = TRUE))
      for (g in class_groups) {
        measure <- as.character(g$measure[[1L]]); gamma <- as.numeric(g$gamma[[1L]])
        if (measure == "CURVATURE") {
          curvature_class <- function(kb, sb) {
            total <- sum(kb^2)
            if (length(sb) > 1L) for (i in seq_along(sb)) for (j in seq_along(sb)) if (i != j) {
              total <- total + gamma^2 * sb[[i]] * sb[[j]] * if (sb[[i]] < 0 && sb[[j]] < 0) 0 else 1
            }
            sqrt(max(total, 0))
          }
          capital <- max(curvature_class(as.numeric(g$K_b_up), as.numeric(g$S_b_up)),
                         curvature_class(as.numeric(g$K_b_down), as.numeric(g$S_b_down)))
        } else {
          kb <- as.numeric(g$K_b); sb <- as.numeric(g$S_b)
          capital <- sqrt(max(sum(kb^2) + gamma * (sum(sb)^2 - sum(sb^2)), 0))
        }
        class_rows[[length(class_rows) + 1L]] <- list(
          correlation_scenario = scenario, measure = measure,
          risk_class = as.character(g$risk_class[[1L]]), capital = capital,
          formula_id = "FRTB_SBM")
        scenario_total <- scenario_total + capital
      }
    }
    scenario_capitals[[length(scenario_capitals) + 1L]] <- list(correlation_scenario = scenario,
                                                                 sbm_capital = scenario_total)
  }
  buckets <- rows_frame(bucket_rows, c("correlation_scenario", "measure", "risk_class", "bucket",
    "S_b_up", "S_b_down", "K_b_up", "K_b_down", "S_b", "K_b", "rho", "gamma", "formula_id"))
  sbm <- rows_frame(class_rows, c("correlation_scenario", "measure", "risk_class", "capital", "formula_id"))
  sbm_scenarios <- rows_frame(scenario_capitals, c("correlation_scenario", "sbm_capital"))
  sbm_capital <- if (nrow(sbm_scenarios)) max(as.numeric(sbm_scenarios$sbm_capital)) else 0

  drc_rows <- list(); drc <- 0; rrao <- 0
  if (nrow(pos)) {
    pos$maturity_scale <- vapply(as.numeric(pos$residual_maturity_years), clip, numeric(1),
                                 lo = parameter_get(p, "FRTB_DRC", "MATURITY_MIN"),
                                 hi = parameter_get(p, "FRTB_DRC", "MATURITY_MAX"))
    pos$scaled_jtd <- as.numeric(pos$drc_jtd) * pos$maturity_scale
    net_groups <- split(pos, interaction(pos$drc_exposure_type, pos$drc_bucket,
                                         pos$issuer_id, pos$seniority_class, drop = TRUE))
    net <- rows_frame(lapply(net_groups, function(g) list(
      drc_exposure_type = as.character(g$drc_exposure_type[[1L]]), drc_bucket = as.character(g$drc_bucket[[1L]]),
      issuer_id = as.character(g$issuer_id[[1L]]), seniority_class = as.character(g$seniority_class[[1L]]),
      net_jtd = sum(g$scaled_jtd), drc_risk_weight = max(as.numeric(g$drc_risk_weight), na.rm = TRUE),
      banking_book_securitisation_rw = if (all(is.na(g$banking_book_securitisation_rw))) NA_real_ else
        max(as.numeric(g$banking_book_securitisation_rw), na.rm = TRUE))))
    sec_mask <- net$drc_exposure_type %in% c("SEC_NONCTP", "SEC_CTP") & !is.na(net$banking_book_securitisation_rw)
    net$drc_risk_weight[sec_mask] <- parameter_get(p, "SEC", "CAPITAL_RATE") * net$banking_book_securitisation_rw[sec_mask]
    drc_groups <- split(net, interaction(net$drc_exposure_type, net$drc_bucket, drop = TRUE))
    drc_rows <- lapply(drc_groups, function(g) {
      long <- g[g$net_jtd > 0, , drop = FALSE]; short <- g[g$net_jtd < 0, , drop = FALSE]
      gross_long <- sum(long$net_jtd); gross_short <- sum(-short$net_jtd)
      hbr <- if (gross_long + gross_short) gross_long / (gross_long + gross_short) else 0
      weighted_long <- sum(long$net_jtd * long$drc_risk_weight)
      weighted_short <- sum((-short$net_jtd) * short$drc_risk_weight)
      list(drc_exposure_type = as.character(g$drc_exposure_type[[1L]]),
           drc_bucket = as.character(g$drc_bucket[[1L]]), gross_long_jtd = gross_long,
           gross_short_jtd = gross_short, hedge_benefit_ratio = hbr,
           weighted_long = weighted_long, weighted_short = weighted_short,
           capital = max(weighted_long - hbr * weighted_short, 0), formula_id = "FRTB_DRC")
    })
    drc <- sum(vapply(drc_rows, function(x) x$capital, numeric(1)))
    residual <- pos[!vapply(pos$rrao_exempt_flag, rwa_bool, logical(1)), , drop = FALSE]
    if (nrow(residual)) {
      rates <- vapply(residual$rrao_exotic_flag, function(x) parameter_get(p, "FRTB_RRAO",
                     if (rwa_bool(x)) "EXOTIC_RATE" else "OTHER_RATE"), numeric(1))
      rrao <- sum(abs(as.numeric(residual$notional)) * rates)
    }
  }
  frtb_k <- sbm_capital + drc + rrao
  out$results$FRTB_Buckets <- buckets; out$results$FRTB_Risk_Classes <- sbm
  out$results$FRTB_DRC <- rows_frame(drc_rows, c("drc_exposure_type", "drc_bucket", "gross_long_jtd",
    "gross_short_jtd", "hedge_benefit_ratio", "weighted_long", "weighted_short", "capital", "formula_id"))
  out$results$FRTB_Summary <- data.frame(sbm = sbm_capital, drc = drc, rrao = rrao,
                                         k_frtb = frtb_k, rwea = rwa_factor * frtb_k,
                                         formula_id = "FRTB_SBM/DRC/RRAO")
  out$metrics$K_MARKET_FRTB <- frtb_k

  ima_rows <- lapply(seq_len(nrow(t$frtb_ima_input)), function(i) {
    r <- t$frtb_ima_input[i, , drop = FALSE]
    scale <- rwa_num(r$es_stress_reduced) / max(rwa_num(r$es_current_reduced), 1)
    imcc <- max(rwa_num(r$imcc_yesterday), rwa_num(r$backtesting_multiplier) * rwa_num(r$imcc_60d_average))
    ses <- max(rwa_num(r$ses_nmrf_yesterday), rwa_num(r$nmrf_multiplier) * rwa_num(r$ses_nmrf_60d_average))
    eligible <- rwa_bool(r$ima_permission_flag) && as.logical(parameter_get(p, "FRTB_PLA_ELIGIBLE", as.character(r$pla_zone)))
    k <- imcc + ses + rwa_num(r$ima_drc) + rwa_num(r$capital_addons)
    list(desk_id = as.character(r$desk_id), stress_scaling = scale, imcc = imcc, ses_nmrf = ses,
         ima_drc = rwa_num(r$ima_drc), capital_addons = rwa_num(r$capital_addons),
         ima_permission = rwa_bool(r$ima_permission_flag), pla_zone = as.character(r$pla_zone),
         ima_eligible = eligible, k_ima = k, formula_id = "FRTB_IMA")
  })
  ima <- rows_frame(ima_rows, c("desk_id", "stress_scaling", "imcc", "ses_nmrf", "ima_drc",
                                "capital_addons", "ima_permission", "pla_zone", "ima_eligible", "k_ima", "formula_id"))
  out$results$FRTB_IMA <- ima
  out$metrics$K_MARKET_IMA_PARALLEL <- if (nrow(ima)) sum(as.numeric(ima$k_ima[as.logical(ima$ima_eligible)])) else 0
  out$metrics$K_MARKET <- if (startsWith(ctx$market_regime, "LEGACY")) legacy_k else frtb_k
  invisible(out)
}

