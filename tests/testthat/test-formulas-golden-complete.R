test_that("remaining pure regulatory formulas match Python golden cases", {
  p <- rwa_internal("default_parameter_store")()
  f <- rwa_internal
  expect_equal(f("normal_cdf")(1), .8413447460685429, tolerance = 1e-14)
  expect_equal(f("normal_ppf")(.975), 1.9599639845400536, tolerance = 1e-14)

  whole <- f("real_estate_weighted_rw")(
    80, 100, "RESIDENTIAL", TRUE, 1, 0, FALSE, p
  )
  split <- f("real_estate_weighted_rw")(
    80, 100, "RESIDENTIAL", FALSE, 1, 0, FALSE, p
  )
  expect_equal(whole$risk_weight, .45)
  expect_equal(split$risk_weight, .45)
  expect_equal(sum(split$segments$amount), 80)

  expect_equal(f("crm_maturity_mismatch_factor")(2, 5, .25, 5),
               .3684210526315789, tolerance = 1e-14)
  expect_equal(f("comprehensive_crm")(100, 80, .1, .05, .08),
               40.40000000000002, tolerance = 1e-14)
  expect_equal(f("irb_correlation")(.01, 10, TRUE, p),
               .19653515451245054, tolerance = 1e-14)
  expect_equal(f("retail_correlation")(.01, "OTHER_RETAIL", p),
               .12160945166343272, tolerance = 1e-14)
  expect_equal(f("irb_maturity_b")(.01, p),
               .13748613089693737, tolerance = 1e-14)
  expect_equal(f("irb_maturity_adjustment")(.01, 2.5, p),
               1.2598095009238282, tolerance = 1e-14)

  expect_equal(f("sa_ccr_multiplier")(10, 4, 20, p), 1)
  expect_equal(f("sft_ead")(100, 90, .1, .08), 26.19999999999999,
               tolerance = 1e-14)
  expect_equal(f("sec_k_irb")(1000, 20, 2000, p), .05)
  expect_equal(f("sec_k_sa")(1000, 2000, p), .04)
  expect_equal(f("ssfa_k")(.08, .1, .2, .5), .22269743653790774,
               tolerance = 1e-14)
  expect_equal(f("securitisation_ssfa_rw")(.08, .1, .2, .5, .15, p),
               2.783717956723847, tolerance = 1e-14)
  irba <- f("sec_irba_p")("NON_RETAIL", TRUE, 30, .08, .4, 3, FALSE, p)
  expect_equal(unname(irba), c(.4006666666666667, .4006666666666667),
               tolerance = 1e-14)
  expect_equal(f("sec_erba_rw")(3, 3, FALSE, FALSE, .1, .3, p), .6,
               tolerance = 1e-14)
  expect_equal(f("settlement_factor")(20, p), .5)
  expect_equal(f("npe_secured_factor")(7, TRUE, p), .7)
  expect_equal(f("t2_eligible_amount")(100, 100, as.Date("2028-08-31"),
                                         as.Date("2026-08-31"), p),
               40.0328587075575, tolerance = 1e-13)
})

test_that("market aggregation and canonical stochastic path are deterministic", {
  quadratic <- rwa_internal("market_quadratic")
  expect_equal(quadratic(c(1, -2), matrix(c(1, .5, .5, 1), 2)), sqrt(3))
  expect_equal(quadratic(c(-1, -2), matrix(c(1, .5, .5, 1), 2), TRUE), sqrt(5))

  z <- rwa_internal("deterministic_normals")(5000, 1, 20260831)
  expect_equal(z[1:5], c(
    -.31962158218552156, -.26098908832367107, .22137357215636785,
    1.568407040844316, -.8245556895501467
  ), tolerance = 1e-15)
})

test_that("pure formula guards reject structurally invalid inputs", {
  p <- rwa_internal("default_parameter_store")()
  expect_error(rwa_internal("sa_ead")(100, 0, 0, 0, 0, "CLASS_1",
                                       "NET_ARTICLE_111", NULL, p))
  expect_error(rwa_internal("correlated_capital")(c(1, 2), diag(3)))
  expect_error(rwa_internal("irrbb_shock")("UNKNOWN", 1, .01, .01, .01, p))
  expect_error(rwa_internal("ba_cva_capital")(list(c(1, 2)), p))
})
