# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

#' List Bundled Reference Profiles
#'
#' Returns metadata for every synthetic reference profile included with the
#' package. No customer or production data is included.
#'
#' @return A data frame with profile identifiers, versions, base dates, seeds,
#'   default dataset versions and descriptions.
#' @export
#' @examples
#' list_reference_profiles()
list_reference_profiles <- function() {
  root <- package_resource("extdata", "profiles")
  files <- sort(list.files(root, pattern = "[.]ya?ml$", full.names = TRUE))
  if (!length(files)) abort_resource("No bundled reference profiles were found")
  rows <- lapply(files, function(path) {
    payload <- load_yaml_file(path)
    data.frame(
      profile_id = as.character(payload$profile_id),
      profile_version = as.character(payload$profile_version),
      base_as_of_date = as.Date(payload$base_as_of_date),
      default_seed = as.integer(payload$default_seed),
      description = as.character(payload$description %||% ""),
      default_dataset_version = as.character(payload$default_dataset_version %||% ""),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

#' List Bundled Reference Datasets
#'
#' @return A data frame with dataset identifiers and versions.
#' @export
#' @examples
#' list_reference_datasets()
list_reference_datasets <- function() {
  root <- package_resource("extdata", "datasets")
  files <- sort(list.files(root, pattern = "^dataset_manifest[.]json$",
                           recursive = TRUE, full.names = TRUE))
  rows <- lapply(files, function(path) {
    payload <- jsonlite::read_json(path, simplifyVector = TRUE)
    rel <- substring(dirname(path), nchar(root) + 2L)
    data.frame(
      id = gsub("\\\\", "/", rel), profile = as.character(payload$bank_profile %||% ""),
      as_of_date = as.character(payload$as_of_date %||% ""),
      version = as.character(payload$dataset_version %||% ""),
      stringsAsFactors = FALSE
    )
  })
  if (!length(rows)) return(data.frame(id = character(), profile = character(),
                                       as_of_date = character(), version = character()))
  do.call(rbind, rows)
}

#' Regulatory Source Metadata
#'
#' Returns links and archived checksums for official sources used to design the
#' engine. The source documents themselves are deliberately not redistributed.
#'
#' @return A data frame. The `redistributed` column is always false for the
#'   bundled metadata.
#' @export
#' @examples
#' regulatory_sources()
regulatory_sources <- function() {
  path <- package_resource("sources", "sources.json")
  payload <- jsonlite::read_json(path, simplifyVector = TRUE)
  as.data.frame(payload$sources, stringsAsFactors = FALSE)
}
