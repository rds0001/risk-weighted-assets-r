boolean_cases <- function() {
  rows <- read.csv(test_path("fixtures", "regulatory_boolean_cases.csv"),
                   colClasses="character", na.strings=character(), strip.white=FALSE)
  decode <- function(kind, value) switch(kind, bool=value == "1", int=as.integer(value),
    float=as.numeric(value), str=value, null=NULL, nan=NaN, na=NA)
  rows$value_decoded <- I(Map(decode, rows$kind, rows$value))
  rows
}

boolean_portfolio <- function(sources, values, irb) {
  t <- sources$KSA_BANK
  n <- length(values)
  for (name in c("exposure_lot","sa_classification","irb_parameter")) {
    original <- if (name == "irb_parameter") sources$MID_SIZE_UNIVERSAL else t
    row <- original[[name]][original[[name]]$exposure_id == "EXP-000001", , drop=FALSE][1, , drop=FALSE]
    t[[name]] <- row[rep(1L,n), , drop=FALSE]
    ids <- sprintf("BOOL-%03d",seq_len(n)-1L)
    t[[name]]$exposure_id <- t[[name]]$business_key <- ids
    t[[name]]$record_id <- paste0(ids,"::v1")
    rownames(t[[name]]) <- NULL
  }
  t$exposure_lot$default_flag <- I(values)
  fields <- list(approach=if (irb) "IRB" else "KSA",gross_carrying_amount=1e6,
    net_carrying_amount_article_111=1e6,ead_data_path="GROSS",
    specific_credit_adjustments=0,general_credit_adjustments=0,
    additional_valuation_adjustments=0,other_own_funds_reductions=0,committed_undrawn=0)
  for (key in names(fields)) t$exposure_lot[[key]] <- fields[[key]]
  fields <- list(exposure_class="CORPORATE",credit_quality_step=3,short_term_flag=FALSE,
    transactor_flag=FALSE,retail_eligible_flag=FALSE,specialised_lending_type="",
    risk_weight_override=NA_real_,currency_mismatch_flag=FALSE,supporting_factor=1,
    supporting_factor_type="NONE",sme_supporting_eligible=FALSE,infrastructure_supporting_eligible=FALSE)
  for (key in names(fields)) t$sa_classification[[key]] <- fields[[key]]
  fields <- list(irb_approach="FIRB",irb_subclass="CORPORATE",pd_estimate=.0005,
    pd_floor=0,lgd_estimate=.4,lgd_floor=0,ead_estimate=1e6,ead_floor=0,elbe=.1)
  for (key in names(fields)) t$irb_parameter[[key]] <- fields[[key]]
  if (!irb) t$irb_parameter <- t$irb_parameter[0, , drop=FALSE]
  for (name in c("real_estate_exposure","protection_allocation","crypto_exposure"))
    t[[name]] <- t[[name]][0, , drop=FALSE]
  t$business_indicator_item$amount <- 0
  t$rule_set$output_floor_factor <- .725
  t
}

test_that("Python/R shared boolean vectors have one explicit classification", {
  cases <- boolean_cases()
  for (i in seq_len(nrow(cases))) {
    value <- cases$value_decoded[[i]]
    if (cases$expected[i] == "ERROR") {
      expect_error(rwa_internal("regulatory_bool")(value,"default_flag"),
                   "default_flag must be an explicit boolean", info=cases$id[i])
    } else expect_identical(rwa_internal("regulatory_bool")(value,"default_flag"),
                             cases$expected[i] == "TRUE", info=cases$id[i])
  }
})

test_that("public KSA and binding-floor portfolios are representation invariant", {
  sources <- lapply(c("KSA_BANK","MID_SIZE_UNIVERSAL"), function(p)
    official_snapshot(generate_synthetic_tables(bank_profile=p,seed=5752026),
      as_of_date=as.Date("2026-08-31"),
      knowledge_time=as.POSIXct("2026-08-31 23:59:59",tz="UTC")))
  names(sources) <- c("KSA_BANK","MID_SIZE_UNIVERSAL")
  cases <- boolean_cases()
  for (irb in c(FALSE,TRUE)) for (expected in c(TRUE,FALSE)) {
    values <- unclass(cases$value_decoded[cases$expected == if (expected) "TRUE" else "FALSE"])
    t <- boolean_portfolio(sources,values,irb)
    before <- t$exposure_lot$default_flag
    mixed <- calculate_tables(t)
    canonical <- calculate_tables(boolean_portfolio(sources,rep(list(expected),length(values)),irb))
    expect_identical(t$exposure_lot$default_flag,before)
    expect_true(all(vapply(mixed$controls,function(x) x$passed,logical(1))))
    rw <- if (expected) 1.5 else .75
    for (view in c("applied","parallel")) {
      frames <- if (view == "applied") mixed$results else mixed$parallel_results
      m <- if (view == "applied") mixed$metrics else mixed$parallel_metrics
      reference <- if (view == "applied") canonical$metrics else canonical$parallel_metrics
      sa <- frames$SA_Detail
      expect_true(all(sa$defaulted == expected))
      expect_true(all(sa$risk_weight == rw))
      expect_true(all(sa$rwea == 1e6*rw))
      expect_true(all(sa$shadow_rwea == 1e6*rw))
      fields <- c("RWEA_KSA","RWEA_IRB","IRB_EL","U_TREA","S_TREA","TREA","FLOOR_UPLIFT")
      expect_identical(m[fields],reference[fields])
      expect_equal(m$S_TREA,length(values)*1e6*rw)
      if (irb) {
        detail <- frames$IRB_Detail
        expect_true(all(detail$defaulted == expected))
        expect_true(all(detail$pd == if (expected) 1 else .0005))
        if (expected) {
          expect_true(all(detail$k == 0)); expect_true(all(detail$el_amount == 400000))
        }
        expect_true(m$FLOOR_BINDING)
        expect_equal(m$TREA,.725*m$S_TREA)
      } else {
        expect_equal(nrow(frames$IRB_Detail),0L)
        expect_equal(m$RWEA_KSA,length(values)*1e6*rw)
        expect_equal(m$U_TREA,m$RWEA_KSA); expect_equal(m$TREA,m$U_TREA)
      }
    }
  }
  for (irb in c(FALSE,TRUE)) for (i in which(cases$expected == "ERROR")) {
    expect_error(calculate_tables(boolean_portfolio(sources,list(cases$value_decoded[[i]]),irb)),
      "default_flag must be an explicit boolean", info=cases$id[i])
  }
})
