# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

load_reference_tables <- function() {
  path <- package_resource("extdata", "canonical", "reference_tables.rds")
  if (!file.exists(path)) abort_resource("Bundled canonical reference tables are missing")
  lapply(readRDS(path), normalize_canonical_table)
}

shift_temporal_columns <- function(tables, profile, target_as_of) {
  base <- as.Date(profile$base_as_of_date)
  delta <- as.numeric(as.Date(target_as_of) - base)
  immutable <- unlist(profile$shift_columns$immutable_date_columns %||% list(), use.names = FALSE)
  dates <- setdiff(unlist(profile$shift_columns$date %||% list(), use.names = FALSE), immutable)
  datetimes <- unlist(profile$shift_columns$datetime %||% list(), use.names = FALSE)
  for (name in names(tables)) {
    frame <- tables[[name]]
    for (field in intersect(dates, names(frame))) {
      value <- excel_date(frame[[field]])
      value[!is.na(value)] <- value[!is.na(value)] + delta
      frame[[field]] <- value
    }
    for (field in intersect(datetimes, names(frame))) {
      value <- excel_datetime(frame[[field]])
      value[!is.na(value)] <- value[!is.na(value)] + delta * 86400
      frame[[field]] <- value
    }
    tables[[name]] <- frame
  }
  tables
}

materialize_regulatory_parameters <- function(tables, target_as_of) {
  config <- load_regulatory_config()
  items <- regulatory_parameter_items(config)
  template <- tables$regulatory_parameter[1L, , drop = FALSE]
  rows <- lapply(seq_along(items), function(i) {
    item <- items[[i]]
    row <- template
    d1 <- as.character(item$d1 %||% ""); d2 <- as.character(item$d2 %||% "")
    row$record_id <- sprintf("PARAM-%04d-%s-%s-%s::v1", i, item$key, d1, d2)
    row$business_key <- sub("::v1$", "", row$record_id)
    row$version_no <- 1
    row$as_of_date <- as.Date(target_as_of)
    row$parameter_key <- as.character(item$key)
    row$dimension_1 <- d1; row$dimension_2 <- d2
    row$parameter_value <- as.numeric(item$value); row$unit <- as.character(item$unit)
    row$rule_set_id <- as.character(config$metadata$rule_set_id)
    row$legal_reference <- as.character(item$ref)
    row
  })
  tables$regulatory_parameter <- do.call(rbind, rows)
  rownames(tables$regulatory_parameter) <- NULL

  formula_template <- tables$formula_definition[1L, , drop = FALSE]
  formula_ids <- names(config$formula_registry)
  formulas <- lapply(seq_along(formula_ids), function(i) {
    formula_id <- formula_ids[[i]]
    row <- formula_template
    row$record_id <- sprintf("FORMULA-%s::v1", formula_id)
    row$business_key <- sub("::v1$", "", row$record_id)
    row$version_no <- 1
    row$as_of_date <- as.Date(target_as_of)
    row$formula_id <- formula_id
    row$formula_version <- as.character(config$metadata$version)
    row$component <- as.character(config$formula_registry[[formula_id]])
    row$expression_language <- "R_FLOAT"
    row$legal_reference <- "SCHRITT_1_FORMELKATALOG"
    row$description <- sprintf("Implementierte Formel %s", formula_id)
    row
  })
  tables$formula_definition <- do.call(rbind, formulas)
  rownames(tables$formula_definition) <- NULL
  tables
}

update_run_control <- function(tables, target_as_of, seed, profile_id) {
  updates <- c(as_of_date = format(as.Date(target_as_of)),
               knowledge_time = paste0(format(as.Date(target_as_of)), "T23:59:59"),
               random_seed = as.character(seed), institution_profile = profile_id)
  for (key in names(updates)) {
    mask <- as.character(tables$run_config$config_key) == key
    if (sum(mask) != 1L) abort_configuration(sprintf("run_config key is missing or ambiguous: %s", key))
    tables$run_config$config_value[mask] <- updates[[key]]
  }
  if ("random_seed" %in% names(tables$model_registry)) tables$model_registry$random_seed <- seed
  tables
}

apply_profile_transformations <- function(tables, profile) {
  transformations <- profile$transformations %||% list()
  for (name in unlist(transformations$empty_tables %||% list(), use.names = FALSE)) {
    if (is.null(tables[[name]])) abort_configuration(sprintf("Unknown transformed table: %s", name))
    tables[[name]] <- tables[[name]][0, , drop = FALSE]
  }
  for (name in names(transformations$set_columns %||% list())) {
    if (is.null(tables[[name]])) abort_configuration(sprintf("Unknown transformed table: %s", name))
    for (field in names(transformations$set_columns[[name]])) {
      if (!field %in% names(tables[[name]])) abort_configuration(sprintf("Unknown transformed field: %s.%s", name, field))
      tables[[name]][[field]] <- transformations$set_columns[[name]][[field]]
    }
  }
  tables
}

#' Generate Synthetic Canonical Tables
#'
#' Materializes a complete synthetic banking profile from immutable package
#' fixtures. The seed is recorded for lineage; no business distributions are
#' generated at runtime.
#'
#' @param as_of Reporting date. Defaults to the profile base date.
#' @param seed Integer lineage seed.
#' @param bank_profile Profile identifier.
#' @param config_root Optional directory containing profile YAML files.
#' @return A named list of canonical data frames.
#' @seealso [calculate_tables()], [generate_synthetic_dataset()]
#' @examples
#' tables <- generate_synthetic_tables(bank_profile = "KSA_BANK")
#' length(tables)
#' @export
generate_synthetic_tables <- function(as_of = NULL, seed = NULL,
                                      bank_profile = "MID_SIZE_UNIVERSAL",
                                      config_root = NULL) {
  profile <- load_profile(bank_profile, config_root)
  target_as_of <- as.Date(as_of %||% profile$base_as_of_date)
  effective_seed <- as.integer(seed %||% profile$default_seed)
  tables <- load_reference_tables()
  tables <- shift_temporal_columns(tables, profile, target_as_of)
  tables <- materialize_regulatory_parameters(tables, target_as_of)
  tables <- update_run_control(tables, target_as_of, effective_seed, bank_profile)
  tables <- apply_profile_transformations(tables, profile)
  report <- new_validation_report(validate_tables_internal(tables))
  if (!validation_valid(report)) {
    abort_configuration(sprintf("Reference profile violates the data contract with %d errors",
                                length(validation_errors(report))))
  }
  tables
}

#' Generate a Synthetic Workbook Dataset
#'
#' @param root Parent directory for dated datasets.
#' @param as_of Reporting date.
#' @param version Dataset version.
#' @param seed Integer lineage seed.
#' @param bank_profile Profile identifier.
#' @param config_root Optional profile configuration directory.
#' @param overwrite Whether an existing dataset may be replaced.
#' @return The generated dataset directory.
#' @details The function writes 16 canonical workbooks plus a dataset manifest.
#'   An existing non-empty target requires `overwrite = TRUE`.
#' @seealso [validate_dataset()], [calculate_dataset()]
#' @examplesIf interactive()
#' generate_synthetic_dataset(file.path(tempdir(), "rwa-runs"),
#'                            bank_profile = "KSA_BANK")
#' @export
generate_synthetic_dataset <- function(root, as_of = NULL, version = NULL,
                                       seed = NULL, bank_profile = "MID_SIZE_UNIVERSAL",
                                       config_root = NULL, overwrite = FALSE) {
  profile <- load_profile(bank_profile, config_root)
  target_as_of <- as.Date(as_of %||% profile$base_as_of_date)
  dataset_version <- as.character(version %||% profile$default_dataset_version)
  effective_seed <- as.integer(seed %||% profile$default_seed)
  dataset <- file.path(root, format(target_as_of), dataset_version)
  if (dir.exists(dataset) && length(list.files(dataset, all.files = TRUE, no.. = TRUE)) && !overwrite) {
    abort_configuration(sprintf("Dataset already exists: %s; use overwrite = TRUE explicitly", dataset))
  }
  input_dir <- file.path(dataset, "inputs")
  dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- generate_synthetic_tables(target_as_of, effective_seed, bank_profile, config_root)
  files <- write_input_workbooks(input_dir, tables)
  manifest <- list(
    dataset_version = dataset_version, as_of_date = format(target_as_of),
    bank_profile = bank_profile, profile_version = as.character(profile$profile_version),
    random_seed = effective_seed, generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    input_workbooks = basename(files),
    input_sha256 = setNames(vapply(files, digest::digest, character(1), file = TRUE, algo = "sha256"), basename(files)),
    table_row_counts = vapply(tables, nrow, integer(1))
  )
  jsonlite::write_json(manifest, file.path(dataset, "dataset_manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE)
  normalizePath(dataset, winslash = "/")
}
