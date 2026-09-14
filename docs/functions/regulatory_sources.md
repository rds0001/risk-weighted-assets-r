# `regulatory_sources()`

Returns the machine-readable external-source inventory.

```r
sources <- regulatory_sources()
stopifnot(all(!sources$redistributed))
```

The data frame contains official URLs and archival SHA-256 values. It does not
contain or download regulations, PDFs or webpages. Users must independently
obtain and assess current official material.
