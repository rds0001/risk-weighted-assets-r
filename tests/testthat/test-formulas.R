test_that("SA exposure at default and net paths matches Python", {
  params <- rwa_internal("default_parameter_store")()
  sa_ead <- rwa_internal("sa_ead")
  expected_ccf <- c(CLASS_1 = 1, CLASS_2 = .5, CLASS_3 = .4, CLASS_4 = .2, CLASS_5 = .1)
  for (cls in names(expected_ccf)) {
    value <- sa_ead(100, 0, 0, 0, 50, cls, "GROSS", params = params)
    expect_equal(unname(value[["ead_off"]]), 50 * expected_ccf[[cls]])
    expect_equal(unname(value[["ead"]]), 100 + 50 * expected_ccf[[cls]])
  }
  value <- sa_ead(100, 20, 0, 0, 0, "CLASS_1", "NET_ARTICLE_111", 80, params)
  expect_equal(unname(value[["ead_on"]]), 80)
})

test_that("IRB corporate golden formula matches Python to 1e-12", {
  params <- rwa_internal("default_parameter_store")()
  r <- rwa_internal("irb_correlation")(.01, params = params)
  k <- rwa_internal("irb_k")(.01, .40, r, 2.5, TRUE, FALSE, 0, params)
  expect_equal(r, 0.192783679165516, tolerance = 1e-12)
  expect_equal(k, 0.06564750321212547, tolerance = 1e-12)
  multiplier <- rwa_internal("parameter_get")(params, "RWA_MULTIPLIER", "PILLAR1")
  expect_equal(multiplier * k, 0.8205937901515684, tolerance = 1e-12)
})

test_that("retail IRB does not apply maturity adjustment", {
  params <- rwa_internal("default_parameter_store")()
  r <- rwa_internal("retail_correlation")(.01, "RETAIL_RESIDENTIAL", params)
  k1 <- rwa_internal("irb_k")(.01, .20, r, 1, FALSE, FALSE, 0, params)
  k5 <- rwa_internal("irb_k")(.01, .20, r, 5, FALSE, FALSE, 0, params)
  expect_identical(k1, k5)
})

test_that("SA-CCR, securitisation and BA-CVA golden cases hold", {
  params <- rwa_internal("default_parameter_store")()
  ead <- rwa_internal("sa_ccr_ead")(10, 4, 20,
    rwa_internal("parameter_get")(params, "SA_CCR", "ALPHA"), params)
  expect_equal(unname(ead[["rc"]]), 6)
  expect_gte(unname(ead[["multiplier"]]), rwa_internal("parameter_get")(params, "SA_CCR", "MULTIPLIER_FLOOR"))
  expect_lte(unname(ead[["multiplier"]]), 1)

  rw <- rwa_internal("securitisation_rw")("SEC_SA", .08, .10, .20, .5,
    FALSE, FALSE, FALSE, 6, params)
  expect_gte(rw, rwa_internal("parameter_get")(params, "SEC_FLOOR", "NON_STS"))
  expect_lte(rw, rwa_internal("parameter_get")(params, "SEC", "RW_CAP"))
  expect_error(rwa_internal("securitisation_ssfa_rw")(.08, .2, .1, .5, .15, params))

  item <- list(c(.05, 2, 1e6, 0, 0, 0, 0, 0, 0))
  capital <- rwa_internal("ba_cva_capital")(item, params)
  rate <- rwa_internal("parameter_get")(params, "BA_CVA", "DISCOUNT_RATE")
  discount <- (1 - exp(-rate * 2)) / (rate * 2)
  scva <- .05 * 2 * 1e6 * discount / rwa_internal("parameter_get")(params, "BA_CVA", "ALPHA")
  unhedged_weight <- rwa_internal("parameter_get")(params, "BA_CVA", "UNHEDGED_WEIGHT")
  expected <- (unhedged_weight + rwa_internal("parameter_get")(params, "BA_CVA", "HEDGED_WEIGHT") *
                 (1 - unhedged_weight)) * scva
  expect_equal(capital, expected, tolerance = 1e-12)
})

test_that("operational risk, floor, NPE and IRRBB formulas match golden cases", {
  params <- rwa_internal("default_parameter_store")()
  bic <- rwa_internal("bic_from_components")(
    rep(2e9, 3), rep(1e9, 3), rep(40e9, 3), rep(0, 3), rep(.2e9, 3),
    rep(.2e9, 3), rep(.3e9, 3), rep(.1e9, 3), rep(0, 3), rep(0, 3), params)
  expect_equal(unname(bic[["bi"]]), 1.4e9)
  expect_equal(unname(bic[["bic"]]), .12e9 + .15 * .4e9)

  factors <- c(`2025` = .5, `2026` = .55, `2027` = .6, `2028` = .65, `2029` = .7, `2030` = .725)
  for (year in names(factors)) {
    expect_equal(rwa_internal("output_floor_factor")(as.Date(paste0(year, "-12-31")), FALSE, params), factors[[year]])
  }
  floor_result <- rwa_internal("output_floor")(100, 200, .725, FALSE,
    rwa_internal("parameter_get")(params, "OUTPUT_FLOOR", "OPTIONAL_CAP"))
  expect_equal(floor_result$trea, 145)
  expect_true(floor_result$binding)
  expect_equal(vapply(1:4, rwa_internal("npe_unsecured_factor"), numeric(1), params = params), c(0, 0, .35, 1))

  expect_equal(rwa_internal("irrbb_shock")("PARALLEL_UP", 10, .02, .025, .01, params), .02)
  expect_gte(rwa_internal("shocked_zero_rate")(-.03, -.02, 1, params), -.03)
  expect_equal(rwa_internal("correlated_capital")(c(3, 4), diag(2)), 5)
})
