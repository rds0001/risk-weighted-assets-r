test_that("knowledge timestamps preserve ISO times, fractions and UTC instants", {
  parse <- rwa_internal("parse_knowledge_time")
  expected <- as.POSIXct("2026-08-31 23:59:59", tz = "UTC")
  for (value in list("2026-08-31T23:59:59", "2026-08-31T23:59:59Z",
                     "2026-08-31 23:59:59", expected, as.POSIXlt(expected))) {
    expect_equal(as.numeric(parse(value)), as.numeric(expected))
  }
  expect_equal(as.numeric(parse("2026-08-31T23:59:59.5Z")),
               as.numeric(expected) + .5)
  expect_equal(parse("2026-08-31"), as.POSIXct("2026-08-31", tz = "UTC"))
  expect_equal(parse(as.Date("2026-08-31")), as.POSIXct("2026-08-31", tz = "UTC"))
  for (value in list(NULL, NA, "", "UNKNOWN", "2026-99-31T23:59:59",
                     "2026-08-31T23:59:59junk", c("2026-08-31","2026-09-01"), 123)) {
    expect_error(parse(value), class = "rwa_configuration_error")
  }
})

test_that("default public snapshot equals the explicit end-of-day snapshot", {
  tables <- generate_synthetic_tables(bank_profile = "KSA_BANK", seed = 5752026)
  before <- tables
  expected <- official_snapshot(tables,
    knowledge_time = as.POSIXct("2026-08-31 23:59:59", tz = "UTC"))
  implicit <- official_snapshot(tables)
  expect_equal(nrow(implicit$business_indicator_item), 30L)
  expect_identical(implicit, expected)
  expect_identical(tables, before)
  for (value in c("2026-08-31T23:59:59Z", "2026-08-31 23:59:59")) {
    expect_identical(official_snapshot(tables, knowledge_time = value), expected)
  }
  expect_equal(nrow(official_snapshot(tables,
    knowledge_time = "2026-08-31T00:00:00Z")$business_indicator_item), 0L)
})
