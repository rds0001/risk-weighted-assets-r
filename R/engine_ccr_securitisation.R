# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

calculate_ccr_cva_settlement <- function(t, ctx, out) {
  p <- ctx$parameters; rwa_factor <- parameter_get(p, "RWA_MULTIPLIER", "PILLAR1")
  ns_rows <- lapply(seq_len(nrow(t$netting_set)), function(i) {
    r <- t$netting_set[i, , drop = FALSE]
    addon <- sum(vapply(c("addon_ird", "addon_fx", "addon_credit", "addon_equity", "addon_commodity"),
                        function(x) rwa_num(r[[x]]), numeric(1)))
    alpha <- rwa_num(r$alpha, parameter_get(p, "SA_CCR", "ALPHA"))
    e <- sa_ccr_ead(rwa_num(r$V), rwa_num(r$C), addon, alpha, p)
    rw <- rwa_num(r$risk_weight, 1)
    list(netting_set_id = as.character(r$netting_set_id), rc = unname(e["rc"]), addon = addon,
         multiplier = unname(e["multiplier"]), pfe = unname(e["pfe"]), ead = unname(e["ead"]),
         risk_weight = rw, rwea = unname(e["ead"]) * rw,
         formula_id = "SA_CCR", formula_version = ctx$formula_version)
  })
  ccr <- rows_frame(ns_rows, c("netting_set_id", "rc", "addon", "multiplier", "pfe", "ead",
                               "risk_weight", "rwea", "formula_id", "formula_version"))
  out$results$CCR_Detail <- ccr; out$metrics$RWEA_CCR <- sum_column(ccr, "rwea")

  sft_rows <- lapply(seq_len(nrow(t$sft_trade)), function(i) {
    r <- t$sft_trade[i, , drop = FALSE]
    ead <- sft_ead(rwa_num(r$cash_leg), rwa_num(r$security_value),
                   rwa_num(r$security_haircut), rwa_num(r$fx_haircut))
    rw <- rwa_num(r$risk_weight)
    list(trade_id = as.character(r$trade_id), ead = ead, risk_weight = rw,
         rwea = ead * rw, formula_id = "SFT_COMPREHENSIVE")
  })
  sft <- rows_frame(sft_rows, c("trade_id", "ead", "risk_weight", "rwea", "formula_id"))
  out$results$SFT_Detail <- sft; out$metrics$RWEA_SFT <- sum_column(sft, "rwea")

  ccp_rows <- lapply(seq_len(nrow(t$ccp_exposure)), function(i) {
    r <- t$ccp_exposure[i, , drop = FALSE]
    if (rwa_bool(r$qccp_flag)) {
      rw <- parameter_get(p, "CCP_RW", if (rwa_bool(r$client_joint_default_flag)) "QCCP_JOINT_DEFAULT" else "QCCP_MEMBER")
      trade_rwea <- rwa_num(r$trade_ead) * rw; df <- rwa_num(r$default_fund_contribution)
      denominator <- max(rwa_num(r$ccp_default_fund_total), 1)
      k <- max(rwa_num(r$hypothetical_ccp_capital) * df / denominator,
               parameter_get(p, "CCP_DF", "FLOOR_CAPITAL_RATE") *
                 parameter_get(p, "CCP_RW", "QCCP_MEMBER") * df)
      df_rwea <- rwa_factor * k
    } else {
      rw <- parameter_get(p, "CCP_RW", "NON_QCCP")
      trade_rwea <- rwa_num(r$trade_ead) * rw
      df_rwea <- rwa_factor * rwa_num(r$default_fund_contribution)
    }
    list(ccp_exposure_id = as.character(r$ccp_exposure_id), qccp = rwa_bool(r$qccp_flag),
         trade_rwea = trade_rwea, default_fund_rwea = df_rwea,
         rwea = trade_rwea + df_rwea, formula_id = "CCP")
  })
  ccp <- rows_frame(ccp_rows, c("ccp_exposure_id", "qccp", "trade_rwea", "default_fund_rwea", "rwea", "formula_id"))
  out$results$CCP_Detail <- ccp; out$metrics$RWEA_CCP <- sum_column(ccp, "rwea")

  items <- list()
  for (i in seq_len(nrow(t$cva_scope_item))) {
    r <- t$cva_scope_item[i, , drop = FALSE]
    if (!rwa_bool(r$exempt_flag)) items[[length(items) + 1L]] <- c(
      rwa_num(r$cva_risk_weight), rwa_num(r$effective_maturity), rwa_num(r$ead),
      rwa_num(r$single_name_hedge), rwa_num(r$single_hedge_maturity),
      rwa_num(r$hedge_correlation), rwa_num(r$index_hedge),
      rwa_num(r$index_hedge_maturity), rwa_num(r$index_hedge_risk_weight))
  }
  k_cva <- if (length(items)) ba_cva_capital(items, p) else 0
  sensitivities <- t$cva_sensitivity
  bucket_rows <- list(); measure_capital <- numeric()
  if (nrow(sensitivities)) {
    sensitivities$ws <- as.numeric(sensitivities$sensitivity) * as.numeric(sensitivities$risk_weight)
    groups <- split(sensitivities, interaction(sensitivities$measure, sensitivities$risk_class,
                                               sensitivities$bucket, drop = TRUE))
    for (g in groups) {
      ws <- g$ws; rho <- as.numeric(g$correlation[[1L]])
      k2 <- sum(ws^2) + rho * (sum(ws)^2 - sum(ws^2))
      bucket_rows[[length(bucket_rows) + 1L]] <- list(
        measure = as.character(g$measure[[1L]]), risk_class = as.character(g$risk_class[[1L]]),
        bucket = as.character(g$bucket[[1L]]), S_b = sum(ws), K_b = sqrt(max(k2, 0)),
        formula_id = "SA_CVA")
    }
  }
  cva_buckets <- rows_frame(bucket_rows, c("measure", "risk_class", "bucket", "S_b", "K_b", "formula_id"))
  if (nrow(cva_buckets)) {
    gamma <- parameter_get(p, "SA_CVA", "INTER_BUCKET_CORRELATION")
    groups <- split(cva_buckets, interaction(cva_buckets$measure, cva_buckets$risk_class, drop = TRUE))
    measure_capital <- vapply(groups, function(g) {
      sqrt(max(sum(g$K_b^2) + gamma * (sum(g$S_b)^2 - sum(g$S_b^2)), 0))
    }, numeric(1))
  }
  k_sa_cva <- sum(measure_capital)
  out$results$CVA_Buckets <- cva_buckets
  out$results$CVA_Summary <- rows_frame(list(
    list(approach = "BA_CVA", counterparties = length(items), k_cva = k_cva,
         rwea = rwa_factor * k_cva, formula_id = "BA_CVA"),
    list(approach = "SA_CVA_PARALLEL", counterparties = length(items), k_cva = k_sa_cva,
         rwea = rwa_factor * k_sa_cva, formula_id = "SA_CVA")))
  out$metrics$K_CVA <- k_cva; out$metrics$K_CVA_SA <- k_sa_cva

  settlement_rows <- lapply(seq_len(nrow(t$settlement_exposure)), function(i) {
    r <- t$settlement_exposure[i, , drop = FALSE]
    k <- if (rwa_bool(r$free_delivery_flag)) {
      max(rwa_num(r$delivered_leg) - rwa_num(r$countervalue), 0) * rwa_num(r$counterparty_risk_weight)
    } else {
      rwa_num(r$positive_price_difference) * settlement_factor(as.integer(rwa_num(r$business_days_late)), p)
    }
    list(settlement_id = as.character(r$settlement_id), capital_requirement = k,
         rwea = rwa_factor * k, formula_id = "SETTLEMENT")
  })
  settlement <- rows_frame(settlement_rows, c("settlement_id", "capital_requirement", "rwea", "formula_id"))
  out$results$Settlement_Detail <- settlement; out$metrics$K_SETTLEMENT <- sum_column(settlement, "capital_requirement")
  lex <- t$large_exposure_excess
  if (nrow(lex)) {
    lex$capital_requirement <- as.numeric(lex$excess_amount) * as.numeric(lex$capital_charge_rate)
    lex$rwea <- rwa_factor * lex$capital_requirement; lex$formula_id <- "LARGE_EXPOSURE"
  }
  out$results$Large_Exposure <- lex; out$metrics$K_LARGE_EXPOSURE <- sum_column(lex, "capital_requirement")
  invisible(out)
}

calculate_securitisation <- function(t, ctx, out) {
  p <- ctx$parameters
  merged <- merge(t$securitisation_tranche, t$securitisation_pool, by = "pool_id",
                  suffixes = c("", "_pool"), sort = FALSE)
  rows <- lapply(seq_len(nrow(merged)), function(i) {
    r <- merged[i, , drop = FALSE]; approach <- as.character(r$approach)
    senior <- rwa_bool(r$senior_flag); sts <- rwa_bool(r$sts_flag)
    resecuritisation <- rwa_bool(r$resecuritisation_flag); data_sufficient <- rwa_bool(r$data_sufficient_flag)
    p_raw <- NA_real_
    if (identical(approach, "SEC_IRBA")) {
      ka <- sec_k_irb(rwa_num(r$rwea_pool_irb_ul), rwa_num(r$el_pool_irb), rwa_num(r$pool_ead), p)
      pv <- sec_irba_p(if (as.character(r$pool_type) == "RETAIL") "RETAIL" else "NON_RETAIL",
                       senior, rwa_num(r$effective_number_exposures), ka, rwa_num(r$average_lgd),
                       rwa_num(r$tranche_maturity), sts, p)
      p_raw <- unname(pv["raw"]); p_factor <- unname(pv["p"])
    } else if (identical(approach, "SEC_SA")) {
      base_ka <- sec_k_sa(rwa_num(r$rwea_pool_sa), rwa_num(r$pool_ead), p)
      w <- rwa_num(r$npe_share)
      ka <- (1 - w) * base_ka + w * parameter_get(p, "SEC_SSFA", "DEFAULTED_POOL_FACTOR")
      p_factor <- parameter_get(p, "SEC_SSFA", if (resecuritisation) "RESECURITISATION_P" else if (sts) "SA_STS_P" else "SA_P")
    } else { ka <- NA_real_; p_factor <- NA_real_ }
    override <- row_value(r, "risk_weight_override", NA)
    rw <- if (!is.na(override)) as.numeric(override) else if (!data_sufficient) {
      parameter_get(p, "SEC", "RW_CAP")
    } else if (identical(approach, "SEC_ERBA")) {
      sec_erba_rw(as.integer(rwa_num(r$credit_quality_step)), rwa_num(r$tranche_maturity), senior,
                  sts, rwa_num(r$attachment), rwa_num(r$detachment), p)
    } else {
      securitisation_rw(approach, ka, rwa_num(r$attachment), rwa_num(r$detachment), p_factor,
                        sts, senior, resecuritisation, as.integer(rwa_num(r$credit_quality_step)), p)
    }
    list(tranche_id = as.character(r$tranche_id), approach = approach, pool_k = ka,
         attachment = rwa_num(r$attachment), detachment = rwa_num(r$detachment),
         thickness = rwa_num(r$detachment) - rwa_num(r$attachment), senior = senior,
         sts = sts, p_raw = p_raw, p_factor = p_factor, risk_weight = rw,
         ead = rwa_num(r$ead), rwea = rwa_num(r$ead) * rw,
         formula_id = if (approach != "SEC_ERBA") "SEC_SSFA" else "SEC_ERBA")
  })
  result <- rows_frame(rows, c("tranche_id", "approach", "pool_k", "attachment", "detachment",
                               "thickness", "senior", "sts", "p_raw", "p_factor", "risk_weight",
                               "ead", "rwea", "formula_id"))
  out$results$SEC_Detail <- result; out$metrics$RWEA_SECURITISATION <- sum_column(result, "rwea")
  invisible(out)
}

