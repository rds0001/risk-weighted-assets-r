root <- normalizePath(".", winslash = "/")
required <- c(
  "DESCRIPTION", "NAMESPACE", "LICENSE", "README.md", "NEWS.md",
  "inst/LEGAL.md", "inst/CITATION",
  "docs/RISKWEIGHTEDASSETS_COMPLETE_DOCUMENTATION.md",
  "docs/RISKWEIGHTEDASSETS_COMPLETE_DOCUMENTATION.pdf"
)
missing <- required[!file.exists(file.path(root, required))]
if (length(missing)) stop("Missing required files: ", paste(missing, collapse = ", "))

all_files <- list.files(root, recursive = TRUE, all.files = TRUE,
                        full.names = FALSE, no.. = TRUE)
all_files <- all_files[!grepl("(^|/)([.]git|riskweightedassets[.]Rcheck)(/|$)", all_files)]
forbidden <- all_files[grepl(
  "(^|/)(scaffold|[.]venv|__pycache__|dist|build)(/|$)|[.](docx?|odt)$",
  all_files, ignore.case = TRUE
)]
if (length(forbidden)) stop("Forbidden source-tree content: ", paste(forbidden, collapse = ", "))
pdfs <- all_files[grepl("[.]pdf$", all_files, ignore.case = TRUE)]
allowed_pdfs <- c(
  "docs/RISKWEIGHTEDASSETS_COMPLETE_DOCUMENTATION.pdf",
  "docs/riskweightedassets-reference.pdf"
)
unexpected_pdfs <- setdiff(pdfs, allowed_pdfs)
if (length(unexpected_pdfs)) {
  stop("Unexpected PDF or downloaded document: ",
       paste(unexpected_pdfs, collapse = ", "))
}

description <- read.dcf(file.path(root, "DESCRIPTION"))
if (description[1L, "License"] != "GPL-3") stop("DESCRIPTION must declare GPL-3")

tables <- readRDS(file.path(root, "inst", "extdata", "canonical", "reference_tables.rds"))
contracts <- readRDS(file.path(root, "inst", "extdata", "canonical", "table_contracts.rds"))
if (length(tables) != 68L || !setequal(names(tables), names(contracts))) {
  stop("Canonical resource and contract inventories differ")
}
if (all(tables$sa_classification$short_term_flag)) {
  stop("Boolean fixture corruption detected")
}
cat("Source tree verified:", length(all_files), "files and", length(tables),
    "canonical tables.\n")
