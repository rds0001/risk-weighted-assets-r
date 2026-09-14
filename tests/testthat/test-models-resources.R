test_that("validation and calculation S3 models expose stable semantics", {
  new_message <- rwa_internal("new_validation_message")
  new_report <- rwa_internal("new_validation_report")
  report <- new_report(list(new_message("WARNING", "W1"), new_message("ERROR", "E1")))
  expect_false(rwa_internal("validation_valid")(report))
  expect_equal(nrow(as.data.frame(report)), 2)

  result <- rwa_internal("new_calculation_result")(
    "CALCULATED", "TEST", "1.0.0", "CRR3-EU",
    controls = list(list(passed = TRUE)), validation = new_report())
  expect_true(rwa_internal("calculation_successful")(result))
  expect_equal(rwa_internal("controls_passed")(result), 1)
})

test_that("reference metadata is available without downloads", {
  profiles <- list_reference_profiles()
  datasets <- list_reference_datasets()
  sources <- regulatory_sources()
  expect_setequal(profiles$profile_id, c("KSA_BANK", "MID_SIZE_UNIVERSAL"))
  expect_equal(nrow(datasets), 2)
  expect_true(all(!sources$redistributed))
  expect_true(all(grepl("^https://", sources$official_url)))
})

test_that("workspace writes only to caller-selected destination", {
  destination <- tempfile("rwa-workspace-")
  workspace <- create_workspace(destination)
  expect_s3_class(workspace, "rwa_workspace")
  expect_true(file.exists(file.path(destination, "workspace_manifest.json")))
  universal <- file.path(workspace$runs_root, "2026-08-31", "v1.0.0", "inputs")
  ksa <- file.path(workspace$runs_root, "2026-08-31", "v1.0.0-ksa", "inputs")
  expect_equal(length(list.files(universal, pattern = "[.]xlsx$")), 16L)
  expect_equal(length(list.files(ksa, pattern = "[.]xlsx$")), 16L)
  expect_error(create_workspace(destination), class = "rwa_resource_error")
})
