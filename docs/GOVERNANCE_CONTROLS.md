# Governance, controls and acceptance

## Validation layers

Validation runs before temporal selection or calculation. It checks workbook
and sheet presence, Excel table names, mandatory values, unique record IDs,
version types, valid/known intervals, selected foreign keys, bounded rates,
parameter uniqueness, run configuration, tranche bounds and curvature inputs.
Messages contain severity, stable code, table, row reference, field and text.
Any `ERROR` prevents calculation; warnings remain visible in the audit output.

## Calculation controls

The applied run contains 12 controls for the supplied profiles:

1. SA credit reconciliation;
2. total TREA reconciliation;
3. EAD non-negativity;
4. capital stack reconciliation;
5. ICAAP correlation symmetry;
6. ICAAP correlation positive-semidefiniteness;
7. behavioural-assumption weights by segment/type;
8. complete formula registry;
9. selected official market regime;
10. configured EU operational-risk ILM;
11. no double counting of management RWA equivalents;
12. output-floor allocation reconciliation.

The exact number can grow if additional behavioural segments are supplied.
`calculation_successful()` internally requires status `CALCULATED`, no
validation errors, and every control passed.

## Lineage

Each persisted result records run ID, engine version, as-of date, knowledge
time, rule set, applied/fully-loaded view and official flag. The manifest adds
input, code and calculation fingerprints. Audit workbook lineage records the
row count and formula IDs for every output table.

## Acceptance gates

A release candidate is acceptable only when:

- roxygen-generated files are current;
- all unit, invariant, contract, workbook and golden-master tests pass;
- both bank profiles match every Python 1.0.0 headline metric within the
  documented floating-point tolerance;
- `devtools::test()` and `devtools::check()` pass in a current clean R setup;
- `R CMD build` succeeds and the built tarball passes `R CMD check --as-cran`;
- Linux, Windows and macOS GitHub Actions are green;
- Win-builder and R-hub release/oldrel/devel checks have no unexplained issue;
- source tarball contents, file sizes, licenses and external-source boundary
  have been reviewed;
- CRAN's natural-person maintainer field has been supplied and confirmed.

## Operational use

Institutions must independently validate law, mappings, permissions, source
systems, parameter versions, overrides and reconciliations. Synthetic profile
success demonstrates implementation integrity, not fitness for a particular
bank. Production use requires change governance, segregation of duties,
access control, backups, incident handling and supervisory sign-off outside
this package.
