# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

#' Validate a Canonical Dataset
#'
#' Reads and validates all canonical input workbooks without calculating or
#' writing any output files.
#'
#' @param dataset Dataset directory containing an `inputs` subdirectory.
#' @return An `rwa_validation_report` object.
#' @seealso [calculate_dataset()], [generate_synthetic_dataset()]
#' @examplesIf interactive()
#' root <- file.path(tempdir(), "rwa-validation-example")
#' dataset <- generate_synthetic_dataset(root, bank_profile = "KSA_BANK")
#' as.data.frame(validate_dataset(dataset))
#' @export
validate_dataset <- function(dataset) {
  path <- normalizePath(dataset, winslash = "/", mustWork = FALSE)
  loaded <- read_input_workbooks(file.path(path, "inputs"))
  new_validation_report(c(loaded$issues, validate_tables_internal(loaded$tables)))
}

validate_tables_public <- function(tables) {
  if (!is.list(tables) || is.null(names(tables))) abort_validation("tables must be a named list of data.frames")
  invalid <- names(tables)[!vapply(tables, is.data.frame, logical(1))]
  if (length(invalid)) abort_validation(sprintf("Non-data.frame tables: %s", paste(invalid, collapse = ", ")))
  new_validation_report(validate_tables_internal(tables))
}

#' Calculate Canonical In-Memory Tables
#'
#' Validates and calculates canonical tables without producing spreadsheet
#' output. A parallel fully-loaded result is calculated from the same snapshot.
#'
#' @param tables Named list of canonical data frames.
#' @param run_id Optional caller-defined run identifier.
#' @param project_root Optional root used to resolve local source documents.
#' @param parameter_overrides Optional data frame of controlled parameter
#'   overrides prepared as described in [override_regulatory_parameters()].
#' @param override_reason,override_approved_by Required non-empty governance
#'   information when `parameter_overrides` is supplied.
#' @return An `rwa_calculation_result` object.
#' @details The return includes applied and fully-loaded result tables. All
#'   calculations use one official bitemporal snapshot. The function does not
#'   write files and does not change the global random-number stream.
#' @seealso [generate_synthetic_tables()], [calculate_dataset()]
#' @examplesIf interactive()
#' tables <- generate_synthetic_tables(bank_profile = "KSA_BANK")
#' result <- calculate_tables(tables)
#' result$metrics[c("RWEA_KSA", "TREA")]
#' @export
calculate_tables <- function(tables, run_id = NULL, project_root = NULL,
                             parameter_overrides = NULL, override_reason = NULL,
                             override_approved_by = NULL) {
  if (!is.null(parameter_overrides)) {
    tables <- override_regulatory_parameters(
      tables, parameter_overrides,
      reason = override_reason %||% attr(parameter_overrides, "reason") %||% "",
      approved_by = override_approved_by %||% attr(parameter_overrides, "approved_by") %||% ""
    )
  }
  report <- validate_tables_public(tables)
  if (!validation_valid(report)) abort_validation(
    sprintf("Input validation failed with %d error(s)", length(validation_errors(report))),
    messages = validation_errors(report))
  fingerprint <- digest::digest(paste(tables_fingerprint(tables), code_fingerprint(), engine_version(), sep = ":"),
                                algo = "sha256", serialize = FALSE)
  config <- run_configuration(tables); as_of <- as.Date(config[["as_of_date"]])
  effective_run_id <- run_id %||% paste0("RUN-", format(as_of, "%Y%m%d"), "-", toupper(substr(fingerprint, 1, 10)))
  execution <- tryCatch(execute_tables(tables, effective_run_id, project_root),
                        error = function(e) {
                          if (inherits(e, "rwa_error")) stop(e)
                          abort_calculation(sprintf("In-memory calculation failed: %s", conditionMessage(e)))
                        })
  new_calculation_result(
    "CALCULATED", effective_run_id, engine_version(), execution$context$rule_set_id,
    metrics = execution$applied$metrics, controls = execution$applied$controls,
    validation = execution$report, results = execution$applied$results,
    parallel_results = execution$parallel$results,
    parallel_metrics = execution$parallel$metrics,
    parallel_controls = execution$parallel$controls,
    parameter_overrides = attr(tables, "rwa_parameter_overrides") %||% data.frame())
}

input_directory_fingerprint <- function(input_dir) {
  files <- sort(list.files(input_dir, pattern = "[.]xlsx$", full.names = TRUE))
  digests <- setNames(vapply(files, digest::digest, character(1), file = TRUE, algo = "sha256"), basename(files))
  digest::digest(digests, algo = "sha256")
}

#' Calculate a Canonical Workbook Dataset
#'
#' Validates a dataset, creates an immutable deterministic run directory and
#' writes six structured output workbooks plus a JSON run manifest.
#'
#' @param dataset Dataset directory containing an `inputs` subdirectory.
#' @return An `rwa_calculation_result` object with output paths.
#' @details Output is written below `dataset/outputs/<run-id>`. The run ID
#'   fingerprints the input files, code and package version.
#' @seealso [validate_dataset()], [generate_synthetic_dataset()]
#' @examplesIf interactive()
#' root <- file.path(tempdir(), "rwa-calculation-example")
#' dataset <- generate_synthetic_dataset(root, bank_profile = "KSA_BANK")
#' calculate_dataset(dataset)
#' @export
calculate_dataset <- function(dataset) {
  dataset_path <- normalizePath(dataset, winslash = "/", mustWork = FALSE)
  input_dir <- file.path(dataset_path, "inputs")
  loaded <- read_input_workbooks(input_dir)
  if (is.null(loaded$tables$run_config) || !nrow(loaded$tables$run_config)) {
    abort_calculation("Run configuration is missing")
  }
  cfg <- run_configuration(loaded$tables); as_of <- as.Date(cfg[["as_of_date"]])
  input_hash <- input_directory_fingerprint(input_dir); code_hash <- code_fingerprint()
  fingerprint <- digest::digest(paste(input_hash, code_hash, engine_version(), sep = ":"),
                                algo = "sha256", serialize = FALSE)
  run_id <- paste0("RUN-", format(as_of, "%Y%m%d"), "-", toupper(substr(fingerprint, 1, 10)))
  output_dir <- file.path(dataset_path, "outputs", run_id)
  execution <- tryCatch(execute_tables(loaded$tables, run_id, dirname(dirname(dataset_path)), loaded$issues),
                        error = function(e) {
                          if (inherits(e, "rwa_error")) stop(e)
                          abort_calculation(sprintf("Dataset calculation failed: %s", conditionMessage(e)))
                        })
  metadata <- list(
    run_id = run_id, as_of_date = format(as_of),
    knowledge_time = format(execution$context$knowledge_time, tz = "UTC", usetz = TRUE),
    status = "CALCULATED", input_hash = input_hash, code_hash = code_hash,
    calculation_fingerprint = fingerprint, engine_version = engine_version(),
    r_version = R.version.string, created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    rule_set_id = execution$context$rule_set_id, parallel_rule_set_id = "CRR3-EU-FL",
    reporting_currency = execution$context$reporting_currency)
  files <- write_outputs(output_dir, execution, metadata)
  manifest <- c(metadata, list(
    output_files = basename(files), control_count = length(execution$applied$controls),
    controls_passed = sum(vapply(execution$applied$controls, function(x) isTRUE(x$passed), logical(1))),
    metrics = execution$applied$metrics))
  jsonlite::write_json(manifest, file.path(output_dir, "run_manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = 16, na = "null")
  new_calculation_result(
    "CALCULATED", run_id, engine_version(), execution$context$rule_set_id,
    metrics = execution$applied$metrics, controls = execution$applied$controls,
    validation = execution$report, output_dir = normalizePath(output_dir, winslash = "/"),
    output_files = files, results = execution$applied$results,
    parallel_results = execution$parallel$results,
    parallel_metrics = execution$parallel$metrics,
    parallel_controls = execution$parallel$controls,
    parameter_overrides = attr(loaded$tables, "rwa_parameter_overrides") %||% data.frame())
}
