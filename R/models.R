# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

new_validation_message <- function(severity, code, table = "", row_ref = "",
                                   field = "", message = "") {
  structure(
    list(
      severity = as.character(severity), code = as.character(code),
      table = as.character(table), row_ref = as.character(row_ref),
      field = as.character(field), message = as.character(message)
    ),
    class = "rwa_validation_message"
  )
}

new_validation_report <- function(messages = list()) {
  if (is.data.frame(messages)) {
    messages <- lapply(seq_len(nrow(messages)), function(i) {
      do.call(new_validation_message, as.list(messages[i, , drop = FALSE]))
    })
  }
  structure(list(messages = unname(messages)), class = "rwa_validation_report")
}

validation_errors <- function(x) {
  Filter(function(item) identical(item$severity, "ERROR"), x$messages)
}

validation_warnings <- function(x) {
  Filter(function(item) identical(item$severity, "WARNING"), x$messages)
}

validation_valid <- function(x) length(validation_errors(x)) == 0L

#' Print a Validation Report
#'
#' @param x An `rwa_validation_report`.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.rwa_validation_report <- function(x, ...) {
  errors <- length(validation_errors(x))
  warnings <- length(validation_warnings(x))
  cat(sprintf("<rwa_validation_report> %d message(s): %d error(s), %d warning(s)\n",
              length(x$messages), errors, warnings))
  invisible(x)
}

#' Convert a Validation Report to a Data Frame
#'
#' @param x An `rwa_validation_report`.
#' @param row.names Unused compatibility argument.
#' @param optional Unused compatibility argument.
#' @param ... Unused.
#' @return A data frame with one row per structured validation message.
#' @export
as.data.frame.rwa_validation_report <- function(x, row.names = NULL, optional = FALSE, ...) {
  columns <- c("severity", "code", "table", "row_ref", "field", "message")
  if (!length(x$messages)) {
    out <- as.data.frame(setNames(replicate(length(columns), character(), simplify = FALSE), columns),
                         stringsAsFactors = FALSE)
  } else {
    out <- do.call(rbind, lapply(x$messages, function(item) {
      as.data.frame(setNames(lapply(columns, function(name) item[[name]] %||% ""), columns),
                    stringsAsFactors = FALSE)
    }))
    rownames(out) <- NULL
  }
  out
}

new_calculation_result <- function(status, run_id, engine_version, rule_set_id,
                                   metrics = list(), controls = list(),
                                   validation = new_validation_report(),
                                   output_dir = NULL, output_files = character(),
                                   results = list(), parallel_results = list(),
                                   parallel_metrics = list(), parallel_controls = list(),
                                   parameter_overrides = data.frame()) {
  structure(
    list(
      status = as.character(status), run_id = as.character(run_id),
      engine_version = as.character(engine_version),
      rule_set_id = as.character(rule_set_id), metrics = metrics,
      controls = controls, validation = validation, output_dir = output_dir,
      output_files = output_files, results = results,
      parallel_results = parallel_results,
      parallel_metrics = parallel_metrics,
      parallel_controls = parallel_controls,
      parameter_overrides = parameter_overrides
    ),
    class = "rwa_calculation_result"
  )
}

controls_passed <- function(x) {
  sum(vapply(x$controls, function(control) isTRUE(control$passed), logical(1)))
}

control_count <- function(x) length(x$controls)

calculation_successful <- function(x) {
  identical(x$status, "CALCULATED") && validation_valid(x$validation) &&
    controls_passed(x) == control_count(x)
}

#' Print a Calculation Result
#'
#' @param x An `rwa_calculation_result`.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.rwa_calculation_result <- function(x, ...) {
  cat(sprintf("<rwa_calculation_result> %s [%s]\n", x$run_id, x$status))
  cat(sprintf("Rule set: %s; controls: %d/%d; valid: %s\n",
              x$rule_set_id, controls_passed(x), control_count(x),
              if (validation_valid(x$validation)) "yes" else "no"))
  invisible(x)
}

new_workspace <- function(root) {
  root <- normalizePath(root, winslash = "/", mustWork = FALSE)
  structure(
    list(
      root = root,
      data_root = file.path(root, "daten"),
      runs_root = file.path(root, "daten", "rechenlaeufe"),
      configuration_root = file.path(root, "daten", "konfiguration"),
      standards_root = file.path(root, "Standards")
    ),
    class = "rwa_workspace"
  )
}

#' Print a Workspace
#'
#' @param x An `rwa_workspace`.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.rwa_workspace <- function(x, ...) {
  cat(sprintf("<rwa_workspace> %s\n", x$root))
  invisible(x)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) return(y)
  first <- x[[1L]]
  if (is.atomic(first) && length(first) == 1L && is.na(first)) y else x
}
