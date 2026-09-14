# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

normalize_dimension <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) "" else trimws(as.character(value[[1L]]))
}

parameter_key <- function(key, dimension_1 = "", dimension_2 = "") {
  paste(as.character(key), normalize_dimension(dimension_1),
        normalize_dimension(dimension_2), sep = "\037")
}

new_parameter_store <- function(frame) {
  if (!is.data.frame(frame)) abort_configuration("regulatory_parameter must be a data.frame")
  required <- c("parameter_key", "dimension_1", "dimension_2", "parameter_value")
  missing <- setdiff(required, names(frame))
  if (length(missing)) {
    abort_rwa(sprintf("Columns missing from regulatory_parameter: %s",
                      paste(missing, collapse = ", ")),
              subclass = "rwa_parameter_error")
  }
  normalized <- frame
  normalized$parameter_key <- vapply(normalized$parameter_key, normalize_dimension, character(1))
  normalized$dimension_1 <- vapply(normalized$dimension_1, normalize_dimension, character(1))
  normalized$dimension_2 <- vapply(normalized$dimension_2, normalize_dimension, character(1))
  keys <- mapply(parameter_key, normalized$parameter_key,
                 normalized$dimension_1, normalized$dimension_2, USE.NAMES = FALSE)
  duplicates <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  if (any(duplicates)) {
    abort_rwa(sprintf("Ambiguous regulatory parameter: %s", keys[which(duplicates)[1L]]),
              subclass = "rwa_parameter_error")
  }
  values <- suppressWarnings(as.numeric(normalized$parameter_value))
  if (anyNA(values)) {
    i <- which(is.na(values))[1L]
    abort_rwa(sprintf("Regulatory parameter is not numeric: %s", keys[[i]]),
              subclass = "rwa_parameter_error")
  }
  names(values) <- keys
  structure(list(frame = normalized, values = values), class = "rwa_parameter_store")
}

parameter_has <- function(params, key, dimension_1 = "", dimension_2 = "") {
  parameter_key(key, dimension_1, dimension_2) %in% names(params$values)
}

parameter_get <- function(params, key, dimension_1 = "", dimension_2 = "") {
  lookup <- parameter_key(key, dimension_1, dimension_2)
  if (!lookup %in% names(params$values)) {
    abort_rwa(sprintf("Required regulatory parameter is missing: %s[%s,%s]",
                      key, normalize_dimension(dimension_1), normalize_dimension(dimension_2)),
              subclass = "rwa_parameter_error")
  }
  unname(params$values[[lookup]])
}

parameter_require <- function(params, keys) {
  missing <- vapply(keys, function(item) {
    !parameter_has(params, item[[1L]], item[[2L]] %||% "", item[[3L]] %||% "")
  }, logical(1))
  if (any(missing)) abort_rwa("Required regulatory parameters are missing", "rwa_parameter_error")
  invisible(params)
}
