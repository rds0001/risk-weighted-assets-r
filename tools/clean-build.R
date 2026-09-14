targets <- c(
  list.files(".", pattern = "^riskweightedassets_.*[.]tar[.]gz$", full.names = TRUE),
  list.files(".", pattern = "^riskweightedassets[.]Rcheck$", full.names = TRUE)
)
targets <- unique(normalizePath(targets, winslash = "/", mustWork = FALSE))
root <- normalizePath(".", winslash = "/")
safe <- startsWith(targets, paste0(root, "/"))
if (any(!safe)) stop("Refusing to remove a path outside the package root")
unlink(targets[safe], recursive = TRUE, force = TRUE)
cat("Removed", sum(safe), "local build artifact(s).\n")
