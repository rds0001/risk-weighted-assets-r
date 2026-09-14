# Canonical data model and history

## Contract

The canonical model contains 68 named tables distributed across 16 input
workbooks. Each sheet contains exactly one Excel table named `tbl_in_<name>`.
Table and column names are stable integration identifiers. The complete list is
available as `names(generate_synthetic_tables())`.

Every historised table starts with:

| Column | Meaning |
|---|---|
| `record_id` | Unique immutable record-version identifier |
| `business_key` | Stable business identity across versions |
| `version_no` | Monotone version number |
| `as_of_date` | Reporting snapshot date |
| `valid_from`, `valid_to` | Business-valid interval, end exclusive |
| `known_from`, `known_to` | Knowledge interval, end exclusive |
| `is_official` | Eligibility for the official calculation |
| `record_status` | Active, cancelled or superseded state |

## Principal domains

- governance: run configuration, rule sets, official designations, scope and
  approach permissions;
- counterparties and mappings: parties, groups, assessments, ratings,
  products and accounts;
- credit: contracts, facilities, exposure lots, SA classifications, property,
  IRB parameters, collateral and guarantees;
- counterparty and market: netting, derivatives, SFT, CCP, CVA, settlement,
  large exposures, trading positions, sensitivities and FRTB inputs;
- securitisation and operational risk;
- own funds, adjustments, capital requirements and prudential constraints;
- IRRBB/CSRBB cash flows, curves, behavioural assumptions and scenarios;
- ICAAP taxonomy, materiality, economic capital, correlations, capacity and
  normative projections;
- governance metadata: models, formula definitions, legal sources and
  regulatory parameters.

## Snapshot selection

A record is selected only if it is official, valid at the configured
`as_of_date`, known at `knowledge_time`, and neither cancelled nor superseded.
For each `business_key`, the latest eligible version is retained. Explicit
official designations can then replace the selected record with an approved
record version. Both applied and fully-loaded calculations use this same
snapshot.

## Missing values and types

Empty Excel cells become typed `NA`. Excel serial dates and datetimes are
normalised to `Date` and UTC `POSIXct`. Boolean values accept actual logicals
and controlled textual/numeric encodings; business formulas never rely on R's
implicit truth coercion. Monetary values remain unrounded binary doubles during
calculation; rounding belongs only to presentation.

## Spreadsheet output

The persisted run contains six workbooks: summary, Pillar 1, capital, IRRBB,
ICAAP and audit. Each result table adds calculation run, formula version,
snapshot, rule set, view and official-status columns. The JSON manifest records
input, code and calculation fingerprints and checksums the run context.

## Data ownership

All bundled portfolios and names are synthetic. The package does not contain
customer data. The canonical schema may be populated by an institution only
after its own data ownership, quality, reconciliation and access controls have
been established.
