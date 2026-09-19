# Public R API

The public surface is deliberately granular and designed from the perspective
of a bank analyst. It exposes 77 documented functions covering controlled
workflows, individual formulae, domain views, parameters, schemas, metrics,
tables and controls. Mutable orchestration internals remain private.

## Calculation

- `calculate_tables(tables, run_id = NULL, project_root = NULL, ...)` validates and
  calculates an in-memory named list of 68 canonical data frames. It returns an
  `rwa_calculation_result` and performs no spreadsheet writes.
- `validate_dataset(dataset)` reads the 16 canonical input workbooks and returns
  an `rwa_validation_report` without calculating or writing results.
- `calculate_dataset(dataset)` validates, selects the official snapshot,
  calculates applied and fully-loaded views, and persists six result workbooks
  plus `run_manifest.json` under an immutable run directory.

## Synthetic data

- `generate_synthetic_tables()` returns a complete in-memory profile.
- `generate_synthetic_dataset()` writes a complete canonical Excel dataset to
  a caller-selected directory.
- `list_reference_profiles()` and `list_reference_datasets()` return bundled
  inventory metadata.

## Workspace and sources

- `create_workspace(path, overwrite = FALSE)` creates a controlled writable
  tree and materialises both synthetic profiles.
- `default_workspace()` resolves `RWA_WORKSPACE` or a local default without
  writing anything.
- `regulatory_sources()` returns official links and checksums, never document
  bodies.

## Analyst-level access and control

- 38 formula functions cover SA, IRB, CRM, CCR, SFT, securitisation, CVA,
  settlement, operational risk, output floor, NPE, Tier 2, FRTB, IRRBB and
  correlated economic capital.
- Nine `analyze_*()` functions return focused metrics, result tables and
  controls from canonical tables or an existing result.
- `rwa_metric()`, `rwa_metrics()`, `rwa_result_table()`, `rwa_controls()` and
  `compare_calculation_views()` provide stable result access.
- `regulatory_parameters()`, `regulatory_parameter()` and
  `override_regulatory_parameters()` expose every weight and allow explicit,
  non-mutating, audited sensitivity changes.
- Formula catalogue, rule sets, schemas and the bitemporal official snapshot
  are public without requiring `:::`.

See [ANALYST_API.md](ANALYST_API.md) for the complete map. Every export has
native R help generated from roxygen2.

## Returned classes

`rwa_validation_report` contains a list of structured messages. Convert it with
`as.data.frame()` to obtain `severity`, `code`, `table`, `row_ref`, `field` and
`message` columns.

`rwa_calculation_result` contains status, deterministic run identifier, engine
and rule-set versions, 63 applied and 63 fully-loaded headline metrics,
applied and parallel controls, validation messages, 34 applied and 34 parallel
result tables, parameter-override evidence and optional output paths.

`rwa_workspace` contains `root`, `data_root`, `runs_root`,
`configuration_root` and `standards_root` paths.

## Error contract

Errors inherit from `rwa_error` and one specific class:

- `rwa_configuration_error` for missing or inconsistent configuration;
- `rwa_parameter_error` for absent or duplicate regulatory parameters;
- `rwa_resource_error` for missing packaged resources or unsafe destinations;
- `rwa_validation_error` for invalid canonical input;
- `rwa_calculation_error` for failures during the controlled calculation.

Use `tryCatch(..., rwa_validation_error = function(e) ...)` when integrating
with production orchestration.

## In-memory example

```r
tables <- riskweightedassets::generate_synthetic_tables(
  bank_profile = "MID_SIZE_UNIVERSAL"
)
result <- riskweightedassets::calculate_tables(tables)
stopifnot(result$status == "CALCULATED")
metrics <- unlist(result$metrics[c("TREA", "CET1_RATIO")])
```

Native manpages for every public function are installed with the package.

## Credit supporting factors (1.2.0)

Four new public functions cover SME, infrastructure, combined support and complete IRB RWEA.
See [supporting-factor documentation](SUPPORTING_FACTORS.md) for inputs, eligibility, compatibility and audit output.
