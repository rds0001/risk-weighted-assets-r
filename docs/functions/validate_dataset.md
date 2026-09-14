# `validate_dataset()`

Validates a canonical workbook dataset without calculation or output writes.

```r
report <- validate_dataset(dataset)
as.data.frame(report)
```

The `rwa_validation_report` contains structured severity, code, table, row,
field and message values. An empty data frame means the supplied dataset has no
detected contract issues. Validation success does not establish regulatory
appropriateness or production data quality.
