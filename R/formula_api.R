# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

#' Standardised Credit-risk and CRM Formulae
#'
#' Granular, side-effect-free formulae for exposure value, risk weights, real
#' estate treatment and credit-risk mitigation. Rates and weights are decimals.
#' Monetary inputs and outputs use one caller-selected currency consistently.
#'
#' @param gross_carrying_amount,specific_adjustments,additional_valuation_adjustments,other_own_funds_reductions Monetary amounts.
#' @param committed_undrawn Undrawn commitment amount.
#' @param annex_i_class CRR Annex I conversion-factor class.
#' @param data_path `"GROSS_COMPONENTS"` or `"NET_ARTICLE_111"`.
#' @param net_carrying_amount_article_111 Optional net carrying amount.
#' @param exposure_class,cqs Exposure class and credit-quality step.
#' @param short_term,transactor,retail_eligible,defaulted Logical classification flags.
#' @param default_coverage_ratio Coverage ratio for defaulted exposures.
#' @param specialised_lending_type Optional specialised-lending category.
#' @param ead,property_value,senior_liens Monetary real-estate inputs.
#' @param property_type Property category.
#' @param ipre,adc Logical real-estate flags.
#' @param counterparty_rw Counterparty risk weight.
#' @param t_protection,t_exposure,minimum_t,maximum_T Maturity-mismatch inputs in years.
#' @param exposure,collateral Exposure and collateral values.
#' @param he,hc,hfx Exposure, collateral and currency haircuts.
#' @param parameters Optional parameter data frame or `rwa_parameter_store`;
#'   bundled regulatory parameters are used by default.
#' @return Numeric value, named numeric vector, or documented list depending on the formula.
#' @seealso [regulatory_parameters()], [override_regulatory_parameters()]
#' @examples
#' sa_exposure_value(100, 2, 0, 0, 40, "CLASS_2", "GROSS_COMPONENTS")
#' crm_adjusted_exposure(100, 60, 0.05, 0.10, 0.08)
#' @export
sa_exposure_value <- function(gross_carrying_amount, specific_adjustments = 0,
                              additional_valuation_adjustments = 0,
                              other_own_funds_reductions = 0,
                              committed_undrawn = 0, annex_i_class,
                              data_path = "GROSS_COMPONENTS",
                              net_carrying_amount_article_111 = NULL,
                              parameters = NULL) {
  sa_ead(gross_carrying_amount, specific_adjustments,
         additional_valuation_adjustments, other_own_funds_reductions,
         committed_undrawn, annex_i_class, data_path,
         net_carrying_amount_article_111, as_public_parameter_store(parameters))
}

#' @rdname sa_exposure_value
#' @export
sa_risk_weight <- function(exposure_class, cqs = NULL, short_term = FALSE,
                           transactor = FALSE, retail_eligible = FALSE,
                           defaulted = FALSE, default_coverage_ratio = 0,
                           specialised_lending_type = "", parameters = NULL) {
  sa_base_risk_weight(exposure_class, cqs, short_term, transactor,
                      retail_eligible, defaulted, default_coverage_ratio,
                      specialised_lending_type, as_public_parameter_store(parameters))
}

#' @rdname sa_exposure_value
#' @export
real_estate_risk_weight <- function(ead, property_value, property_type, ipre,
                                    counterparty_rw, senior_liens = 0,
                                    adc = FALSE, parameters = NULL) {
  real_estate_weighted_rw(ead, property_value, property_type, ipre,
                          counterparty_rw, senior_liens, adc,
                          as_public_parameter_store(parameters))
}

#' @rdname sa_exposure_value
#' @export
crm_maturity_factor <- function(t_protection, t_exposure, minimum_t = 0.25,
                                maximum_T = 5) {
  crm_maturity_mismatch_factor(t_protection, t_exposure, minimum_t, maximum_T)
}

#' @rdname sa_exposure_value
#' @export
crm_adjusted_exposure <- function(exposure, collateral, he, hc, hfx) {
  comprehensive_crm(exposure, collateral, he, hc, hfx)
}

#' Internal Ratings Based Formulae
#'
#' Direct access to IRB asset correlations, maturity adjustment and capital
#' requirement. Probability, LGD and correlation inputs are decimal rates.
#'
#' @param pd Probability of default.
#' @param annual_sales_million Optional annual sales in millions.
#' @param financial_multiplier Whether to apply the financial-sector multiplier.
#' @param subclass Retail exposure subclass.
#' @param maturity Effective maturity in years.
#' @param lgd Loss given default.
#' @param correlation Asset correlation.
#' @param apply_maturity_adjustment Whether the maturity adjustment applies.
#' @param defaulted Whether the exposure is defaulted.
#' @param elbe Best estimate of expected loss for a defaulted exposure.
#' @param parameters Optional parameter data frame or store.
#' @return One numeric coefficient or capital-requirement rate.
#' @seealso [regulatory_parameters()]
#' @examples
#' irb_asset_correlation(0.01)
#' irb_capital_requirement(0.01, 0.45, 0.20, 2.5, TRUE, FALSE, 0)
#' @export
irb_asset_correlation <- function(pd, annual_sales_million = NULL,
                                  financial_multiplier = FALSE,
                                  parameters = NULL) {
  irb_correlation(pd, annual_sales_million, financial_multiplier,
                  as_public_parameter_store(parameters))
}

#' @rdname irb_asset_correlation
#' @export
irb_retail_correlation <- function(pd, subclass, parameters = NULL) {
  retail_correlation(pd, subclass, as_public_parameter_store(parameters))
}

#' @rdname irb_asset_correlation
#' @export
irb_maturity_coefficient <- function(pd, parameters = NULL) {
  irb_maturity_b(pd, as_public_parameter_store(parameters))
}

#' @rdname irb_asset_correlation
#' @export
irb_maturity_factor <- function(pd, maturity, parameters = NULL) {
  irb_maturity_adjustment(pd, maturity, as_public_parameter_store(parameters))
}

#' @rdname irb_asset_correlation
#' @export
irb_capital_requirement <- function(pd, lgd, correlation, maturity,
                                    apply_maturity_adjustment = TRUE,
                                    defaulted = FALSE, elbe = 0,
                                    parameters = NULL) {
  irb_k(pd, lgd, correlation, maturity, apply_maturity_adjustment,
        defaulted, elbe, as_public_parameter_store(parameters))
}

#' Counterparty, SFT, Securitisation, CVA and Settlement Formulae
#'
#' Granular formula interface for SA-CCR, SFT, securitisation approaches,
#' BA-CVA and settlement risk. Rates are decimal values.
#'
#' @param V,C Current value and collateral under SA-CCR.
#' @param addon Aggregate SA-CCR add-on.
#' @param alpha SA-CCR regulatory alpha.
#' @param cash_leg,security_value Monetary SFT legs.
#' @param security_haircut,fx_haircut Haircuts.
#' @param rwea_pool_irb_ul,el_pool_irb,rwea_pool_sa,pool_ead Pool inputs.
#' @param ka,pool_k Pool capital ratio.
#' @param attachment,detachment Tranche attachment and detachment points.
#' @param p Supervisory SSFA parameter.
#' @param floor Minimum risk weight.
#' @param pool_type Pool category.
#' @param senior,sts,resecuritisation Logical tranche flags.
#' @param effective_number Effective number of pool exposures.
#' @param average_lgd Average pool LGD.
#' @param tranche_maturity,maturity Maturity in years.
#' @param cqs Credit-quality step.
#' @param approach Securitisation approach.
#' @param items BA-CVA rows, each with the documented nine numeric fields.
#' @param days_late Settlement delay in days.
#' @param parameters Optional parameter data frame or store.
#' @return Numeric formula result or named vector.
#' @seealso [analyze_counterparty_risk()], [analyze_securitisation()]
#' @examples
#' sa_ccr_exposure_value(100, 30, 20, 1.4)
#' sft_exposure_value(100, 90, 0.1, 0.05)
#' @export
sa_ccr_multiplier_value <- function(V, C, addon, parameters = NULL) {
  sa_ccr_multiplier(V, C, addon, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
sa_ccr_exposure_value <- function(V, C, addon, alpha, parameters = NULL) {
  sa_ccr_ead(V, C, addon, alpha, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
sft_exposure_value <- function(cash_leg, security_value, security_haircut, fx_haircut) {
  sft_ead(cash_leg, security_value, security_haircut, fx_haircut)
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_irb_pool_capital <- function(rwea_pool_irb_ul, el_pool_irb,
                                            pool_ead, parameters = NULL) {
  sec_k_irb(rwea_pool_irb_ul, el_pool_irb, pool_ead,
            as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_sa_pool_capital <- function(rwea_pool_sa, pool_ead,
                                           parameters = NULL) {
  sec_k_sa(rwea_pool_sa, pool_ead, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_ssfa_coefficient <- function(ka, attachment, detachment, p) {
  ssfa_k(ka, attachment, detachment, p)
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_ssfa_risk_weight <- function(pool_k, attachment, detachment, p,
                                            floor, parameters = NULL) {
  securitisation_ssfa_rw(pool_k, attachment, detachment, p, floor,
                         as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_irba_p <- function(pool_type, senior, effective_number, pool_k,
                                  average_lgd, tranche_maturity, sts,
                                  parameters = NULL) {
  sec_irba_p(pool_type, senior, effective_number, pool_k, average_lgd,
             tranche_maturity, sts, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_erba_risk_weight <- function(cqs, maturity, senior, sts,
                                            attachment, detachment,
                                            parameters = NULL) {
  sec_erba_rw(cqs, maturity, senior, sts, attachment, detachment,
              as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
securitisation_risk_weight <- function(approach, pool_k, attachment, detachment,
                                       p, sts = FALSE, senior = FALSE,
                                       resecuritisation = FALSE, cqs = 0,
                                       parameters = NULL) {
  securitisation_rw(approach, pool_k, attachment, detachment, p, sts, senior,
                    resecuritisation, cqs, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
cva_basic_approach_capital <- function(items, parameters = NULL) {
  ba_cva_capital(items, as_public_parameter_store(parameters))
}

#' @rdname sa_ccr_multiplier_value
#' @export
settlement_risk_factor <- function(days_late, parameters = NULL) {
  settlement_factor(days_late, as_public_parameter_store(parameters))
}

#' Operational Risk, Output Floor, NPE and Tier-2 Formulae
#'
#' @param il,ie,assets,dividends,oi,oe,fi,fe,trading_pnl,banking_pnl Numeric
#'   vectors for the business-indicator components.
#' @param as_of Reporting date.
#' @param fully_loaded Whether to return the fully-loaded floor factor.
#' @param u_trea Unfloored TREA.
#' @param s_trea Standardised TREA.
#' @param factor Output-floor factor.
#' @param optional_cap Whether an optional cap applies.
#' @param cap_multiplier Cap multiple of unfloored TREA.
#' @param year NPE vintage year.
#' @param property_security Whether secured by property.
#' @param current_amount,first_day_amount Tier-2 instrument amounts.
#' @param maturity Tier-2 maturity date.
#' @param parameters Optional parameter data frame or store.
#' @return Numeric, named numeric vector, or output-floor result list.
#' @examples
#' apply_output_floor(100, 180, 0.725, FALSE, 1)
#' applicable_output_floor_factor(as.Date("2026-12-31"), FALSE)
#' @export
business_indicator_component <- function(il, ie, assets, dividends, oi, oe,
                                         fi, fe, trading_pnl, banking_pnl,
                                         parameters = NULL) {
  bic_from_components(il, ie, assets, dividends, oi, oe, fi, fe,
                      trading_pnl, banking_pnl, as_public_parameter_store(parameters))
}

#' @rdname business_indicator_component
#' @export
applicable_output_floor_factor <- function(as_of, fully_loaded = FALSE,
                                           parameters = NULL) {
  output_floor_factor(as_of, fully_loaded, as_public_parameter_store(parameters))
}

#' @rdname business_indicator_component
#' @export
apply_output_floor <- function(u_trea, s_trea, factor, optional_cap = FALSE,
                               cap_multiplier = 1) {
  output_floor(u_trea, s_trea, factor, optional_cap, cap_multiplier)
}

#' @rdname business_indicator_component
#' @export
npe_unsecured_coverage_factor <- function(year, parameters = NULL) {
  npe_unsecured_factor(year, as_public_parameter_store(parameters))
}

#' @rdname business_indicator_component
#' @export
npe_secured_coverage_factor <- function(year, property_security = TRUE,
                                        parameters = NULL) {
  npe_secured_factor(year, property_security, as_public_parameter_store(parameters))
}

#' @rdname business_indicator_component
#' @export
tier2_eligible_amount <- function(current_amount, first_day_amount, maturity,
                                  as_of, parameters = NULL) {
  t2_eligible_amount(current_amount, first_day_amount, maturity, as_of,
                     as_public_parameter_store(parameters))
}

#' IRRBB, FRTB and Economic-capital Formulae
#'
#' @param scenario IRRBB or FRTB correlation scenario.
#' @param t Time in years.
#' @param parallel,short,long Scenario shocks as decimal rates.
#' @param base Base continuously compounded zero rate or base correlation.
#' @param shock Rate shock.
#' @param continuous_zero_rate Continuously compounded zero rate.
#' @param capitals Vector of standalone capital amounts.
#' @param correlation Correlation matrix or scalar intra-bucket correlation.
#' @param values Weighted sensitivities.
#' @param curvature Whether curvature aggregation applies.
#' @param parameters Optional parameter data frame or store.
#' @return Numeric shock, rate, discount factor or aggregated capital.
#' @examples
#' present_value_discount_factor(0.03, 5)
#' aggregate_correlated_capital(c(10, 20), matrix(c(1, .25, .25, 1), 2))
#' @export
irrbb_scenario_shock <- function(scenario, t, parallel, short, long,
                                 parameters = NULL) {
  irrbb_shock(scenario, t, parallel, short, long, as_public_parameter_store(parameters))
}

#' @rdname irrbb_scenario_shock
#' @export
irrbb_shocked_zero_rate <- function(base, shock, t, parameters = NULL) {
  shocked_zero_rate(base, shock, t, as_public_parameter_store(parameters))
}

#' @rdname irrbb_scenario_shock
#' @export
present_value_discount_factor <- function(continuous_zero_rate, t) {
  discount_factor(continuous_zero_rate, t)
}

#' @rdname irrbb_scenario_shock
#' @export
aggregate_correlated_capital <- function(capitals, correlation) {
  correlated_capital(capitals, correlation)
}

#' @rdname irrbb_scenario_shock
#' @export
frtb_scenario_correlation <- function(base, scenario, parameters = NULL) {
  market_scenario_correlation(base, scenario, as_public_parameter_store(parameters))
}

#' @rdname irrbb_scenario_shock
#' @export
frtb_quadratic_charge <- function(values, correlation, curvature = FALSE) {
  market_quadratic(values, correlation, curvature)
}
