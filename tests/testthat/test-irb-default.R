default_scenario <- function(approach = "FIRB", pd = .02, elbe = .1,
                             default = TRUE, subclass = "CORPORATE") {
  t <- generate_synthetic_tables(bank_profile = "MID_SIZE_UNIVERSAL", seed = 5752026)
  mask <- t$irb_parameter$exposure_id == "EXP-000001"
  values <- list(irb_approach = approach, irb_subclass = subclass, pd_estimate = pd,
    lgd_estimate = .4, lgd_floor = 0, ead_estimate = 1e6, ead_floor = 0, elbe = elbe,
    specific_credit_adjustments = 250000, general_credit_adjustments = 0)
  for (key in names(values)) t$irb_parameter[mask, key] <- values[[key]]
  t$exposure_lot$default_flag[t$exposure_lot$exposure_id == "EXP-000001"] <- default
  mask <- t$exposure_lot$exposure_id == "EXP-000001"
  t$exposure_lot$specific_credit_adjustments[mask] <- 250000
  t$exposure_lot$general_credit_adjustments[mask] <- 0
  t
}

test_that("public default cases match independently specified Python/R values", {
  cases <- data.frame(approach = c("FIRB","FIRB","AIRB","AIRB","AIRB"),
    elbe = c(.1,.8,.1,.4,.5), k = c(0,0,.3,0,0), el = c(400000,400000,100000,400000,500000))
  for (i in seq_len(nrow(cases))) {
    case <- cases[i, ]
    input_pd <- if (case$approach == "FIRB" && case$elbe == .1) 1 else .02
    source <- default_scenario(case$approach, pd = input_pd, elbe = case$elbe)
    result <- calculate_tables(source)
    expect_true(all(vapply(result$controls, function(x) x$passed, logical(1))))
    expect_true(all(source$irb_parameter$pd_estimate[source$irb_parameter$exposure_id == "EXP-000001"] == input_pd))
    for (view in c("applied", "parallel")) {
      frames <- if (view == "applied") result$results else result$parallel_results
      m <- if (view == "applied") result$metrics else result$parallel_metrics
      detail <- frames$IRB_Detail
      row <- detail[detail$exposure_id == "EXP-000001", ]
      expect_equal(row$pd, 1); expect_equal(row$pd_input, input_pd)
      expect_equal(row$lgd_treatment, if (case$approach == "FIRB") "SUPERVISORY" else "OWN_ESTIMATES")
      expect_equal(row$k, case$k); expect_equal(row$rw, 12.5*case$k)
      expect_equal(row$rwea, 12500000*case$k)
      expect_equal(row$el_rate, case$el/1e6); expect_equal(row$el_amount, case$el)
      expect_equal(row$irb_shortfall, max(case$el-250000, 0))
      expect_equal(row$irb_excess, max(250000-case$el, 0))
      for (pair in list(c("RWEA_IRB","rwea"),c("IRB_EL","el_amount"),
                        c("IRB_SHORTFALL","irb_shortfall"),c("IRB_EXCESS","irb_excess")))
        expect_equal(m[[pair[1]]], sum(detail[[pair[2]]]))
      expect_equal(m$TREA, max(m$U_TREA, m$OUTPUT_FLOOR_FACTOR*m$S_TREA))
    }
  }
})

test_that("correction propagates through own funds and both TREA views", {
  firb <- calculate_tables(default_scenario())
  airb <- calculate_tables(default_scenario("AIRB"))
  for (field in c("metrics", "parallel_metrics")) {
    a <- firb[[field]]; b <- airb[[field]]
    expect_equal(a$IRB_EL-b$IRB_EL, 300000)
    expect_equal(a$IRB_SHORTFALL-b$IRB_SHORTFALL, 150000)
    expect_equal(a$CET1-b$CET1, -150000)
    expect_equal(a$U_TREA-b$U_TREA, -3750000)
    expect_equal(a$S_TREA, b$S_TREA)
    expect_equal(a$T2-b$T2, min(a$IRB_EXCESS,.006*a$RWEA_IRB)-min(b$IRB_EXCESS,.006*b$RWEA_IRB))
  }
})

test_that("supported retail defaults keep own LGD treatment", {
  for (subclass in c("RETAIL_RESIDENTIAL","RETAIL_QRRE","RETAIL_OTHER")) {
    r <- calculate_tables(default_scenario("AIRB", subclass = subclass))
    row <- r$results$IRB_Detail[r$results$IRB_Detail$exposure_id == "EXP-000001", ]
    expect_equal(row$k, .3); expect_equal(row$el_amount, 100000)
  }
})

test_that("direct formula contract is explicit and fail closed", {
  for (treatment in list(NULL, "UNKNOWN", "")) expect_error(
    irb_capital_requirement(1,.4,.2,2.5,defaulted=TRUE,elbe=.1,lgd_treatment=treatment), "lgd_treatment")
  for (elbe in c(.1,.4,.8)) expect_equal(
    irb_capital_requirement(.02,.4,.2,2.5,defaulted=TRUE,elbe=elbe,lgd_treatment="SUPERVISORY"), 0)
  expect_equal(irb_capital_requirement(.02,.4,.2,2.5,defaulted=TRUE,elbe=.1,
    lgd_treatment="OWN_ESTIMATES"), .3)
  expect_error(irb_capital_requirement(1,.4,.2,2.5), "contradicts")
  expect_error(irb_retail_correlation(.01,"RETAIL_TYPO"), "subclass")
  for (bad in c(NA_real_, Inf, -.1, 1.1)) expect_error(
    irb_capital_requirement(bad,.4,.2,2.5,defaulted=TRUE,lgd_treatment="SUPERVISORY"), "pd")
  expect_error(irb_capital_requirement(.01,.4,.2,2.5,defaulted="FALSE"), "boolean")
  expect_error(calculate_tables(default_scenario("UNKNOWN")), "Unsupported")
  expect_error(calculate_tables(default_scenario("SLOTTING")), "Unsupported")
  expect_error(calculate_tables(default_scenario("FIRB",subclass="RETAIL_OTHER")), "requires")
  expect_error(calculate_tables(default_scenario("AIRB",subclass="RETAIL_TYPO")), "Unsupported")
  expect_error(calculate_tables(default_scenario(pd=1,default=FALSE)), "contradicts")
})

test_that("performing capital and retail correlation retain independent references", {
  pd <- .01; lgd <- .4; r <- .2
  b <- (.11852-.05478*log(pd))^2
  expected <- (lgd*pnorm((qnorm(pd)+sqrt(r)*qnorm(.999))/sqrt(1-r))-pd*lgd)/(1-1.5*b)
  for (treatment in c("SUPERVISORY","OWN_ESTIMATES")) expect_equal(
    irb_capital_requirement(pd,lgd,r,2.5,lgd_treatment=treatment), expected)
  w <- (1-exp(-35*pd))/(1-exp(-35))
  r <- .03*w+.16*(1-w)
  expect_equal(irb_retail_correlation(pd,"RETAIL_OTHER"), r)
  expected <- lgd*pnorm((qnorm(pd)+sqrt(r)*qnorm(.999))/sqrt(1-r))-pd*lgd
  for (m in c(1,5)) expect_equal(irb_capital_requirement(pd,lgd,r,m,
    apply_maturity_adjustment=FALSE,lgd_treatment="OWN_ESTIMATES"), expected)
})
