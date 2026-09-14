# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

contracts_by_workbook <- function() {
  split(table_contracts(), vapply(table_contracts(), function(x) x$workbook, character(1)))
}

read_input_workbooks <- function(directory) {
  contracts <- table_contracts()
  tables <- list(); issues <- list()
  add <- function(issue) issues[[length(issues) + 1L]] <<- issue
  for (logical_name in names(contracts)) {
    spec <- contracts[[logical_name]]
    path <- file.path(directory, spec$workbook)
    if (!file.exists(path)) {
      add(validation_issue("ERROR", "MISSING_WORKBOOK", logical_name,
                           message = normalizePath(path, winslash = "/", mustWork = FALSE)))
      next
    }
    available <- tryCatch(openxlsx::getSheetNames(path), error = function(e) character())
    if (!spec$sheet %in% available) {
      add(validation_issue("ERROR", "MISSING_SHEET", logical_name,
                           message = paste("Missing sheet", spec$sheet)))
      next
    }
    frame <- tryCatch(
      as.data.frame(readxl::read_excel(path, sheet = spec$sheet, na = ""),
                    stringsAsFactors = FALSE, check.names = FALSE),
      error = function(e) e
    )
    if (inherits(frame, "error")) {
      add(validation_issue("ERROR", "UNREADABLE_SHEET", logical_name,
                           message = conditionMessage(frame)))
      next
    }
    missing <- setdiff(spec$columns, names(frame))
    if (length(missing)) {
      add(validation_issue("ERROR", "MISSING_COLUMNS", logical_name,
                           field = paste(missing, collapse = ","),
                           message = "Required columns are missing"))
      next
    }
    frame <- frame[, spec$columns, drop = FALSE]
    if (nrow(frame)) frame <- frame[rowSums(!is.na(frame)) > 0L, , drop = FALSE]
    tables[[logical_name]] <- normalize_canonical_table(frame)
  }
  list(tables = tables, issues = issues)
}

write_canonical_table <- function(workbook, sheet, frame, table_name, header_style) {
  openxlsx::addWorksheet(workbook, sheet)
  if (ncol(frame) == 0L) frame <- data.frame(value = character())
  openxlsx::writeDataTable(workbook, sheet, frame, tableName = table_name,
                           tableStyle = "TableStyleMedium2", withFilter = TRUE)
  openxlsx::addStyle(workbook, sheet, header_style, rows = 1,
                     cols = seq_len(ncol(frame)), gridExpand = TRUE, stack = TRUE)
  openxlsx::freezePane(workbook, sheet, firstRow = TRUE)
  widths <- vapply(names(frame), function(name) min(max(12, nchar(name) + 2), 42), numeric(1))
  openxlsx::setColWidths(workbook, sheet, cols = seq_len(ncol(frame)), widths = widths)
}

write_input_workbooks <- function(directory, tables) {
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  groups <- contracts_by_workbook()
  written <- character()
  header <- openxlsx::createStyle(fgFill = "#1F4E78", fontColour = "#FFFFFF",
                                  textDecoration = "bold", halign = "center")
  for (workbook_name in sort(names(groups))) {
    workbook <- openxlsx::createWorkbook(creator = "RiskDataScience GmbH")
    readme <- data.frame(
      property = c("workbook", "purpose", "editing_rule", "versioning", "official_default"),
      value = c(workbook_name, "Canonical institution-neutral RWA input data",
                "Change data cells only; preserve columns and table names",
                "Append corrected versions instead of overwriting records",
                "New active actual records default to TRUE"), stringsAsFactors = FALSE)
    write_canonical_table(workbook, "README", readme, "tbl_doc_readme", header)
    dictionary <- do.call(rbind, lapply(names(groups[[workbook_name]]), function(logical_name) {
      spec <- groups[[workbook_name]][[logical_name]]
      data.frame(logical_table = logical_name, sheet = spec$sheet,
                 excel_table = spec$table_name, field = spec$columns,
                 required = TRUE, description = gsub("_", " ", spec$columns),
                 stringsAsFactors = FALSE)
    }))
    write_canonical_table(workbook, "DATA_DICTIONARY", dictionary, "tbl_doc_dictionary", header)
    lookups <- data.frame(domain = c(rep("record_status", 4), rep("boolean", 2)),
                          value = c("ACTIVE", "PROVISIONAL", "SIMULATED", "CANCELLED", "TRUE", "FALSE"))
    write_canonical_table(workbook, "_LOOKUPS", lookups, "tbl_doc_lookups", header)
    openxlsx::sheetVisibility(workbook)[which(openxlsx::sheets(workbook) == "_LOOKUPS")] <- "hidden"
    changelog <- data.frame(template_version = "1.0.0", change_date = as.Date("2026-09-14"),
                            change = "Initial canonical R data contract")
    write_canonical_table(workbook, "CHANGELOG", changelog, "tbl_doc_changelog", header)
    for (logical_name in names(groups[[workbook_name]])) {
      spec <- groups[[workbook_name]][[logical_name]]
      frame <- tables[[logical_name]]
      if (is.null(frame)) frame <- as.data.frame(setNames(replicate(length(spec$columns), character(), simplify = FALSE), spec$columns))
      for (field in setdiff(spec$columns, names(frame))) frame[[field]] <- NA
      frame <- frame[, spec$columns, drop = FALSE]
      write_canonical_table(workbook, spec$sheet, frame, spec$table_name, header)
    }
    path <- file.path(directory, workbook_name)
    openxlsx::saveWorkbook(workbook, path, overwrite = TRUE)
    written <- c(written, normalizePath(path, winslash = "/"))
  }
  written
}

write_result_workbook <- function(path, sheets, metadata) {
  workbook <- openxlsx::createWorkbook(creator = "RiskDataScience GmbH")
  header <- openxlsx::createStyle(fgFill = "#1F4E78", fontColour = "#FFFFFF",
                                  textDecoration = "bold", halign = "center")
  info <- data.frame(key = names(metadata), value = vapply(metadata, as.character, character(1)),
                     stringsAsFactors = FALSE)
  write_canonical_table(workbook, "Run_Info", info, "tbl_out_run_info", header)
  for (name in names(sheets)) {
    safe <- substr(name, 1L, 31L)
    table_name <- paste0("tbl_out_", gsub("[^A-Za-z0-9_]", "_", safe))
    if (!grepl("^[A-Za-z]", table_name)) table_name <- paste0("t_", table_name)
    write_canonical_table(workbook, safe, as.data.frame(sheets[[name]], stringsAsFactors = FALSE),
                          substr(table_name, 1L, 250L), header)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  openxlsx::saveWorkbook(workbook, path, overwrite = TRUE)
  normalizePath(path, winslash = "/")
}
