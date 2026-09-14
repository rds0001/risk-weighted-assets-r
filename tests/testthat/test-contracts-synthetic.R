test_that("canonical fixtures preserve FALSE values and all table contracts", {
  tables <- generate_synthetic_tables()
  expect_equal(length(tables), 68L)
  expect_equal(sum(vapply(tables, nrow, integer(1))), 14396L)
  expect_false(tables$sa_classification$short_term_flag[
    tables$sa_classification$exposure_id == "EXP-000001"
  ])
  expect_equal(sum(tables$sa_classification$short_term_flag), 66L)
  expect_equal(sum(tables$sa_classification$retail_eligible_flag), 517L)
  expect_equal(nrow(tables$formula_definition), 39L)
  expect_setequal(
    tables$formula_definition$formula_id,
    names(rwa_internal("load_regulatory_config")()$formula_registry)
  )
})

test_that("profile transformations are declarative and complete", {
  universal <- generate_synthetic_tables(bank_profile = "MID_SIZE_UNIVERSAL")
  ksa <- generate_synthetic_tables(bank_profile = "KSA_BANK")
  expect_gt(nrow(universal$irb_parameter), 0L)
  expect_equal(nrow(ksa$irb_parameter), 0L)
  expect_true(all(ksa$exposure_lot$approach == "KSA"))
  expect_equal(names(ksa), names(universal))
  expect_true(rwa_internal("validation_valid")(
    rwa_internal("validate_tables_public")(ksa)
  ))
})

test_that("temporal shifting preserves publication dates and advances snapshots", {
  baseline <- generate_synthetic_tables(as_of = as.Date("2026-08-31"))
  shifted <- generate_synthetic_tables(as_of = as.Date("2027-08-31"))
  expect_equal(as.numeric(as.Date(shifted$exposure_lot$as_of_date[[1L]]) -
                            as.Date(baseline$exposure_lot$as_of_date[[1L]])), 365)
  expect_identical(shifted$legal_source$publication_date,
                   baseline$legal_source$publication_date)
})

test_that("workbook generation round-trips through public validation", {
  root <- tempfile("rwa-dataset-")
  dataset <- generate_synthetic_dataset(
    root, bank_profile = "KSA_BANK", version = "test", overwrite = TRUE
  )
  expect_equal(length(list.files(file.path(dataset, "inputs"), pattern = "[.]xlsx$")), 16L)
  report <- validate_dataset(dataset)
  expect_true(rwa_internal("validation_valid")(report))
  issues <- as.data.frame(report)
  expect_equal(sum(issues$severity == "ERROR"), 0L)
  expect_equal(sum(issues$severity == "WARNING"), 17L)
  loaded <- rwa_internal("read_input_workbooks")(file.path(dataset, "inputs"))$tables
  expect_false(loaded$sa_classification$short_term_flag[
    loaded$sa_classification$exposure_id == "EXP-000001"
  ])
})
