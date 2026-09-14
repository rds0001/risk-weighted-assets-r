# Copyright (C) 2026 RiskDataScience GmbH
# SPDX-License-Identifier: GPL-3.0-only

engine_version <- function() {
  tryCatch(as.character(utils::packageVersion("riskweightedassets")), error = function(e) "1.0.0")
}

run_configuration <- function(tables) {
  frame <- tables$run_config
  setNames(as.character(frame$config_value), as.character(frame$config_key))
}

rule_context <- function(tables, rule_set_id) {
  selected <- tables$rule_set[as.character(tables$rule_set$rule_set_id) == rule_set_id, , drop = FALSE]
  if (nrow(selected) != 1L) abort_calculation(sprintf("Rule set is missing or ambiguous: %s", rule_set_id))
  list(market_regime = as.character(selected$market_regime[[1L]]),
       output_floor_factor = as.numeric(selected$output_floor_factor[[1L]]),
       reporting_currency = as.character(selected$reporting_currency[[1L]]))
}

apply_official_designations <- function(raw, snapshot) {
  designations <- snapshot$official_designation
  if (is.null(designations) || !nrow(designations)) return(snapshot)
  for (i in seq_len(nrow(designations))) {
    d <- designations[i, , drop = FALSE]; object_type <- as.character(d$object_type)
    if (is.null(raw[[object_type]])) next
    selected <- raw[[object_type]][as.character(raw[[object_type]]$record_id) ==
                                     as.character(d$designated_record_id), , drop = FALSE]
    if (!nrow(selected)) next
    business_key <- as.character(d$designated_business_key)
    current <- snapshot[[object_type]]
    snapshot[[object_type]] <- rbind(current[as.character(current$business_key) != business_key, , drop = FALSE], selected)
    rownames(snapshot[[object_type]]) <- NULL
  }
  snapshot
}

validate_legal_files <- function(tables, project_root = NULL) {
  inventory <- regulatory_sources(); sources <- tables$legal_source
  issues <- list()
  if (is.null(sources) || !nrow(sources)) return(issues)
  root <- normalizePath(project_root %||% getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(nrow(sources))) {
    r <- sources[i, , drop = FALSE]; source_id <- rwa_text(r$source_id)
    local <- rwa_text(r$local_file); expected <- tolower(rwa_text(r$sha256)); official <- rwa_text(r$official_url)
    external <- inventory[as.character(inventory$source_id) == source_id, , drop = FALSE]
    provenance_matches <- nrow(external) == 1L && !isTRUE(external$redistributed[[1L]]) &&
      identical(as.character(external$official_url[[1L]]), official) &&
      identical(tolower(as.character(external$archival_sha256[[1L]])), expected)
    if (!nzchar(local)) {
      if (!provenance_matches) issues[[length(issues) + 1L]] <- validation_issue(
        "ERROR", "MISSING_SOURCE_PROVENANCE", "legal_source", as.character(r$record_id),
        "local_file", "Local source or matching external provenance is missing")
      next
    }
    path <- if (grepl("^(/|[A-Za-z]:)", local)) local else file.path(root, local)
    if (!file.exists(path)) {
      if (!provenance_matches) issues[[length(issues) + 1L]] <- validation_issue(
        "ERROR", "MISSING_LEGAL_FILE", "legal_source", as.character(r$record_id), "local_file", path)
    } else {
      actual <- digest::digest(file = path, algo = "sha256")
      if (!nzchar(expected) || actual != expected) issues[[length(issues) + 1L]] <- validation_issue(
        "ERROR", "LEGAL_FILE_HASH_MISMATCH", "legal_source", as.character(r$record_id), "sha256",
        sprintf("expected=%s, actual=%s", expected, actual))
    }
  }
  issues
}

run_one <- function(tables, ctx, fully_loaded = FALSE) {
  out <- new_calculation_bundle()
  calculate_credit(tables, ctx, out)
  calculate_ccr_cva_settlement(tables, ctx, out)
  calculate_securitisation(tables, ctx, out)
  calculate_market(tables, ctx, out)
  calculate_operational(tables, ctx, out)
  calculate_trea(ctx, out, fully_loaded)
  calculate_capital(tables, ctx, out)
  calculate_irrbb(tables, ctx, out)
  calculate_icaap(tables, ctx, out)
  registry <- unique(as.character(tables$formula_definition$formula_id))
  used <- unique(unlist(lapply(out$results, function(frame) {
    if ("formula_id" %in% names(frame)) as.character(stats::na.omit(frame$formula_id)) else character()
  }), use.names = FALSE))
  missing <- sort(setdiff(used, registry))
  add_control(out, "FORMULA_REGISTRY", !length(missing), "no missing", paste(missing, collapse = ","),
              "Every result formula is registered and versioned")
  tolerance <- parameter_get(ctx$parameters, "CONTROL", "ABSOLUTE_TOLERANCE_EUR")
  expected_market <- out$metrics[[if (startsWith(ctx$market_regime, "LEGACY")) "K_MARKET_LEGACY" else "K_MARKET_FRTB"]]
  add_control(out, "OFFICIAL_MARKET_REGIME", abs(out$metrics$K_MARKET - expected_market) < tolerance,
              expected_market, out$metrics$K_MARKET, "Market risk matches the selected rule-set regime")
  expected_ilm <- parameter_get(ctx$parameters, "OPRISK", "EU_ILM")
  add_control(out, "EU_OPRISK_ILM", identical(as.numeric(out$results$Operational_Risk$ilm_eu[[1L]]), expected_ilm),
              expected_ilm, out$results$Operational_Risk$ilm_eu[[1L]], "EU BIC applies the configured ILM")
  equivalents_additive <- any(vapply(out$results$RWA_Equivalents$additive_to_legal_trea, rwa_bool, logical(1)))
  add_control(out, "RWA_EQUIVALENT_NO_DOUBLE_COUNT", !equivalents_additive, FALSE, equivalents_additive,
              "Pillar 2 and economic equivalents are not added to legal TREA")
  allocation <- sum_column(out$results$Floor_Allocation, "allocated_floor_uplift")
  add_control(out, "FLOOR_ALLOCATION", abs(allocation - out$metrics$FLOOR_UPLIFT) < tolerance,
              out$metrics$FLOOR_UPLIFT, allocation, "Floor allocation reconciles")
  view <- if (fully_loaded) "FULLY_LOADED" else "APPLIED"
  for (name in names(out$results)) {
    frame <- out$results[[name]]; n <- nrow(frame)
    metadata <- data.frame(
      calculation_run_id = rep(ctx$run_id, n), result_version = rep(ctx$formula_version, n),
      result_as_of_date = rep(ctx$as_of_date, n), result_knowledge_time = rep(ctx$knowledge_time, n),
      result_rule_set_id = rep(ctx$rule_set_id, n), result_view = rep(view, n),
      result_is_official = rep(!fully_loaded, n), stringsAsFactors = FALSE)
    out$results[[name]] <- cbind(metadata, frame)
  }
  out
}

execute_tables <- function(raw, run_id, project_root = NULL, initial_issues = list()) {
  issues <- c(initial_issues, validate_tables_internal(raw), validate_legal_files(raw, project_root))
  report <- new_validation_report(issues)
  if (!validation_valid(report)) abort_validation(
    sprintf("Input validation failed with %d error(s)", length(validation_errors(report))),
    messages = validation_errors(report))
  cfg <- run_configuration(raw)
  as_of <- as.Date(cfg[["as_of_date"]])
  knowledge_text <- sub("Z$", "", cfg[["knowledge_time"]])
  knowledge <- as.POSIXct(knowledge_text, format = "%Y-%m-%dT%H:%M:%OS", tz = "UTC")
  if (is.na(knowledge)) knowledge <- as.POSIXct(knowledge_text, tz = "UTC")
  if (is.na(as_of) || is.na(knowledge)) abort_calculation("Invalid as_of_date or knowledge_time in run_config")
  snapshot <- lapply(raw, select_official_as_of, as_of_date = as_of, knowledge_time = knowledge)
  snapshot <- apply_official_designations(raw, snapshot)
  params <- new_parameter_store(snapshot$regulatory_parameter)
  applied_rule <- rule_context(snapshot, cfg[["rule_set_id"]])
  context <- new_calculation_context(as_of, knowledge, cfg[["rule_set_id"]], params,
                                     applied_rule$reporting_currency, applied_rule$market_regime,
                                     applied_rule$output_floor_factor, run_id)
  applied <- run_one(snapshot, context, FALSE)
  full_rule <- rule_context(snapshot, "CRR3-EU-FL")
  full_context <- new_calculation_context(as_of, knowledge, "CRR3-EU-FL", params,
                                          full_rule$reporting_currency, full_rule$market_regime,
                                          full_rule$output_floor_factor, run_id)
  parallel <- run_one(snapshot, full_context, TRUE)
  list(applied = applied, parallel = parallel, context = context,
       full_context = full_context, report = report)
}

tables_fingerprint <- function(tables) digest::digest(tables, algo = "sha256", serialize = TRUE)

code_fingerprint <- function() digest::digest(list(
  version = engine_version(),
  functions = lapply(c(calculate_credit, calculate_market, calculate_capital,
                       calculate_irrbb, calculate_icaap), body)), algo = "sha256")

summary_frame <- function(bundle, view, metadata) {
  ordering <- c("RWEA_KSA", "RWEA_IRB", "RWEA_CRYPTO", "RWEA_CCR", "RWEA_SFT", "RWEA_CCP",
    "RWEA_SECURITISATION", "K_CVA", "K_CVA_SA", "K_SETTLEMENT", "K_LARGE_EXPOSURE", "K_MARKET",
    "K_MARKET_IMA_PARALLEL", "K_OPERATIONAL", "U_TREA", "S_TREA", "OUTPUT_FLOOR_FACTOR",
    "FLOOR_UPLIFT", "TREA", "CET1", "AT1", "T2", "TIER1", "TOTAL_OWN_FUNDS", "CET1_RATIO",
    "TIER1_RATIO", "TOTAL_CAPITAL_RATIO", "P2R_RATE", "P2R_AMOUNT", "CBR_RATE", "P2G_RATE",
    "CET1_HEADROOM", "TIER1_HEADROOM", "TOTAL_HEADROOM", "LEVERAGE_RATIO", "MREL_HEADROOM",
    "TLAC_HEADROOM", "WORST_EVE_LOSS", "EVE_SOT_RATIO", "WORST_NII_DECLINE", "NII_SOT_RATIO",
    "EVE_VAR_99", "EVE_ES_99", "EC_LINEAR", "EC_AGGREGATE", "ECONOMIC_CAPACITY",
    "ECONOMIC_HEADROOM", "NORMATIVE_MIN_HEADROOM", "P2R_RWA_EQUIVALENT", "EC_RWA_EQUIVALENT",
    "IRRBB_MANAGEMENT_CAPITAL", "IRRBB_RWA_EQUIVALENT")
  keys <- ordering[ordering %in% names(bundle$metrics)]
  rows_frame(lapply(keys, function(k) list(
    calculation_run_id = metadata$run_id, result_version = metadata$engine_version,
    as_of_date = metadata$as_of_date,
    rule_set_id = if (view == "APPLIED") metadata$rule_set_id else metadata$parallel_rule_set_id,
    is_official = view == "APPLIED", view = view, metric = k, value = bundle$metrics[[k]],
    unit = if (grepl("RATIO|RATE|FACTOR", k)) "RATE" else "EUR")))
}

lineage_frame <- function(bundle, run_id, rule_set_id) rows_frame(lapply(names(bundle$results), function(name) {
  frame <- bundle$results[[name]]
  list(calculation_run_id = run_id, result_table = name, row_count = nrow(frame),
       formula_ids = if ("formula_id" %in% names(frame)) paste(sort(unique(as.character(stats::na.omit(frame$formula_id)))), collapse = ",") else "",
       rule_set_id = rule_set_id, source = "canonical_official_snapshot")
}))

write_outputs <- function(output_dir, execution, metadata) {
  bundle <- execution$applied; parallel <- execution$parallel; report <- execution$report
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE); files <- character()
  summary <- rbind(summary_frame(bundle, "APPLIED", metadata), summary_frame(parallel, "FULLY_LOADED", metadata))
  executive <- data.frame(
    official_status = if (validation_valid(report) && all(vapply(bundle$controls, function(x) isTRUE(x$passed), logical(1)))) "APPROVED" else "REVIEW",
    as_of_date = metadata$as_of_date, trea = bundle$metrics$TREA,
    floor_binding = bundle$metrics$FLOOR_BINDING, cet1_ratio = bundle$metrics$CET1_RATIO,
    total_capital_ratio = bundle$metrics$TOTAL_CAPITAL_RATIO, leverage_ratio = bundle$metrics$LEVERAGE_RATIO,
    eve_sot_ratio = bundle$metrics$EVE_SOT_RATIO, nii_sot_ratio = bundle$metrics$NII_SOT_RATIO,
    economic_headroom = bundle$metrics$ECONOMIC_HEADROOM)
  prefix <- paste0("RWA_OUT_", metadata$as_of_date, "_", metadata$run_id, "_")
  p <- file.path(output_dir, paste0(prefix, "00_Summary.xlsx"))
  files <- c(files, write_result_workbook(p, list(Executive_Summary = executive, Metrics = summary,
    Applied_TREA = bundle$results$TREA_Summary, Fully_Loaded_TREA = parallel$results$TREA_Summary), metadata))
  pillar_names <- intersect(names(bundle$results), c("SA_Detail", "IRB_Detail", "Crypto_Detail", "CCR_Detail",
    "SFT_Detail", "CCP_Detail", "CVA_Summary", "CVA_Buckets", "Settlement_Detail", "Large_Exposure",
    "SEC_Detail", "Market_Legacy", "FRTB_Buckets", "FRTB_Risk_Classes", "FRTB_DRC", "FRTB_Summary",
    "FRTB_IMA", "Operational_Risk", "TREA_Summary", "Floor_Allocation"))
  p <- file.path(output_dir, paste0(prefix, "01_Pillar1.xlsx")); files <- c(files, write_result_workbook(p, bundle$results[pillar_names], metadata))
  capital_names <- c("Prudent_Valuation", "NPE_Backstop", "Capital_Stack", "Parallel_Constraints", "RWA_Equivalents")
  p <- file.path(output_dir, paste0(prefix, "02_Capital.xlsx")); files <- c(files, write_result_workbook(p, bundle$results[capital_names], metadata))
  irrbb_names <- c("IRRBB_Repricing_Gap", "IRRBB_NII_Bands", "IRRBB_Currency_Scenarios", "IRRBB_Scenarios", "IRRBB_Risk_Measures")
  p <- file.path(output_dir, paste0(prefix, "03_IRRBB.xlsx")); files <- c(files, write_result_workbook(p, bundle$results[irrbb_names], metadata))
  icaap_names <- c("EC_Standalone", "EC_Aggregation", "Normative_Projection", "Pillar2_Bridge")
  p <- file.path(output_dir, paste0(prefix, "04_ICAAP.xlsx")); files <- c(files, write_result_workbook(p, bundle$results[icaap_names], metadata))
  controls <- rows_frame(bundle$controls)
  lineage <- rbind(lineage_frame(bundle, metadata$run_id, metadata$rule_set_id),
                   lineage_frame(parallel, metadata$run_id, metadata$parallel_rule_set_id))
  p <- file.path(output_dir, paste0(prefix, "05_Audit.xlsx")); files <- c(files, write_result_workbook(p,
    list(Validation_Issues = as.data.frame(report), Reconciliations = controls, Lineage = lineage), metadata))
  files
}
