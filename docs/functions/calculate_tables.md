# `calculate_tables()`

Calculates a complete canonical dataset held in memory.

```r
calculate_tables(tables, run_id = NULL, project_root = NULL)
```

`tables` must be a named list of canonical data frames, normally created by
`generate_synthetic_tables()` or an institution-specific adapter. `run_id` is
optional; when absent it is derived deterministically. `project_root` resolves
caller-owned local regulatory source files.

The return value is an `rwa_calculation_result` with applied metrics, controls,
validation, 34 applied tables and 34 fully-loaded parallel tables. The function
does not write output files. Invalid inputs raise `rwa_validation_error`.
