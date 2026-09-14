# Build the language-neutral stochastic reference path used for parity tests.
# Python and NumPy are development dependencies only; users load a plain RDS.

generator <- file.path("data-raw", "export-numpy-pcg64-reference.py")
output <- system2("python3", generator, stdout = TRUE, stderr = TRUE)
status <- attr(output, "status")
if (!is.null(status) && status != 0L) stop(paste(output, collapse = "\n"))
payload <- jsonlite::fromJSON(paste(output, collapse = "\n"))
stopifnot(length(payload$values) == payload$paths)
saveRDS(payload, file.path("inst", "extdata", "canonical",
                           "irrbb_numpy_reference.rds"), compress = "xz")
