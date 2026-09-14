# `create_workspace()`

Creates a self-contained writable workspace at a caller-selected path.

```r
workspace <- create_workspace(path, overwrite = FALSE)
```

The workspace contains configuration, source metadata and both synthetic
reference datasets. Installed package files are never modified. A non-empty
destination is rejected unless overwrite is explicitly enabled. The return is
an `rwa_workspace` containing the key absolute paths.
