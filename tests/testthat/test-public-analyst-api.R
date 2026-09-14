test_that("all granular formula exports execute through the public API", {
  calls <- list(
    sa_exposure_value = quote(sa_exposure_value(100, 2, 0, 0, 40, "CLASS_2")),
    sa_risk_weight = quote(sa_risk_weight("CENTRAL_GOVERNMENT", 1)),
    real_estate_risk_weight = quote(real_estate_risk_weight(80, 100, "RESIDENTIAL", TRUE, 1)),
    crm_maturity_factor = quote(crm_maturity_factor(2, 5)),
    crm_adjusted_exposure = quote(crm_adjusted_exposure(100, 80, .1, .05, .08)),
    irb_asset_correlation = quote(irb_asset_correlation(.01)),
    irb_retail_correlation = quote(irb_retail_correlation(.01, "OTHER_RETAIL")),
    irb_maturity_coefficient = quote(irb_maturity_coefficient(.01)),
    irb_maturity_factor = quote(irb_maturity_factor(.01, 2.5)),
    irb_capital_requirement = quote(irb_capital_requirement(.01, .4, .2, 2.5)),
    sa_ccr_multiplier_value = quote(sa_ccr_multiplier_value(10, 4, 20)),
    sa_ccr_exposure_value = quote(sa_ccr_exposure_value(10, 4, 20, 1.4)),
    sft_exposure_value = quote(sft_exposure_value(100, 90, .1, .08)),
    securitisation_irb_pool_capital = quote(securitisation_irb_pool_capital(1000, 20, 2000)),
    securitisation_sa_pool_capital = quote(securitisation_sa_pool_capital(1000, 2000)),
    securitisation_ssfa_coefficient = quote(securitisation_ssfa_coefficient(.08, .1, .2, .5)),
    securitisation_ssfa_risk_weight = quote(securitisation_ssfa_risk_weight(.08, .1, .2, .5, .15)),
    securitisation_irba_p = quote(securitisation_irba_p("NON_RETAIL", TRUE, 30, .08, .4, 3, FALSE)),
    securitisation_erba_risk_weight = quote(securitisation_erba_risk_weight(3, 3, FALSE, FALSE, .1, .3)),
    securitisation_risk_weight = quote(securitisation_risk_weight("SEC_SA", .08, .1, .2, .5)),
    cva_basic_approach_capital = quote(cva_basic_approach_capital(list(c(.05, 2, 1e6, 0, 0, 0, 0, 0, 0)))),
    settlement_risk_factor = quote(settlement_risk_factor(20)),
    business_indicator_component = quote(business_indicator_component(rep(2e9, 3), rep(1e9, 3), rep(40e9, 3), rep(0, 3), rep(.2e9, 3), rep(.2e9, 3), rep(.3e9, 3), rep(.1e9, 3), rep(0, 3), rep(0, 3))),
    applicable_output_floor_factor = quote(applicable_output_floor_factor(as.Date("2026-12-31"))),
    apply_output_floor = quote(apply_output_floor(100, 180, .725)),
    npe_unsecured_coverage_factor = quote(npe_unsecured_coverage_factor(3)),
    npe_secured_coverage_factor = quote(npe_secured_coverage_factor(7, TRUE)),
    tier2_eligible_amount = quote(tier2_eligible_amount(100, 100, as.Date("2028-08-31"), as.Date("2026-08-31"))),
    irrbb_scenario_shock = quote(irrbb_scenario_shock("PARALLEL_UP", 5, .02, .025, .01)),
    irrbb_shocked_zero_rate = quote(irrbb_shocked_zero_rate(.01, -.02, 1)),
    present_value_discount_factor = quote(present_value_discount_factor(.03, 5)),
    aggregate_correlated_capital = quote(aggregate_correlated_capital(c(3, 4), diag(2))),
    frtb_scenario_correlation = quote(frtb_scenario_correlation(.25, "HIGH")),
    frtb_quadratic_charge = quote(frtb_quadratic_charge(c(1, -2), .5))
  )
  values <- lapply(calls, eval, envir = parent.frame())
  expect_true(all(vapply(values, function(x) length(x) > 0L, logical(1))))
})

test_that("analysts control parameters non-destructively with an audit trail", {
  tables <- generate_synthetic_tables(bank_profile = "KSA_BANK")
  original <- regulatory_parameters(tables)
  override <- data.frame(parameter_key = "RWA_MULTIPLIER", dimension_1 = "PILLAR1",
                         dimension_2 = "", parameter_value = 13)
  changed <- override_regulatory_parameters(tables, override, "Sensitivity", "Model Risk")
  expect_equal(regulatory_parameter("RWA_MULTIPLIER", "PILLAR1", parameters = original), 12.5)
  expect_equal(regulatory_parameter("RWA_MULTIPLIER", "PILLAR1",
                                    parameters = regulatory_parameters(changed)), 13)
  audit <- parameter_overrides(changed)
  expect_equal(audit$old_value, 12.5)
  expect_equal(audit$new_value, 13)
  expect_equal(audit$reason, "Sensitivity")
  expect_error(override_regulatory_parameters(tables, override, "", "Model Risk"),
               class = "rwa_configuration_error")
})

test_that("one result supports granular analyst views and applied/full comparison", {
  result <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
  expect_length(result$parallel_metrics, 63L)
  expect_length(result$parallel_results, 34L)
  expect_equal(nrow(failed_controls(result)), 0L)
  expect_true(all(c("metric", "applied", "fully_loaded", "difference") %in%
                    names(compare_calculation_views(result))))
  analyses <- list(
    analyze_credit_risk(result), analyze_counterparty_risk(result),
    analyze_securitisation(result), analyze_market_risk(result),
    analyze_operational_risk(result), analyze_output_floor(result),
    analyze_capital_adequacy(result), analyze_irrbb(result), analyze_icaap(result)
  )
  expect_true(all(vapply(analyses, inherits, logical(1), "rwa_domain_analysis")))
  expect_true(all(vapply(analyses, function(x) nrow(x$metrics) > 0L, logical(1))))
  expect_equal(rwa_metric(result, "TREA"), result$metrics$TREA)
  expect_equal(rwa_result_table(result, "Capital_Stack"), result$results$Capital_Stack)
})

test_that("every exported function has an Rd alias", {
  exports <- getNamespaceExports("riskweightedassets")
  aliases <- unique(unlist(lapply(tools::Rd_db("riskweightedassets"), function(rd) {
    nodes <- rd[vapply(rd, function(node) identical(attr(node, "Rd_tag"), "\\alias"), logical(1))]
    vapply(nodes, function(node) as.character(node[[1L]]), character(1))
  }), use.names = FALSE))
  expect_setequal(setdiff(exports, aliases), character())
})
