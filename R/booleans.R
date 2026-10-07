# Canonical, fail-closed regulator input contract. Not a permissive truthiness test.
normalize_exposure_defaults <- function(tables) {
  values <- tables$exposure_lot$default_flag
  if (is.null(values)) stop("default_flag must be an explicit boolean", call. = FALSE)
  if (!is.logical(values) || anyNA(values)) {
    tables$exposure_lot$default_flag <- vapply(values, regulatory_bool, logical(1),
                                               field_name = "default_flag")
  }
  tables
}

regulatory_bool <- function(value, field_name) {
  invalid <- function() stop(field_name, " must be an explicit boolean", call. = FALSE)
  if (length(value) != 1L || !is.atomic(value) || is.na(value)) invalid()
  if (is.logical(value)) return(value)
  if (is.numeric(value) && !is.complex(value) && value %in% c(0, 1)) return(value == 1)
  if (is.character(value) || is.factor(value)) {
    text <- toupper(trimws(as.character(value)))
    if (text %in% c("TRUE", "1", "1.0", "YES", "JA")) return(TRUE)
    if (text %in% c("FALSE", "0", "0.0", "NO", "NEIN")) return(FALSE)
  }
  invalid()
}
