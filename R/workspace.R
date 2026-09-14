# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

#' Default Writable Workspace
#'
#' Uses `RWA_WORKSPACE` when it is set, otherwise a `rwa-workspace` directory
#' below the current working directory. The function only describes the path;
#' it does not create or modify it.
#'
#' @return An `rwa_workspace` object.
#' @export
#' @examples
#' default_workspace()
default_workspace <- function() {
  configured <- Sys.getenv("RWA_WORKSPACE", unset = "")
  root <- if (nzchar(configured)) configured else file.path(getwd(), "rwa-workspace")
  new_workspace(root)
}

copy_tree <- function(source, destination, overwrite = FALSE) {
  if (!dir.exists(source)) abort_resource(sprintf("Bundled resource directory is missing: %s", source))
  files <- list.files(source, recursive = TRUE, full.names = TRUE, all.files = TRUE,
                      no.. = TRUE)
  dirs <- files[dir.exists(files)]
  regular <- files[file.exists(files) & !dir.exists(files)]
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  for (path in dirs) {
    rel <- substring(path, nchar(source) + 2L)
    dir.create(file.path(destination, rel), recursive = TRUE, showWarnings = FALSE)
  }
  for (path in regular) {
    rel <- substring(path, nchar(source) + 2L)
    target <- file.path(destination, rel)
    dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
    if (file.exists(target) && !overwrite) abort_resource(sprintf("Resource already exists: %s", target))
    if (!file.copy(path, target, overwrite = overwrite, copy.mode = FALSE)) {
      abort_resource(sprintf("Could not copy resource to %s", target))
    }
  }
  invisible(destination)
}

#' Create a Writable RWA Workspace
#'
#' Exports the package's synthetic reference environment to a caller-controlled
#' directory. Existing non-empty directories require explicit `overwrite`.
#'
#' @param path Destination directory.
#' @param overwrite Whether existing files may be replaced.
#' @return An `rwa_workspace` object.
#' @export
#' @examplesIf interactive()
#' workspace <- create_workspace(file.path(tempdir(), "rwa-example"), overwrite = TRUE)
#' print(workspace)
create_workspace <- function(path, overwrite = FALSE) {
  root <- normalizePath(path, winslash = "/", mustWork = FALSE)
  if (dir.exists(root)) {
    existing <- setdiff(list.files(root, all.files = TRUE, no.. = TRUE), "workspace_manifest.json")
    if (length(existing) && !isTRUE(overwrite)) abort_resource(sprintf("Workspace is not empty: %s", root))
  }
  dir.create(root, recursive = TRUE, showWarnings = FALSE)
  copy_tree(package_resource("config"), file.path(root, "daten", "konfiguration", "regulatory"), overwrite = overwrite)
  copy_tree(package_resource("extdata", "profiles"),
            file.path(root, "daten", "konfiguration", "profiles"), overwrite = overwrite)
  copy_tree(package_resource("sources"), file.path(root, "Standards", "00_manifest"), overwrite = overwrite)
  profiles <- list_reference_profiles()
  for (i in seq_len(nrow(profiles))) {
    generate_synthetic_dataset(
      file.path(root, "daten", "rechenlaeufe"),
      bank_profile = profiles$profile_id[[i]],
      version = profiles$default_dataset_version[[i]],
      overwrite = overwrite
    )
  }
  manifest <- list(
    schema_version = "1.0", engine_version = as.character(utils::packageVersion("riskweightedassets")),
    created_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    contains = c("configuration", "synthetic_reference_profiles",
                 "reference_datasets", "source_metadata")
  )
  jsonlite::write_json(manifest, file.path(root, "workspace_manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE)
  new_workspace(root)
}
