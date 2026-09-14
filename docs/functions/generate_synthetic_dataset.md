# `generate_synthetic_dataset()`

Writes one complete synthetic profile as the 16-workbook canonical contract.

```r
path <- generate_synthetic_dataset(
  root = file.path(tempdir(), "runs"),
  version = "v1.0.0",
  bank_profile = "KSA_BANK"
)
```

The returned path is `<root>/<as-of>/<version>`. Existing non-empty targets are
rejected unless `overwrite = TRUE`. A dataset manifest records profile, seed,
workbook checksums and table row counts.
