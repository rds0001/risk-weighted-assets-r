# riskweightedassets 1.2.2

* Fixed inconsistent default_flag parsing between Standardised Approach and IRB.
  Accepted representations are normalised once and shared by SA, IRB, KSA and
  output-floor calculations; missing or ambiguous flags now fail closed.
* Added SA_Detail.defaulted, shared Python/R vectors, and public portfolio tests.
* Existing 1.2.1 default LGD-treatment contract and reference parameters retained.

# riskweightedassets 1.2.1

* Corrected supervisory-LGD FIRB defaults: K/RW/RWEA = 0; EL = LGD * EAD.
* Unified default/PD handling; retained original PD and resolved LGD treatment.
* Default formula calls require explicit lgd_treatment. Unsupported combinations
  fail closed, including slotting (no separate implementation).
* Added public-API default/capital regressions and documented API migration.

# riskweightedassets 1.2.0

* Added four documented public supporting-factor functions (77 exports).
* Applied verified SME/infrastructure factors to IRB RWEA without changing K or EL.
* Added compatible optional Excel fields, traceable evidence and floor-path diagnostics.
* Preserved legacy SA factors with explicit unverified-eligibility warnings.
* Added boundary, eligibility, regression and output-floor tests.

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
