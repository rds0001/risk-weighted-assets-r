# Bank-analyst API map

The API is organized around questions an analyst must answer, not around the
engine's internal call graph. All formula rates are decimals; monetary values
use one caller-selected currency consistently. Regulatory defaults are visible
through `regulatory_parameters()` and may be replaced explicitly for a governed
sensitivity analysis.

## Calculation and data lifecycle

`calculate_tables()`, `calculate_dataset()`, `validate_dataset()`,
`generate_synthetic_tables()`, `generate_synthetic_dataset()`,
`create_workspace()`, `default_workspace()`, `official_snapshot()`,
`select_rule_set()`, `list_reference_profiles()` and
`list_reference_datasets()` cover the controlled lifecycle.

## Analyst control and auditability

`regulatory_parameters()` and `regulatory_parameter()` expose all coefficients
and weights. `override_regulatory_parameters()` returns a modified copy and
requires both a business reason and approval reference. `parameter_overrides()`
returns old value, new value and governance evidence. No override silently
mutates package defaults. `formula_catalog()`, `available_rule_sets()`,
`table_dictionary()`, `table_schema()` and `regulatory_sources()` expose the
methodological, data and provenance context.

A changed coefficient belongs in an override. A structurally changed formula
requires versioned package code, formula-catalog revision, golden tests and
review; arbitrary runtime evaluation is intentionally not supported.

## Standardised credit and CRM

`sa_exposure_value()`, `sa_risk_weight()`, `real_estate_risk_weight()`,
`crm_maturity_factor()` and `crm_adjusted_exposure()` answer exposure-level SA
and CRM questions.

## IRB

`irb_asset_correlation()`, `irb_retail_correlation()`,
`irb_maturity_coefficient()`, `irb_maturity_factor()` and
`irb_capital_requirement()` expose the IRB formula chain.

## Counterparty, SFT, securitisation and settlement

`sa_ccr_multiplier_value()`, `sa_ccr_exposure_value()`,
`sft_exposure_value()`, `cva_basic_approach_capital()`,
`settlement_risk_factor()`, `securitisation_irb_pool_capital()`,
`securitisation_sa_pool_capital()`, `securitisation_ssfa_coefficient()`,
`securitisation_ssfa_risk_weight()`, `securitisation_irba_p()`,
`securitisation_erba_risk_weight()` and `securitisation_risk_weight()` expose
the respective calculation steps.

## Operational risk, capital and output floor

`business_indicator_component()`, `applicable_output_floor_factor()`,
`apply_output_floor()`, `npe_unsecured_coverage_factor()`,
`npe_secured_coverage_factor()` and `tier2_eligible_amount()` support isolated
capital and own-funds analysis.

## IRRBB, FRTB and economic capital

`irrbb_scenario_shock()`, `irrbb_shocked_zero_rate()`,
`present_value_discount_factor()`, `frtb_scenario_correlation()`,
`frtb_quadratic_charge()` and `aggregate_correlated_capital()` expose reusable
market, valuation and diversification mathematics.

## Domain packages from one controlled snapshot

`analyze_credit_risk()`, `analyze_counterparty_risk()`,
`analyze_securitisation()`, `analyze_market_risk()`,
`analyze_operational_risk()`, `analyze_output_floor()`,
`analyze_capital_adequacy()`, `analyze_irrbb()` and `analyze_icaap()` return a
focused `rwa_domain_analysis`. Passing an existing result avoids recalculation;
passing canonical tables performs the validated calculation first.

## Result interrogation

`rwa_metrics()`, `rwa_metric()`, `rwa_result_tables()`,
`rwa_result_table()`, `rwa_table_names()`, `rwa_controls()`,
`failed_controls()`, `rwa_validation()`, `compare_calculation_views()` and
`rwa_summary()` provide explicit access to applied and fully-loaded views.
These accessors replace fragile direct list indexing in production analysis.
