# `generate_synthetic_tables()`

Materialises a complete synthetic profile as native R data frames.

```r
tables <- generate_synthetic_tables(
  as_of = as.Date("2026-08-31"),
  seed = 5752026L,
  bank_profile = "MID_SIZE_UNIVERSAL"
)
```

`bank_profile` is `MID_SIZE_UNIVERSAL` or `KSA_BANK`. Dates are shifted from the
immutable base profile, parameters and formula definitions are materialised
from YAML, and the lineage seed is recorded. The return is a named list of 68
data frames. No files are written and no customer data is included.
