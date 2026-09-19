support_test_tables <- function() {
  tables <- generate_synthetic_tables()
  tables <- lapply(tables, rwa_internal("select_official_as_of"),
                   as.Date("2026-08-31"), as.POSIXct("2026-08-31 23:59:59", tz="UTC"))
  for (name in c("exposure_lot", "sa_classification", "irb_parameter", "real_estate_exposure")) {
    tables[[name]] <- tables[[name]][as.character(tables[[name]]$exposure_id) == "EXP-000001", , drop=FALSE]
  }
  for (name in c("crypto_exposure", "protection_allocation")) tables[[name]] <- tables[[name]][0, , drop=FALSE]
  tables
}

support_test_run <- function(tables, floor=.55, fully_loaded=FALSE, with_floor=FALSE) {
  p <- rwa_internal("new_parameter_store")(tables$regulatory_parameter)
  ctx <- rwa_internal("new_calculation_context")(as.Date("2026-08-31"),
    as.POSIXct("2026-08-31 23:59:59", tz="UTC"), "CRR3-EU-2026", p, "EUR", "LEGACY", floor)
  out <- rwa_internal("new_calculation_bundle")()
  rwa_internal("calculate_credit")(tables, ctx, out)
  if (with_floor) {
    for (name in c("K_MARKET_FRTB","K_MARKET_LEGACY","K_CVA_SA","K_CVA",
                   "K_SETTLEMENT","K_LARGE_EXPOSURE","K_OPERATIONAL")) out$metrics[[name]] <- 0
    rwa_internal("calculate_trea")(ctx, out, fully_loaded)
  }
  out
}

test_that("support factors match independent shared numeric cases", {
  expect_equal(sme_supporting_factor(1e6), .7619)
  expect_equal(sme_supporting_factor(2.5e6), .7619)
  expect_equal(sme_supporting_factor(5e6), .80595)
  expect_equal(infrastructure_supporting_factor(), .75)
  expect_equal(apply_credit_supporting_factors(1e6, .80595, .75), 604462.5)
  expect_equal(irb_risk_weighted_assets(1e6, .08, .80595, .75), 604462.5)
  expect_equal(irb_risk_weighted_assets(1e6, .08), 1e6)
  for (bad in list(0, -1, NA_real_, Inf, NaN, "bad", TRUE)) expect_error(sme_supporting_factor(bad))
  for (bad in list(0, -.1, 1.01, NA_real_, Inf, TRUE)) expect_error(apply_credit_supporting_factors(100, bad))
})

test_that("eligibility, evidence, finite values and combined factors are enforced", {
  p <- rwa_internal("default_parameter_store")()
  resolve <- rwa_internal("resolve_support")
  row <- list(irb_subclass="CORPORATE", default_flag=FALSE, annual_sales_eur=20e6,
    sme_supporting_eligible=TRUE, infrastructure_supporting_eligible=TRUE,
    sme_total_amount_owed_eur=5e6, supporting_factor_reference="SYNTHETIC-001",
    supporting_factor_approved_by="Synthetic Model Risk")
  detail <- resolve(row, p, "IRB")
  expect_equal(detail$supporting_factor, .6044625)
  expect_equal(detail$supporting_factor_type, "SME_INFRASTRUCTURE")
  changes <- list(default_flag=TRUE, adc_flag=TRUE, annual_sales_eur=50e6+1,
    supporting_factor_reference="", supporting_factor_approved_by="",
    irb_subclass="INSTITUTION", supporting_factor=.75, sme_supporting_eligible="maybe",
    sme_total_amount_owed_eur=NA_real_, supporting_factor_type="INFRASTRUCTURE")
  for (name in names(changes)) {
    changed <- row
    changed[[name]] <- changes[[name]]
    expect_error(resolve(changed, p, "IRB"), info=name)
  }
  legacy <- list(supporting_factor=.7619, supporting_factor_type="SME")
  expect_equal(resolve(legacy, NULL, "SA")$supporting_factor_status, "LEGACY_SA_UNVERIFIED")
  expect_error(resolve(legacy, NULL, "IRB"))
  expect_equal(resolve(list(), NULL, "IRB")$supporting_factor, 1)
})

test_that("the IRB correction does not change K, EL or the SA comparison", {
  tables <- support_test_tables()
  before <- support_test_run(tables)
  tables$irb_parameter$infrastructure_supporting_eligible <- TRUE
  tables$irb_parameter$supporting_factor_reference <- "SYNTHETIC-501A"
  tables$irb_parameter$supporting_factor_approved_by <- "Synthetic Model Risk"
  after <- support_test_run(tables)
  a <- after$results$IRB_Detail; b <- before$results$IRB_Detail
  expect_equal(a$rwea, b$rwea * .75)
  for (field in c("k","pd","lgd","ead","el_amount","irb_shortfall","irb_excess","rw")) {
    expect_equal(a[[field]], b[[field]], info=field)
  }
  expect_equal(a$effective_rw, b$rw * .75)
  expect_equal(after$metrics$RWEA_KSA_SHADOW_ALL, before$metrics$RWEA_KSA_SHADOW_ALL)
  expect_equal(a$supporting_factor_relief, b$rwea * .25)
  tables$exposure_lot$default_flag <- TRUE
  expect_error(support_test_run(tables), "defaulted")
})

test_that("support flows into both floor paths once, for both calculation views", {
  tables <- support_test_tables()
  for (name in c("irb_parameter","sa_classification")) {
    tables[[name]]$infrastructure_supporting_eligible <- TRUE
    tables[[name]]$supporting_factor_reference <- "SYNTHETIC-501A"
    tables[[name]]$supporting_factor_approved_by <- "Synthetic Model Risk"
    tables[[name]]$supporting_factor_type <- "INFRASTRUCTURE"
    tables[[name]]$supporting_factor <- .75
  }
  for (floor in c(.1, 1)) for (full in c(FALSE, TRUE)) {
    out <- support_test_run(tables, floor, full, TRUE)
    u <- out$metrics$RWEA_IRB; s <- sum(out$results$SA_Detail$rwea)
    expect_equal(out$metrics$U_TREA, u)
    expect_equal(out$metrics$S_TREA, s)
    expect_equal(out$metrics$TREA, max(u, floor*s))
    expect_equal(out$metrics$FLOOR_BINDING, floor == 1)
  }
})

test_that("new parameters remain governed and old table inputs remain usable", {
  parameters <- regulatory_parameters()
  changed <- parameters
  mask <- changed$parameter_key == "SUPPORTING_FACTOR" & changed$dimension_1 == "INFRASTRUCTURE"
  changed$parameter_value[mask] <- .8
  expect_equal(infrastructure_supporting_factor(changed), .8)
  expect_equal(infrastructure_supporting_factor(parameters), .75)
  old <- data.frame(exposure_id="X")
  new <- rwa_internal("normalize_support_columns")(old, "irb_parameter")
  expect_false("supporting_factor" %in% names(old))
  expect_equal(rwa_internal("resolve_support")(as.list(new), NULL, "IRB")$supporting_factor, 1)
})

test_that("supporting evidence and both adjusted paths survive Excel round trips", {
  tables <- support_test_tables()
  for (name in c("sa_classification", "irb_parameter")) {
    tables[[name]]$supporting_factor_type <- "INFRASTRUCTURE"
    tables[[name]]$supporting_factor <- .75
    tables[[name]]$infrastructure_supporting_eligible <- TRUE
    tables[[name]]$supporting_factor_reference <- "SYNTHETIC-XLSX-501A"
    tables[[name]]$supporting_factor_approved_by <- "Synthetic Model Risk"
  }
  expected <- support_test_run(tables)
  directory <- tempfile("support-roundtrip-")
  rwa_internal("write_input_workbooks")(directory, tables)
  loaded <- rwa_internal("read_input_workbooks")(directory)
  expect_length(loaded$issues, 0L)
  actual <- support_test_run(loaded$tables)
  for (name in c("SA_Detail", "IRB_Detail")) {
    expect_equal(actual$results[[name]]$rwea, expected$results[[name]]$rwea)
    expect_equal(actual$results[[name]]$supporting_factor_status, "VERIFIED_INPUT")
    expect_equal(actual$results[[name]]$supporting_factor_reference, "SYNTHETIC-XLSX-501A")
  }
  expect_false(actual$results$IRB_Detail$supporting_factor_path_difference)
})

test_that("the public portfolio calculation reconciles explicit IRB support", {
  tables <- generate_synthetic_tables(bank_profile = "MID_SIZE_UNIVERSAL")
  mask <- tables$irb_parameter$exposure_id == "EXP-000001"
  tables$irb_parameter$infrastructure_supporting_eligible[mask] <- TRUE
  tables$irb_parameter$supporting_factor_reference[mask] <- "SYNTHETIC-PUBLIC-501A"
  tables$irb_parameter$supporting_factor_approved_by[mask] <- "Synthetic Model Risk"
  result <- calculate_tables(tables)
  expect_true(all(vapply(result$controls, function(x) x$passed, logical(1))))
  for (frames in list(result$results, result$parallel_results)) {
    row <- frames$IRB_Detail[frames$IRB_Detail$exposure_id == "EXP-000001", ]
    expect_equal(row$rwea, row$rwea_pre_supporting_factor * .75)
  }
})
