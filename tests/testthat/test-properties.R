test_that("discount factors and maturity adjustments satisfy invariants", {
  params <- rwa_internal("default_parameter_store")()
  rates <- seq(-.02, .15, length.out = 50)
  times <- seq(0, 30, length.out = 50)
  values <- mapply(rwa_internal("discount_factor"), rates, times)
  expect_true(all(is.finite(values)))
  expect_true(all(values > 0))
  expect_equal(rwa_internal("discount_factor")(.05, 0), 1)

  pd <- seq(.0005, .20, length.out = 50)
  b <- vapply(pd, rwa_internal("irb_maturity_b"), numeric(1), params = params)
  expect_true(all(is.finite(b)))
  expect_true(all(b > 0))
})

test_that("output floor is monotone and never below unfloored TREA", {
  params <- rwa_internal("default_parameter_store")()
  factors <- seq(0, .725, length.out = 30)
  trea <- vapply(factors, function(factor) {
    rwa_internal("output_floor")(100, 200, factor, FALSE, 1e99)$trea
  }, numeric(1))
  expect_true(all(diff(trea) >= 0))
  expect_true(all(trea >= 100))
})

test_that("IRB capital is finite across a broad admissible grid", {
  params <- rwa_internal("default_parameter_store")()
  pds <- exp(seq(log(.00005), log(.40), length.out = 40))
  values <- vapply(pds, function(pd) {
    correlation <- rwa_internal("irb_correlation")(pd, params = params)
    rwa_internal("irb_k")(pd, .45, correlation, 2.5, TRUE, FALSE, 0, params)
  }, numeric(1))
  expect_true(all(is.finite(values)))
  expect_true(all(values >= 0))
})
