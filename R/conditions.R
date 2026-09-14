# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

new_rwa_condition <- function(message, subclass = "rwa_error", ..., call = NULL) {
  structure(
    c(list(message = as.character(message), call = call), list(...)),
    class = c(subclass, "rwa_error", "error", "condition")
  )
}

abort_rwa <- function(message, subclass = "rwa_error", ..., call = NULL) {
  stop(new_rwa_condition(message, subclass = subclass, ..., call = call))
}

abort_configuration <- function(message, ..., call = NULL) {
  abort_rwa(message, "rwa_configuration_error", ..., call = call)
}

abort_resource <- function(message, ..., call = NULL) {
  abort_rwa(message, "rwa_resource_error", ..., call = call)
}

abort_validation <- function(message, messages = NULL, ..., call = NULL) {
  abort_rwa(message, "rwa_validation_error", messages = messages, ..., call = call)
}

abort_calculation <- function(message, ..., call = NULL) {
  abort_rwa(message, "rwa_calculation_error", ..., call = call)
}

