# riskweightedassets 1.1.0

* Expanded the public API from 10 to 73 documented exports, designed around
  concrete bank-analyst questions rather than a single coarse workflow.
* Added 34 granular formula functions for credit, IRB, CRM, CCR, SFT, CVA,
  securitisation, settlement, operational risk, output floor, NPE, Tier 2,
  FRTB, IRRBB and economic-capital aggregation.
* Added nine domain-analysis functions and public metric, result-table,
  control, validation, parameter, formula, schema and snapshot accessors.
* Added explicit non-mutating regulatory-parameter overrides with mandatory
  rationale, approval reference and old/new-value audit trail.
* Preserved both applied and fully-loaded metrics and controls in calculation
  results for direct comparison.

# riskweightedassets 1.0.0

* Added the complete native R migration of the Python 1.0.0 RWA engine.
* Added SA and IRB credit, CRM, CCR, SFT, CCP, CVA, securitisation, settlement,
  large-exposure, market, operational-risk and output-floor calculations.
* Added own funds, prudential constraints, leverage, MREL/TLAC, IRRBB/CSRBB and
  economic/normative ICAAP calculations.
* Added 68 canonical tables, 16-workbook input and six-workbook output flows,
  bitemporal snapshots, strict validation, lineage and reconciliation controls.
* Added two complete synthetic profiles and all-metric Python golden parity.
* Added function, vignette, methodology, governance, legal and CRAN release
  documentation.
