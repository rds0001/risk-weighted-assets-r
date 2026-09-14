# Public R API

The public surface is deliberately small. Calculation details remain internal
so that validation, temporal selection, formula versioning and controls cannot
be bypassed accidentally.

## Calculation

- `calculate_tables(tables, run_id = NULL, project_root = NULL)` validates and
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

## Returned classes

`rwa_validation_report` contains a list of structured messages. Convert it with
`as.data.frame()` to obtain `severity`, `code`, `table`, `row_ref`, `field` and
`message` columns.

`rwa_calculation_result` contains status, deterministic run identifier, engine
and rule-set versions, 63 headline metrics, 12 controls, validation messages,
34 applied result tables, 34 parallel result tables and optional output paths.

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

Detailed pages for every public function are in [`functions/`](functions/).
