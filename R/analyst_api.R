# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

as_rwa_result <- function(x) {
  if (inherits(x, "rwa_calculation_result")) return(x)
  if (is.list(x) && !is.null(names(x)) && all(vapply(x, is.data.frame, logical(1)))) {
    return(calculate_tables(x))
  }
  abort_calculation("x must be canonical tables or an rwa_calculation_result")
}

normalize_view <- function(view) match.arg(view, c("applied", "fully_loaded"))

view_component <- function(result, view, applied, parallel) {
  view <- normalize_view(view)
  value <- result[[if (view == "applied") applied else parallel]]
  if (is.null(value)) abort_calculation(sprintf("Result does not contain %s data", view))
  value
}

#' Regulatory Parameter Inventory
#'
#' Returns the effective parameter table used by granular formulas. Analysts can
#' inspect every weight and coefficient before calculation.
#' @param tables Optional canonical table list. If omitted, bundled defaults are used.
#' @return A data frame containing parameter keys, dimensions and values.
#' @seealso [regulatory_parameter()], [override_regulatory_parameters()]
#' @examples
#' head(regulatory_parameters())
#' @export
regulatory_parameters <- function(tables = NULL) {
  if (is.null(tables)) return(default_parameter_store()$frame)
  if (!is.list(tables) || is.null(tables$regulatory_parameter)) {
    abort_configuration("tables must contain regulatory_parameter")
  }
  tables$regulatory_parameter
}

#' Read One Regulatory Parameter
#'
#' @param key Regulatory parameter key.
#' @param dimension_1,dimension_2 Optional parameter dimensions.
#' @param parameters A parameter-store object or parameter data frame. Bundled
#'   regulatory defaults are used when omitted.
#' @return One numeric parameter value.
#' @seealso [regulatory_parameters()]
#' @examples
#' regulatory_parameter("RWA_MULTIPLIER", "PILLAR1")
#' @export
regulatory_parameter <- function(key, dimension_1 = "", dimension_2 = "",
                                 parameters = NULL) {
  parameter_get(as_public_parameter_store(parameters), key, dimension_1, dimension_2)
}

as_public_parameter_store <- function(parameters = NULL) {
  if (is.null(parameters)) return(default_parameter_store())
  if (inherits(parameters, "rwa_parameter_store")) return(parameters)
  if (is.data.frame(parameters)) return(new_parameter_store(parameters))
  abort_configuration("parameters must be NULL, a parameter data frame or rwa_parameter_store")
}

#' Apply Auditable Regulatory Parameter Overrides
#'
#' Creates a modified copy of canonical tables. Existing parameter rows are
#' replaced only when key and both dimensions identify exactly one row. The
#' original input is not mutated and an audit record is attached.
#' @param tables Canonical input tables.
#' @param overrides Data frame with `parameter_key`, `parameter_value` and
#'   optional `dimension_1`, `dimension_2` columns.
#' @param reason Non-empty business rationale.
#' @param approved_by Non-empty approver or governance reference.
#' @return A copied table list carrying an `rwa_parameter_overrides` audit attribute.
#' @seealso [parameter_overrides()], [calculate_tables()]
#' @examples
#' t <- generate_synthetic_tables(bank_profile = "KSA_BANK")
#' o <- data.frame(parameter_key = "RWA_MULTIPLIER", dimension_1 = "PILLAR1",
#'                 dimension_2 = "", parameter_value = 12.5)
#' t2 <- override_regulatory_parameters(t, o, "Sensitivity", "Model Risk")
#' parameter_overrides(t2)
#' @export
override_regulatory_parameters <- function(tables, overrides, reason, approved_by) {
  if (!is.list(tables) || is.null(tables$regulatory_parameter)) {
    abort_configuration("tables must contain regulatory_parameter")
  }
  if (!is.data.frame(overrides) || !all(c("parameter_key", "parameter_value") %in% names(overrides))) {
    abort_configuration("overrides must contain parameter_key and parameter_value")
  }
  if (!nzchar(trimws(as.character(reason))) || !nzchar(trimws(as.character(approved_by)))) {
    abort_configuration("reason and approved_by must be non-empty")
  }
  for (column in c("dimension_1", "dimension_2")) if (!column %in% names(overrides)) overrides[[column]] <- ""
  if (!nrow(overrides)) return(tables)
  values <- suppressWarnings(as.numeric(overrides$parameter_value))
  if (anyNA(values)) abort_configuration("Every override value must be numeric")
  frame <- tables$regulatory_parameter
  audit <- vector("list", nrow(overrides))
  for (i in seq_len(nrow(overrides))) {
    key <- normalize_dimension(overrides$parameter_key[[i]])
    d1 <- normalize_dimension(overrides$dimension_1[[i]])
    d2 <- normalize_dimension(overrides$dimension_2[[i]])
    hit <- vapply(frame$parameter_key, normalize_dimension, character(1)) == key &
      vapply(frame$dimension_1, normalize_dimension, character(1)) == d1 &
      vapply(frame$dimension_2, normalize_dimension, character(1)) == d2
    if (sum(hit) != 1L) abort_configuration(sprintf(
      "Override must identify exactly one parameter: %s[%s,%s]", key, d1, d2))
    old <- as.numeric(frame$parameter_value[hit])
    frame$parameter_value[hit] <- values[[i]]
    audit[[i]] <- data.frame(
      sequence = i, parameter_key = key, dimension_1 = d1, dimension_2 = d2,
      old_value = old, new_value = values[[i]], reason = as.character(reason),
      approved_by = as.character(approved_by), stringsAsFactors = FALSE)
  }
  tables$regulatory_parameter <- frame
  attr(tables, "rwa_parameter_overrides") <- do.call(rbind, audit)
  tables
}

#' Parameter Override Audit Trail
#'
#' @param x Canonical tables or an `rwa_calculation_result`.
#' @return A data frame of old/new values and governance information.
#' @seealso [override_regulatory_parameters()]
#' @examples
#' parameter_overrides(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' @export
parameter_overrides <- function(x) {
  if (inherits(x, "rwa_calculation_result")) return(x$parameter_overrides %||% data.frame())
  attr(x, "rwa_parameter_overrides") %||% data.frame()
}

#' Formula Catalogue
#'
#' @param tables Optional canonical tables; bundled reference tables are used otherwise.
#' @return The versioned formula-definition data frame.
#' @seealso [regulatory_parameters()]
#' @examples
#' head(formula_catalog())
#' @export
formula_catalog <- function(tables = NULL) {
  if (is.null(tables)) tables <- readRDS(package_resource("extdata", "canonical", "reference_tables.rds"))
  tables$formula_definition
}

#' Available Rule Sets
#'
#' @inheritParams formula_catalog
#' @return The rule-set data frame.
#' @seealso [select_rule_set()]
#' @examples
#' available_rule_sets()
#' @export
available_rule_sets <- function(tables = NULL) {
  if (is.null(tables)) tables <- readRDS(package_resource("extdata", "canonical", "reference_tables.rds"))
  tables$rule_set
}

#' Select a Rule Set
#'
#' Returns a modified copy of canonical tables with the requested rule set in
#' `run_config`; it never mutates the caller's object.
#' @param tables Canonical input tables.
#' @param rule_set_id Identifier listed by [available_rule_sets()].
#' @return Modified canonical tables.
#' @examples
#' t <- generate_synthetic_tables(bank_profile = "KSA_BANK")
#' t <- select_rule_set(t, "CRR3-EU-FL")
#' @export
select_rule_set <- function(tables, rule_set_id) {
  available <- as.character(tables$rule_set$rule_set_id)
  if (!rule_set_id %in% available) abort_configuration("Unknown rule_set_id")
  hit <- as.character(tables$run_config$config_key) == "rule_set_id"
  if (sum(hit) != 1L) abort_configuration("run_config must contain one rule_set_id")
  tables$run_config$config_value[hit] <- as.character(rule_set_id)
  tables
}

#' Canonical Table Dictionary
#'
#' @return A data frame describing all logical tables, workbooks and sheets.
#' @seealso [table_schema()]
#' @examples
#' head(table_dictionary())
#' @export
table_dictionary <- function() {
  contracts <- table_contracts()
  rows_frame(lapply(names(contracts), function(name) data.frame(
    table = name, workbook = contracts[[name]]$workbook,
    sheet = contracts[[name]]$sheet, excel_table = contracts[[name]]$table_name,
    required = isTRUE(contracts[[name]]$required),
    column_count = length(contracts[[name]]$columns), stringsAsFactors = FALSE)))
}

#' Canonical Table Schema
#'
#' @param table Logical table name from [table_dictionary()].
#' @return A list with workbook, sheet, Excel table, required flag and columns.
#' @examples
#' table_schema("exposure_lot")
#' @export
table_schema <- function(table) {
  contracts <- table_contracts()
  if (!table %in% names(contracts)) abort_configuration("Unknown canonical table")
  contracts[[table]]
}

#' Select the Official Bitemporal Snapshot
#'
#' @param tables Canonical table list.
#' @param as_of_date Optional business date; defaults to `run_config`.
#' @param knowledge_time Optional knowledge timestamp; defaults to `run_config`.
#' @return Canonical tables reduced to the effective official records.
#' @examples
#' t <- generate_synthetic_tables(bank_profile = "KSA_BANK")
#' s <- official_snapshot(t)
#' @export
official_snapshot <- function(tables, as_of_date = NULL, knowledge_time = NULL) {
  cfg <- run_configuration(tables)
  as_of_date <- as_of_date %||% as.Date(cfg[["as_of_date"]])
  knowledge_time <- knowledge_time %||% as.POSIXct(sub("Z$", "", cfg[["knowledge_time"]]), tz = "UTC")
  snapshot <- lapply(tables, select_official_as_of,
                     as_of_date = as.Date(as_of_date), knowledge_time = knowledge_time)
  apply_official_designations(tables, snapshot)
}

#' Calculation Metrics
#'
#' @param result An `rwa_calculation_result`.
#' @param view `"applied"` or `"fully_loaded"`.
#' @return A tidy data frame with metric, value, unit and view.
#' @seealso [rwa_metric()], [compare_calculation_views()]
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_metrics(r)
#' @export
rwa_metrics <- function(result, view = c("applied", "fully_loaded")) {
  metrics <- view_component(as_rwa_result(result), view, "metrics", "parallel_metrics")
  keys <- names(metrics)
  data.frame(metric = keys, value = as.numeric(unlist(metrics, use.names = FALSE)),
             unit = ifelse(grepl("RATIO|RATE|FACTOR", keys), "RATE", "EUR"),
             view = toupper(normalize_view(view)), stringsAsFactors = FALSE)
}

#' Read One Calculation Metric
#'
#' @inheritParams rwa_metrics
#' @param metric Metric identifier.
#' @return One numeric value.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_metric(r, "CET1_RATIO")
#' @export
rwa_metric <- function(result, metric, view = c("applied", "fully_loaded")) {
  metrics <- view_component(as_rwa_result(result), view, "metrics", "parallel_metrics")
  if (!metric %in% names(metrics)) abort_calculation(sprintf("Unknown metric: %s", metric))
  as.numeric(metrics[[metric]])
}

#' Result Tables
#'
#' @inheritParams rwa_metrics
#' @return A named list of result data frames.
#' @seealso [rwa_result_table()], [rwa_table_names()]
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' names(rwa_result_tables(r))
#' @export
rwa_result_tables <- function(result, view = c("applied", "fully_loaded")) {
  view_component(as_rwa_result(result), view, "results", "parallel_results")
}

#' Read One Result Table
#'
#' @inheritParams rwa_metrics
#' @param table Result-table name.
#' @return A result data frame.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_result_table(r, "Capital_Stack")
#' @export
rwa_result_table <- function(result, table, view = c("applied", "fully_loaded")) {
  tables <- rwa_result_tables(result, view)
  if (!table %in% names(tables)) abort_calculation(sprintf("Unknown result table: %s", table))
  tables[[table]]
}

#' List Result-Table Names
#'
#' @inheritParams rwa_metrics
#' @return Character vector of result-table names.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_table_names(r)
#' @export
rwa_table_names <- function(result, view = c("applied", "fully_loaded")) {
  names(rwa_result_tables(result, view))
}

#' Calculation Controls
#'
#' @inheritParams rwa_metrics
#' @return A data frame containing reconciliation and governance controls.
#' @seealso [failed_controls()]
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_controls(r)
#' @export
rwa_controls <- function(result, view = c("applied", "fully_loaded")) {
  controls <- view_component(as_rwa_result(result), view, "controls", "parallel_controls")
  rows_frame(controls)
}

#' Failed Calculation Controls
#'
#' @inheritParams rwa_metrics
#' @return A data frame containing only failed controls.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' failed_controls(r)
#' @export
failed_controls <- function(result, view = c("applied", "fully_loaded")) {
  controls <- rwa_controls(result, view)
  if (!nrow(controls)) return(controls)
  controls[!vapply(controls$passed, rwa_bool, logical(1)), , drop = FALSE]
}

#' Calculation Validation Report
#'
#' @param result An `rwa_calculation_result`.
#' @return The `rwa_validation_report` attached to the result.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_validation(r)
#' @export
rwa_validation <- function(result) as_rwa_result(result)$validation

#' Compare Applied and Fully-loaded Metrics
#'
#' @param result An `rwa_calculation_result`.
#' @return A data frame with both values and their difference.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' compare_calculation_views(r)
#' @export
compare_calculation_views <- function(result) {
  applied <- rwa_metrics(result, "applied")[, c("metric", "value")]
  full <- rwa_metrics(result, "fully_loaded")[, c("metric", "value")]
  names(applied)[2] <- "applied"; names(full)[2] <- "fully_loaded"
  out <- merge(applied, full, by = "metric", all = TRUE, sort = TRUE)
  out$difference <- out$fully_loaded - out$applied
  out
}

#' Compact Calculation Summary
#'
#' @param result An `rwa_calculation_result`.
#' @return A list with identity, core metrics, controls and overrides.
#' @examplesIf interactive()
#' r <- calculate_tables(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' rwa_summary(r)
#' @export
rwa_summary <- function(result) {
  result <- as_rwa_result(result)
  core <- c("TREA", "CET1_RATIO", "TOTAL_CAPITAL_RATIO", "LEVERAGE_RATIO",
            "EVE_SOT_RATIO", "NII_SOT_RATIO", "ECONOMIC_HEADROOM")
  list(run_id = result$run_id, rule_set_id = result$rule_set_id,
       metrics = result$metrics[intersect(core, names(result$metrics))],
       controls = c(passed = controls_passed(result), total = control_count(result)),
       parameter_overrides = parameter_overrides(result))
}

domain_specification <- function(domain) {
  specs <- list(
    credit = list(metrics = "^(RWEA_KSA|RWEA_IRB|RWEA_CRYPTO|IRB_)", tables = c("SA_Detail", "IRB_Detail", "Crypto_Detail"), controls = "IRB|CREDIT|CRYPTO"),
    counterparty = list(metrics = "^(RWEA_CCR|RWEA_SFT|RWEA_CCP|K_CVA|K_SETTLEMENT|K_LARGE)", tables = c("CCR_Detail", "SFT_Detail", "CCP_Detail", "CVA_Summary", "CVA_Buckets", "Settlement_Detail", "Large_Exposure"), controls = "CCR|CVA|SFT|CCP|SETTLEMENT|LARGE"),
    securitisation = list(metrics = "SECURITISATION", tables = "SEC_Detail", controls = "SEC|FORMULA"),
    market = list(metrics = "MARKET", tables = c("Market_Legacy", "FRTB_Buckets", "FRTB_Risk_Classes", "FRTB_DRC", "FRTB_Summary", "FRTB_IMA"), controls = "MARKET|FRTB"),
    operational = list(metrics = "OPERATIONAL", tables = "Operational_Risk", controls = "OPRISK"),
    floor = list(metrics = "TREA|FLOOR", tables = c("TREA_Summary", "Floor_Allocation"), controls = "FLOOR"),
    capital = list(metrics = "CET1|TIER1|TOTAL_|AT1|T2|P2R|CBR|P2G|LEVERAGE|MREL|TLAC", tables = c("Prudent_Valuation", "NPE_Backstop", "Capital_Stack", "Parallel_Constraints", "RWA_Equivalents"), controls = "CAPITAL|OWN_FUNDS|NPE|LEVERAGE|MREL|TLAC"),
    irrbb = list(metrics = "EVE|NII|CSRBB|IRRBB", tables = c("IRRBB_Repricing_Gap", "IRRBB_NII_Bands", "IRRBB_Currency_Scenarios", "IRRBB_Scenarios", "IRRBB_Risk_Measures"), controls = "IRRBB|BEHAVIOUR"),
    icaap = list(metrics = "EC_|ECONOMIC|NORMATIVE", tables = c("EC_Standalone", "EC_Aggregation", "Normative_Projection", "Pillar2_Bridge"), controls = "ICAAP|EC_")
  )
  specs[[domain]]
}

analyze_domain <- function(x, domain, view) {
  result <- as_rwa_result(x); view <- normalize_view(view); spec <- domain_specification(domain)
  metrics <- rwa_metrics(result, view); metrics <- metrics[grepl(spec$metrics, metrics$metric), , drop = FALSE]
  all_tables <- rwa_result_tables(result, view); tables <- all_tables[intersect(spec$tables, names(all_tables))]
  controls <- rwa_controls(result, view)
  if (nrow(controls)) controls <- controls[grepl(spec$controls, controls$control_code), , drop = FALSE]
  structure(list(domain = domain, view = view, run_id = result$run_id,
                 metrics = metrics, tables = tables, controls = controls,
                 parameter_overrides = parameter_overrides(result)),
            class = "rwa_domain_analysis")
}

#' Print a Domain Analysis
#' @param x An `rwa_domain_analysis`.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.rwa_domain_analysis <- function(x, ...) {
  cat(sprintf("<rwa_domain_analysis> %s [%s]: %d metrics, %d tables, %d controls\n",
              x$domain, x$view, nrow(x$metrics), length(x$tables), nrow(x$controls)))
  invisible(x)
}

#' Analyse Credit Risk
#' @param x Canonical tables or an existing calculation result.
#' @param view `"applied"` or `"fully_loaded"`.
#' @return An `rwa_domain_analysis` with relevant metrics, tables and controls.
#' @seealso [calculate_tables()]
#' @examplesIf interactive()
#' analyze_credit_risk(generate_synthetic_tables(bank_profile = "KSA_BANK"))
#' @export
analyze_credit_risk <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "credit", view)

#' Analyse Counterparty Credit Risk, CVA and Settlement Risk
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_counterparty_risk <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "counterparty", view)

#' Analyse Securitisation Risk
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_securitisation <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "securitisation", view)

#' Analyse Market Risk and FRTB
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_market_risk <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "market", view)

#' Analyse Operational Risk
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_operational_risk <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "operational", view)

#' Analyse the Output Floor
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_output_floor <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "floor", view)

#' Analyse Capital Adequacy, Leverage and MREL/TLAC
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_capital_adequacy <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "capital", view)

#' Analyse IRRBB and CSRBB
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_irrbb <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "irrbb", view)

#' Analyse ICAAP Economic and Normative Perspectives
#' @inheritParams analyze_credit_risk
#' @return An `rwa_domain_analysis`.
#' @export
analyze_icaap <- function(x, view = c("applied", "fully_loaded")) analyze_domain(x, "icaap", view)
