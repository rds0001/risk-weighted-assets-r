# `calculate_dataset()`

Runs the persisted canonical Excel workflow.

```r
calculate_dataset(dataset)
```

`dataset` contains an `inputs` directory with 16 canonical workbooks. The
function validates all inputs, computes the official and fully-loaded views and
writes six result workbooks plus `run_manifest.json` below
`outputs/<run-id>/`. The run ID is derived from input, code and package-version
fingerprints. The returned `rwa_calculation_result` also exposes all results in
memory. The caller must ensure the destination is writable.
