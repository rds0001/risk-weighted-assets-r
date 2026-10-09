# Snapshot timestamps — 1.2.3

The public `official_snapshot()` helper previously parsed an ISO knowledge-time
string without an explicit format. Under affected R versions this truncated
`2026-08-31T23:59:59` to midnight and could omit same-day records.
The KSA reference case selected zero instead of 30 business-indicator rows.

The helper and `calculate_tables()` now share one internal UTC parser.
Accepted inputs are POSIXt instants, UTC strings with T or space separators,
optional fractional seconds and optional trailing Z, and date-only values
(midnight UTC). Missing, malformed and non-scalar values raise a structured
configuration error. Function signatures, dependencies and source data are unchanged.

Regression tests compare the implicit run_config snapshot with an explicit
23:59:59 UTC snapshot, retain all 30 expected rows, verify midnight selection,
exercise the supported timestamp formats and reject invalid values.
Caller-owned tables are unchanged.
