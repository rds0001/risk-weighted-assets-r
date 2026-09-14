# Build compressed R-native fixtures from the canonical Python 1.0.0 workbook
# profile. This development script is excluded from the CRAN source package.

source_root <- Sys.getenv(
  "RWA_PYTHON_RESOURCE_ROOT",
  unset = file.path("..", "python-lib", "src", "rwa_engine", "resources")
)
input_root <- file.path(source_root, "daten", "referenzprofile",
                        "MID_SIZE_UNIVERSAL", "inputs")
output_root <- file.path("inst", "extdata", "canonical")

if (!dir.exists(input_root)) {
  stop("Set RWA_PYTHON_RESOURCE_ROOT to the Python 1.0.0 resource directory")
}
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

workbooks <- sort(list.files(input_root, pattern = "^RWA_IN_.*[.]xlsx$", full.names = TRUE))
tables <- list()
contracts <- list()

for (workbook_path in workbooks) {
  workbook <- openxlsx::loadWorkbook(workbook_path)
  for (sheet in openxlsx::sheets(workbook)) {
    excel_tables <- tryCatch(openxlsx::getTables(workbook, sheet), error = function(e) character())
    table_names <- unname(as.character(excel_tables))
    input_names <- table_names[startsWith(table_names, "tbl_in_")]
    if (!length(input_names)) next
    if (length(input_names) != 1L) stop("Expected one canonical table per input sheet")
    canonical_name <- sub("^tbl_in_", "", input_names[[1L]])
    # openxlsx <= 4.2.5.2 converts the OOXML boolean value "0" with
    # as.logical("0"), which is TRUE.  readxl preserves the actual FALSE/TRUE
    # values and therefore is deliberately used for the one-time fixture build.
    # The resulting package resources are plain RDS files and do not introduce
    # a runtime dependency on readxl.
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Building reference fixtures requires the development package 'readxl'")
    }
    frame <- as.data.frame(
      readxl::read_excel(workbook_path, sheet = sheet, na = ""),
      stringsAsFactors = FALSE,
      check.names = FALSE
    )
    tables[[canonical_name]] <- frame
    contracts[[canonical_name]] <- list(
      workbook = basename(workbook_path), sheet = sheet,
      table_name = input_names[[1L]], columns = names(frame), required = TRUE
    )
  }
}

if (length(workbooks) != 16L || length(tables) < 60L) {
  stop(sprintf("Unexpected canonical inventory: %d workbooks, %d tables",
               length(workbooks), length(tables)))
}

saveRDS(tables, file.path(output_root, "reference_tables.rds"), compress = "xz")
saveRDS(contracts, file.path(output_root, "table_contracts.rds"), compress = "xz")

provenance <- list(
  schema_version = "1.0",
  source_package = "risk-weighted-assets 1.0.0",
  profile = "MID_SIZE_UNIVERSAL",
  workbook_count = length(workbooks),
  table_count = length(tables),
  row_counts = vapply(tables, nrow, integer(1)),
  generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
jsonlite::write_json(provenance, file.path(output_root, "provenance.json"),
                     auto_unbox = TRUE, pretty = TRUE)
