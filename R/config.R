# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

package_resource <- function(...) {
  parts <- c(...)
  installed <- system.file(..., package = "riskweightedassets")
  if (nzchar(installed)) return(installed)
  candidates <- c(
    do.call(file.path, as.list(c(getwd(), "inst", parts))),
    do.call(file.path, as.list(c(getwd(), "r-lib", "inst", parts)))
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing)) normalizePath(existing[[1L]], winslash = "/") else ""
}

load_yaml_file <- function(path) {
  if (!file.exists(path)) abort_configuration(sprintf("Configuration file is missing: %s", path))
  value <- yaml::read_yaml(path)
  if (!is.list(value) || is.null(names(value))) {
    abort_configuration(sprintf("Configuration root must be an object: %s", path))
  }
  value
}

load_profile <- function(profile_id, config_root = NULL) {
  path <- if (is.null(config_root)) {
    package_resource("extdata", "profiles", paste0(profile_id, ".yaml"))
  } else {
    file.path(config_root, paste0(profile_id, ".yaml"))
  }
  profile <- load_yaml_file(path)
  required <- c("profile_id", "profile_version", "base_as_of_date", "source_inputs", "regulatory_config")
  missing <- setdiff(required, names(profile))
  if (length(missing)) abort_configuration(sprintf("Profile %s is missing: %s", profile_id, paste(missing, collapse = ", ")))
  if (!identical(as.character(profile$profile_id), profile_id)) {
    abort_configuration(sprintf("Profile id in file does not match %s", profile_id))
  }
  profile
}

load_regulatory_config <- function(path = NULL) {
  if (is.null(path)) path <- package_resource("config", "crr3_eu_2026_v1.yaml")
  config <- load_yaml_file(path)
  if (!is.list(config$metadata) || !is.list(config$parameters)) {
    abort_configuration("Regulatory configuration requires metadata and parameters")
  }
  config
}

regulatory_parameter_items <- function(config) {
  items <- config$parameters
  for (table in config$parameter_tables %||% list()) {
    rows <- table$rows
    columns <- table$columns
    values <- table$values
    valid <- length(values) == length(rows) &&
      all(vapply(values, length, integer(1)) == length(columns))
    if (!valid) abort_configuration(sprintf("Invalid parameter matrix: %s", table$key %||% ""))
    for (i in seq_along(rows)) {
      for (j in seq_along(columns)) {
        items[[length(items) + 1L]] <- list(
          key = table$key, d1 = as.character(rows[[i]]),
          d2 = as.character(columns[[j]]), value = values[[i]][[j]],
          unit = table$unit, ref = table$ref
        )
      }
    }
  }
  items
}

default_parameter_store <- function() {
  items <- regulatory_parameter_items(load_regulatory_config())
  frame <- data.frame(
    parameter_key = vapply(items, function(x) as.character(x$key), character(1)),
    dimension_1 = vapply(items, function(x) as.character(x$d1 %||% ""), character(1)),
    dimension_2 = vapply(items, function(x) as.character(x$d2 %||% ""), character(1)),
    parameter_value = vapply(items, function(x) as.numeric(x$value), numeric(1)),
    stringsAsFactors = FALSE
  )
  new_parameter_store(frame)
}
