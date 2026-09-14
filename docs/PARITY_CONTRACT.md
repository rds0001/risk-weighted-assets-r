# Python-to-R parity contract

The R package is a native port of Python package version 1.0.0, not a wrapper.

## Semantic mapping

| Python | R |
|---|---|
| `dict[str, DataFrame]` | named `list` of `data.frame` |
| `CalculationResult` | S3 `rwa_calculation_result` |
| `ValidationReport` | S3 `rwa_validation_report` |
| `Workspace` | S3 `rwa_workspace` |
| typed exceptions | `rwa_error` condition subclasses |
| `date` / UTC `datetime` | `Date` / UTC `POSIXct` |

## Rules

- Missing spreadsheet cells map to `NA`; empty parameter dimensions are
  canonical empty strings.
- Table and result order is deterministic. Grouped output uses stable sorted
  business identifiers where order is semantically observable.
- No intermediate monetary rounding is allowed.
- Dates use the Excel 1899-12-30 origin and end-exclusive history intervals.
- Official designation overlay, applied and fully-loaded semantics are equal.
- All 68 inputs, 34 result tables, 63 metrics and formula IDs are classified.
- The canonical stochastic path is shared; arbitrary non-reference seeds are
  deterministic within each language but are not asserted bit-identical.

## Numerical acceptance

For every canonical headline metric `x`, the absolute deviation must be no more
than `max(1e-5, abs(x) * 1e-12)`. This admits unavoidable order-of-operation
differences far below one cent while rejecting business-significant drift.
Boolean, identifier, count, status and formula fields require exact equality.

The end-to-end test contains all Python 1.0.0 metric values for both
`MID_SIZE_UNIVERSAL` and `KSA_BANK`; an added or removed metric fails the test.
