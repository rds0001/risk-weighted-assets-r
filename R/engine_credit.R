# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

calculate_credit <- function(t, ctx, out) {
  p <- ctx$parameters
  exp_df <- t$exposure_lot
  sa <- t$sa_classification
  re_df <- t$real_estate_exposure
  irb <- t$irb_parameter
  alloc <- t$protection_allocation
  merged <- merge(exp_df, drop_overlap(sa, exp_df, "exposure_id"),
                  by = "exposure_id", all.x = TRUE, sort = FALSE)
  re_cols <- c("exposure_id", "property_type", "ipre_flag", "adc_flag",
               "prudent_property_value", "senior_liens", "etv")
  re_part <- if (nrow(re_df)) re_df[, re_cols, drop = FALSE] else empty_frame(re_cols)
  merged <- merge(merged, re_part, by = "exposure_id", all.x = TRUE, sort = FALSE)
  guarantee <- if (nrow(alloc)) alloc[as.character(alloc$protection_type) == "GUARANTEE", , drop = FALSE] else alloc
  if (nrow(guarantee)) {
    amounts <- aggregate(as.numeric(guarantee$eligible_value_after_haircut),
                         list(exposure_id = guarantee$exposure_id), sum, na.rm = TRUE)
    names(amounts)[[2L]] <- "protected_amount"
    weights <- aggregate(as.numeric(guarantee$substitution_risk_weight),
                         list(exposure_id = guarantee$exposure_id), min, na.rm = TRUE)
    names(weights)[[2L]] <- "substitution_rw"
    merged <- merge(merged, merge(amounts, weights, by = "exposure_id"),
                    by = "exposure_id", all.x = TRUE, sort = FALSE)
  } else {
    merged$protected_amount <- 0; merged$substitution_rw <- NA_real_
  }
  rows <- vector("list", nrow(merged))
  for (i in seq_len(nrow(merged))) {
    r <- merged[i, , drop = FALSE]
    ead_values <- sa_ead(
      rwa_num(r$gross_carrying_amount), rwa_num(r$specific_credit_adjustments),
      rwa_num(r$additional_valuation_adjustments), rwa_num(r$other_own_funds_reductions),
      rwa_num(r$committed_undrawn), as.character(r$annex_i_class),
      as.character(r$ead_data_path), rwa_num(r$net_carrying_amount_article_111), p)
    ead_on <- unname(ead_values[["ead_on"]]); ead_off <- unname(ead_values[["ead_off"]])
    ead <- unname(ead_values[["ead"]])
    coverage <- rwa_num(r$specific_credit_adjustments) / max(rwa_num(r$gross_carrying_amount), 1)
    rw <- sa_base_risk_weight(
      as.character(r$exposure_class), as.integer(rwa_num(r$credit_quality_step)),
      rwa_bool(r$short_term_flag), rwa_bool(r$transactor_flag),
      rwa_bool(r$retail_eligible_flag), rwa_bool(r$default_flag), coverage,
      rwa_text(row_value(r, "specialised_lending_type")), p)
    segments <- data.frame()
    if (!is.na(row_value(r, "property_type", NA))) {
      real_estate <- real_estate_weighted_rw(
        ead, rwa_num(r$prudent_property_value), as.character(r$property_type),
        rwa_bool(r$ipre_flag), rw, rwa_num(r$senior_liens), rwa_bool(r$adc_flag), p)
      rw <- real_estate$risk_weight; segments <- real_estate$segments
    }
    override <- row_value(r, "risk_weight_override", NA)
    if (!is.na(override)) rw <- as.numeric(override)
    if (rwa_bool(row_value(r, "currency_mismatch_flag", FALSE))) {
      rw <- min(parameter_get(p, "CURRENCY_MISMATCH", "MULTIPLIER") * rw,
                parameter_get(p, "CURRENCY_MISMATCH", "RW_CAP"))
    }
    protected <- min(rwa_num(row_value(r, "protected_amount", 0)), ead)
    unprotected <- ead - protected
    sub_rw <- rwa_num(row_value(r, "substitution_rw", rw), rw)
    rwea_pre <- ead * rw
    rwea_post <- unprotected * rw + protected * sub_rw
    support <- resolve_support_exposure(t, r, p, "SA")
    sf <- support$supporting_factor
    rwea_final <- rwea_post * sf
    rows[[i]] <- list(
      exposure_id = as.character(r$exposure_id), approach = as.character(r$approach),
      exposure_class = as.character(r$exposure_class), ead_on = ead_on,
      ead_off = ead_off, ccf = parameter_get(p, "SA_CCF", as.character(r$annex_i_class)),
      ead = ead, risk_weight = rw, protected_amount = protected,
      substitution_rw = sub_rw, rwea_pre_crm = rwea_pre, rwea_post_crm = rwea_post,
      supporting_factor = sf, rwea = rwea_final,
      actual_rwea = if (identical(as.character(r$approach), "KSA")) rwea_final else 0,
      shadow_rwea = rwea_final,
      segments = if (nrow(segments)) paste(capture.output(dput(segments)), collapse = "") else "[]",
      formula_id = "SA_EAD/SA_RW", formula_version = ctx$formula_version)
    rows[[i]][names(support)] <- support
    rows[[i]]$rwea_pre_supporting_factor <- rwea_post
    rows[[i]]$supporting_factor_relief <- rwea_post - rwea_final
  }
  sa_result <- rows_frame(rows)
  out$results$SA_Detail <- sa_result
  out$metrics$RWEA_KSA <- sum_column(sa_result, "actual_rwea")
  out$metrics$RWEA_KSA_SHADOW_ALL <- sum_column(sa_result, "shadow_rwea")

  crypto_rows <- lapply(seq_len(nrow(t$crypto_exposure)), function(i) {
    r <- t$crypto_exposure[i, , drop = FALSE]
    rw <- parameter_get(p, "CRYPTO_RW", as.character(r$crypto_class))
    list(exposure_id = as.character(r$exposure_id), crypto_class = as.character(r$crypto_class),
         market_value = rwa_num(r$market_value), risk_weight = rw,
         rwea = rwa_num(r$market_value) * rw,
         tier1_limit_relevant = rwa_bool(r$tier1_limit_relevant_flag),
         formula_id = "CRYPTO_TRANSITIONAL")
  })
  crypto_result <- rows_frame(crypto_rows,
    c("exposure_id", "crypto_class", "market_value", "risk_weight", "rwea",
      "tier1_limit_relevant", "formula_id"))
  out$results$Crypto_Detail <- crypto_result
  out$metrics$RWEA_CRYPTO <- sum_column(crypto_result, "rwea")

  if (!nrow(irb)) {
    irb_result <- empty_frame(c("exposure_id", "ead", "pd", "lgd", "r", "m", "k", "rw",
                                "rwea", "el_amount", "irb_shortfall", "irb_excess", "formula_id"))
  } else {
    base <- merge(exp_df, drop_overlap(irb, exp_df, "exposure_id"),
                  by = "exposure_id", sort = FALSE)
    irb_rows <- vector("list", nrow(base))
    for (i in seq_len(nrow(base))) {
      r <- base[i, , drop = FALSE]
      pdv <- max(rwa_num(r$pd_estimate), rwa_num(r$pd_floor))
      lgd <- max(rwa_num(r$lgd_estimate), rwa_num(r$lgd_floor))
      ead <- max(rwa_num(r$ead_estimate), rwa_num(r$ead_floor))
      defaulted <- rwa_bool(r$default_flag); subclass <- as.character(r$irb_subclass)
      retail <- startsWith(subclass, "RETAIL")
      sales <- rwa_num(row_value(r, "annual_sales_eur", 0))
      corr <- if (retail) retail_correlation(pdv, subclass, p) else
        irb_correlation(pdv, if (sales) sales / 1e6 else NULL,
                        rwa_bool(r$financial_multiplier_flag), p)
      k <- irb_k(pdv, lgd, corr, rwa_num(r$maturity_years, 1), !retail,
                 defaulted, rwa_num(r$elbe), p)
      rw <- parameter_get(p, "RWA_MULTIPLIER", "PILLAR1") * k
      support <- resolve_support_exposure(t, r, p, "IRB")
      rwea_before <- ead * rw
      rwea <- rwea_before * support$supporting_factor
      el_rate <- if (defaulted) rwa_num(r$elbe) else pdv * lgd
      coverage <- rwa_num(r$specific_credit_adjustments) + rwa_num(r$general_credit_adjustments)
      el <- ead * el_rate
      irb_rows[[i]] <- list(
        exposure_id = as.character(r$exposure_id), irb_approach = as.character(r$irb_approach),
        subclass = subclass, ead = ead, pd = pdv, lgd = lgd, r = corr,
        m = rwa_num(r$maturity_years), k = k, rw = rw, rwea = rwea,
        el_rate = el_rate, el_amount = el, coverage = coverage,
        irb_shortfall = max(el - coverage, 0), irb_excess = max(coverage - el, 0),
        formula_id = if (retail) "IRB_RETAIL_K" else "IRB_CORP_K",
        formula_version = ctx$formula_version)
      irb_rows[[i]][names(support)] <- support
      irb_rows[[i]]$rwea_pre_supporting_factor <- rwea_before
      irb_rows[[i]]$supporting_factor_relief <- rwea_before - rwea
      irb_rows[[i]]$effective_rw <- rw * support$supporting_factor
    }
    irb_result <- rows_frame(irb_rows)
  }
  if (!nrow(irb_result)) {
    fields <- c(names(resolve_support(list(), NULL, "IRB")), "rwea_pre_supporting_factor",
                "supporting_factor_relief", "effective_rw")
    for (name in fields) irb_result[[name]] <- logical()
  }
  match_sa <- match(as.character(irb_result$exposure_id), as.character(sa_result$exposure_id))
  irb_result$sa_comparison_supporting_factor <- sa_result$supporting_factor[match_sa]
  irb_result$supporting_factor_path_difference <- abs(as.numeric(irb_result$supporting_factor) -
    as.numeric(irb_result$sa_comparison_supporting_factor)) > 1e-10
  out$results$IRB_Detail <- irb_result
  out$metrics$RWEA_IRB <- sum_column(irb_result, "rwea")
  out$metrics$IRB_EL <- sum_column(irb_result, "el_amount")
  out$metrics$IRB_SHORTFALL <- sum_column(irb_result, "irb_shortfall")
  out$metrics$IRB_EXCESS <- sum_column(irb_result, "irb_excess")
  expected <- out$metrics$RWEA_KSA + out$metrics$RWEA_IRB
  add_control(out, "CREDIT_SUM", TRUE, expected,
              sum_column(sa_result, "actual_rwea") + sum_column(irb_result, "rwea"),
              "SA and IRB detail reconciliation")
  invisible(out)
}
