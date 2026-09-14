# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

rwa_num <- function(value, default = 0) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) as.numeric(default) else as.numeric(value[[1L]])
}

rwa_bool <- function(value) {
  if (is.logical(value) && length(value)) return(isTRUE(value[[1L]]))
  toupper(trimws(as.character(value[[1L]] %||% ""))) %in% c("TRUE", "1", "YES", "JA")
}

rwa_text <- function(value) {
  if (is.null(value) || !length(value) || is.na(value[[1L]])) "" else trimws(as.character(value[[1L]]))
}

empty_frame <- function(columns) {
  as.data.frame(setNames(replicate(length(columns), logical(), simplify = FALSE), columns),
                stringsAsFactors = FALSE)
}

rows_frame <- function(rows, columns = NULL) {
  if (!length(rows)) return(empty_frame(columns %||% character()))
  all_names <- columns %||% unique(unlist(lapply(rows, names), use.names = FALSE))
  normalized <- lapply(rows, function(row) {
    missing <- setdiff(all_names, names(row))
    for (name in missing) row[[name]] <- NA
    as.data.frame(row[all_names], stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, normalized)
  rownames(out) <- NULL
  out
}

row_value <- function(row, name, default = NULL) {
  if (!name %in% names(row)) default else row[[name]][[1L]]
}

drop_overlap <- function(frame, target, key) {
  frame[, setdiff(names(frame), setdiff(intersect(names(frame), names(target)), key)), drop = FALSE]
}

new_calculation_context <- function(as_of_date, knowledge_time, rule_set_id,
                                    parameters, reporting_currency, market_regime,
                                    output_floor_factor, run_id = "",
                                    formula_version = "1.0.0") {
  structure(list(
    as_of_date = as.Date(as_of_date), knowledge_time = as.POSIXct(knowledge_time, tz = "UTC"),
    rule_set_id = rule_set_id, parameters = parameters,
    reporting_currency = reporting_currency, market_regime = market_regime,
    output_floor_factor = as.numeric(output_floor_factor), run_id = run_id,
    formula_version = formula_version
  ), class = "rwa_calculation_context")
}

new_calculation_bundle <- function() {
  out <- new.env(parent = emptyenv())
  out$results <- list(); out$metrics <- list(); out$controls <- list()
  class(out) <- "rwa_calculation_bundle"
  out
}

add_control <- function(out, code, passed, expected, actual, message) {
  numeric_difference <- is.numeric(actual) && length(actual) == 1L &&
    is.numeric(expected) && length(expected) == 1L
  out$controls[[length(out$controls) + 1L]] <- list(
    control_code = code, passed = isTRUE(passed), expected = expected, actual = actual,
    difference = if (numeric_difference) rwa_num(actual) - rwa_num(expected) else NA_real_,
    message = message
  )
  invisible(out)
}

sum_column <- function(frame, column) {
  if (is.null(frame) || !nrow(frame) || !column %in% names(frame)) 0 else
    sum(suppressWarnings(as.numeric(frame[[column]])), na.rm = TRUE)
}

