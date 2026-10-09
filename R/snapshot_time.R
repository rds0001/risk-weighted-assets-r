# One UTC interpretation for public snapshots and calculation configuration.
parse_knowledge_time <- function(value) {
  invalid <- function() abort_configuration(
    "knowledge_time must be one valid UTC timestamp or POSIXt value")
  if (length(value) != 1L || anyNA(value)) invalid()
  if (inherits(value, "POSIXt")) {
    result <- as.POSIXct(value, tz = "UTC")
  } else if (inherits(value, "Date")) {
    result <- as.POSIXct(value, tz = "UTC")
  } else if (is.character(value)) {
    text <- trimws(value)
    if (grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", text)) {
      result <- as.POSIXct(text, format = "%Y-%m-%d", tz = "UTC")
    } else {
      pattern <- "^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?Z?$"
      if (!grepl(pattern, text)) invalid()
      text <- sub("Z$", "", sub("T", " ", text, fixed = TRUE))
      result <- as.POSIXct(text, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC")
    }
  } else invalid()
  if (is.na(result) || !is.finite(as.numeric(result))) invalid()
  attr(result, "tzone") <- "UTC"
  result
}
