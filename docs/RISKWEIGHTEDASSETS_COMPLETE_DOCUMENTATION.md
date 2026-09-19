# riskweightedassets — complete documentation

Version 1.2.0 documentation
Copyright © 2026 RiskDataScience GmbH  
License: GNU General Public License version 3

## 1. Purpose and status

`riskweightedassets` is an independently installable, native R implementation
of the RiskDataScience risk-weighted-assets reference engine. It calculates
CRR-oriented Pillar 1 exposure amounts, own-funds and prudential constraints,
IRRBB/CSRBB and ICAAP views from a governed canonical data model. It includes
realistic synthetic bank data and does not require Python at runtime.

The package supports research, education, prototyping and independent model
validation. It is not a certified reporting solution and does not replace
legal assessment, permissions, institution-specific mapping, model validation
or supervisory approval.

## 2. Installation

R 4.1 or newer is required. Install a built source package with:

```r
install.packages("riskweightedassets_1.2.0.tar.gz", repos = NULL, type = "source")
library(riskweightedassets)
```

After CRAN acceptance use `install.packages("riskweightedassets")`.

Runtime dependencies are `digest`, `jsonlite`, `openxlsx`, `readxl`, `utils` and `yaml`. They are
ordinary CRAN packages. Python, NumPy and downloaded regulatory material are
not runtime dependencies.

## 3. Quick start

An in-memory reference calculation has no output side effects:

```r
tables <- generate_synthetic_tables(bank_profile = "MID_SIZE_UNIVERSAL")
result <- calculate_tables(tables)
print(result)
unlist(result$metrics[c("RWEA_KSA", "RWEA_IRB", "TREA", "CET1_RATIO")])
```

The equivalent spreadsheet workflow is:

```r
dataset <- generate_synthetic_dataset(
  root = file.path(tempdir(), "rwa-runs"),
  as_of = as.Date("2026-08-31"),
  version = "v1.0.0",
  bank_profile = "KSA_BANK"
)
report <- validate_dataset(dataset)
result <- calculate_dataset(dataset)
```

## 4. Public API

The package exports 77 documented functions. The controlled lifecycle remains:

- `calculate_tables()` calculates a named list of 68 canonical data frames and
  returns applied and fully-loaded results without writing files.
- `validate_dataset()` validates 16 canonical input workbooks without a run.
- `calculate_dataset()` performs the complete controlled spreadsheet run and
  writes six output workbooks and a JSON manifest.
- `generate_synthetic_tables()` materialises either reference profile in R.
- `generate_synthetic_dataset()` materialises a profile as canonical XLSX.
- `create_workspace()` creates a writable self-contained reference workspace.
- `default_workspace()` resolves the environment-configured default without
  writing it.
- `list_reference_profiles()` and `list_reference_datasets()` expose inventory.
- `regulatory_sources()` exposes official URLs and archival source hashes.

The bank-analyst layer additionally exposes 38 individual regulatory and risk
formula functions, nine domain-analysis functions, applied/fully-loaded metric
and control accessors, result-table accessors, the formula and rule-set
catalogues, canonical schemas and bitemporal snapshots. Regulatory parameters
are inspectable and may be overridden non-destructively only with a reason and
approval reference; the result preserves the old/new-value audit trail. A
structurally changed formula remains a versioned code and test change rather
than an ungoverned runtime expression. The complete inventory is in
`docs/ANALYST_API.md`.

The principal S3 result class is `rwa_calculation_result`. Its fields are
`status`, `run_id`, `engine_version`, `rule_set_id`, `metrics`, `controls`,
`validation`, `output_dir`, `output_files`, `results`, `parallel_results`,
`parallel_metrics`, `parallel_controls` and `parameter_overrides`.
`rwa_validation_report` converts to a six-column data frame. The condition
hierarchy distinguishes configuration, parameter, resource, validation and
calculation errors.

## 5. Data contract

The canonical model contains 68 tables across 16 input workbooks. Each data
sheet has one Excel table named `tbl_in_<logical-name>`. Schema identifiers are
stable and case-sensitive.

All historised tables begin with `record_id`, `business_key`, `version_no`,
`as_of_date`, `valid_from`, `valid_to`, `known_from`, `known_to`, `is_official`
and `record_status`. Business validity and knowledge validity are end-exclusive.
An official snapshot retains the most recent eligible record version per
business key. An approved official designation can identify a specific record
version explicitly.

The domains cover run governance, entities and consolidation, parties and
ratings, contracts/facilities/exposures, SA and IRB credit, collateral and
guarantees, derivatives and SFT, CCP/CVA, securitisation, market risk,
operational risk, own funds, IRRBB cash flows and curves, ICAAP, model/formula
registry, mappings, parameters and legal-source lineage.

Dates are represented as `Date`, knowledge timestamps as UTC `POSIXct`, and
monetary/rate values as double. Missing Excel cells become typed `NA`. Boolean
decoding is explicit; the canonical fixture regression test specifically guards
against spreadsheet readers treating OOXML false (`0`) as true.

## 6. Validation

Validation precedes all calculation. It covers expected files, worksheets and
Excel table names; required values; record uniqueness; interval logic; selected
foreign keys; numeric bounds; parameter uniqueness; run configuration; tranche
bounds; and curvature revaluation completeness.

Each issue has severity, stable code, table, row reference, field and message.
Errors prevent calculation. Warnings are retained in the audit result. This
technical validation is necessary but does not establish the completeness or
correctness of a real bank's source data.

## 7. Calculation architecture

Configuration and regulatory values are loaded first. The contract layer
normalises and validates inputs and creates one official bitemporal snapshot.
The same snapshot is calculated under the applied 2026 rule set and a parallel
fully-loaded rule set. Engines add result tables and metrics to a controlled
bundle. Reconciliations and formula-registry checks run before output metadata
is added.

Pure formula functions are separated from portfolio orchestration. Excel I/O
is a boundary layer, not a business-logic dependency. Package resources are
immutable. Only destinations explicitly selected by the caller are writable.

## 8. Pillar 1 methodology

### 8.1 Standardised credit risk

SA EAD separates on-balance-sheet and off-balance-sheet amounts. Off-balance
amounts use annex-class conversion factors. Exposure class, credit quality,
default, short-term, retail, transactor, specialised-lending, currency and
real-estate attributes select the regulatory risk weight. Real-estate logic
uses property type, IPRE/ADC/completion status, value, liens and ETV. CRM applies
exposure/collateral haircuts, maturity adjustment, FX haircut and funded or
unfunded protection. Supporting factors are applied only after eligibility.

### 8.2 IRB credit risk

Corporate and retail functions apply PD/LGD floors, asset correlations,
confidence quantile, maturity treatment, default handling and financial-sector
multipliers. EAD times unexpected-loss capital times the Pillar 1 multiplier
produces RWEA. Expected loss reconciles with eligible provisions. The engine
also calculates every exposure under SA for output-floor purposes.

### 8.3 Counterparty, CVA and related risks

SA-CCR calculates replacement cost, PFE multiplier, supervisory add-ons and
netting-set EAD. SFT uses a comprehensive exposure/collateral method. CCP
trade/default-fund calculations remain distinct. BA-CVA is official where
configured and SA-CVA is a parallel sensitivity-based view. Settlement-delay
and large-exposure excess charges are calculated separately.

### 8.4 Securitisation

The approach hierarchy selects SEC-IRBA, SEC-SA or SEC-ERBA based on available
inputs and eligibility. SSFA methods use pool capital, delinquency, tranche
attachment/detachment and supervisory parameters. ERBA uses rating, maturity,
seniority and STS. Regulatory floors and caps are enforced.

### 8.5 Market and operational risk

The applied rule set reports the configured legacy market-risk requirement and
produces FRTB SA/IMA parallel views. FRTB SA combines SBM delta/vega/curvature,
DRC and RRAO under correlation scenarios. The fully-loaded rule set explicitly
selects FRTB. Operational risk derives BI components from three-year accounting
measures, applies marginal coefficients and the configured EU ILM.

### 8.6 TREA and output floor

Unfloored TREA aggregates credit RWEA and equivalents of the included capital
requirements. Shadow TREA uses full SA credit. The applicable transitional or
fully-loaded factor floors the result. Floor uplift is allocated to components
and reconciled. Pillar 2 and economic-management equivalents are prohibited
from being double counted in legal TREA.

## 9. Capital and prudential constraints

Own funds combine eligible CET1, AT1 and T2 instruments/components and apply
deductions, prudent valuation, NPE backstop and IRB shortfall/excess. Capital
ratios and headroom distinguish minimums, Pillar 2 requirement, combined buffer
and Pillar 2 guidance. Leverage, MREL and TLAC use their own denominators and
eligibility rules. Management equivalents remain transparent bridge views.

## 10. IRRBB, CSRBB and ICAAP

IRRBB assigns contractual and behavioural cash flows to repricing bands,
interpolates currency curves and applies six versioned shock shapes. It reports
currency and aggregate EVE/NII impacts, worst losses and outlier ratios. CSRBB
is a separate stress loss. The stochastic EVE approximation reports 99% VaR
and expected shortfall from 5,000 versioned rate shocks. The canonical path is
shared with Python 1.0.0 for cross-language parity and does not alter the user's
global R random state.

ICAAP calculates standalone economic capital after provisions, model risk and
non-diversifiable add-ons. A validated correlation matrix aggregates
diversifiable capital, subject to a diversification cap. Economic capacity
applies eligibility, haircut and reserve policy. Normative projections roll
CET1, TREA and leverage exposure through scenarios and expose minimum headroom.

## 11. Controls and auditability

Reference runs pass controls for SA and TREA reconciliation, non-negative EAD,
capital-stack reconciliation, correlation symmetry/PSD, behavioural weights,
formula registration, official market regime, EU ILM, non-double-counting and
floor allocation. Each result row carries run, version, date, rule-set, view
and official-status metadata. The manifest fingerprints inputs, code and run
context. The audit workbook retains validation, reconciliations and lineage.

## 12. Synthetic profiles

`MID_SIZE_UNIVERSAL` covers the complete mixed SA/IRB and complex-product
engine. Its reference SA RWEA is EUR 5,401,278,717.59, IRB RWEA is EUR
901,108,184.57 and TREA is EUR 8,691,246,387.71.

`KSA_BANK` applies declarative transformations to create an SA-only institution
while retaining capital, IRRBB and ICAAP. Its reference SA RWEA is EUR
9,752,217,943.87 and TREA is EUR 11,040,467,943.87.

These values are regression fixtures, not industry benchmarks. Both profiles
contain only synthetic names, contracts and exposures.

## 13. Testing and parity

Tests cover formulas, invariants, parameter strictness, classes, resources,
schema and boolean integrity, date shifting, profile transformation, workbook
round trips and both complete calculations. All 63 metrics and 34 result tables
are classified. Numerical parity uses absolute tolerance
`max(1e-5, abs(expected) * 1e-12)`; discrete values must be exact.

Release checks are:

```r
roxygen2::roxygenise()
devtools::test()
devtools::check()
```

```sh
R CMD build .
R CMD check --as-cran riskweightedassets_1.2.0.tar.gz
```

Linux, Windows and macOS CI plus Win-builder and R-hub release/oldrel/devel
checks are required before CRAN submission.

## 14. Regulatory sources and intellectual property

`regulatory_sources()` lists official source URLs and archival checksums. No
downloaded regulation, guideline, PDF, webpage or third-party standard is
included in the source repository or package. Users must retrieve and evaluate
current official texts independently.

Original code, synthetic data and documentation are GPL-3. External materials
remain subject to their own rights. The package performs no telemetry and no
automatic source download.

## 15. Limitations and production adoption

The package does not supply institution-specific source-system adapters,
regulatory permissions, national-option decisions, model approvals, access
control, operational scheduling, backups, sign-off workflow or report filing.
A bank adopting it must independently govern all of those controls, reconcile
input and output to authoritative systems, validate every material model and
maintain legal/configuration updates.

## 16. Legal contacts

- Imprint: <https://riskdatascience.net/impressum/>
- Privacy policy: <https://riskdatascience.net/datenschutzerklaerung/>
- Issues: <https://github.com/rds0001/risk-weighted-assets-r/issues>

This software is supplied without warranty and does not constitute legal,
supervisory, accounting, tax or investment advice.

## Credit supporting factors (1.2.0)

Four new public functions cover SME, infrastructure, combined support and complete IRB RWEA.

### Detailed supporting-factor reference

Copyright (C) 2026 RiskDataScience GmbH. GPL-3.0-only.

### Scope and calculation

The SA and IRB paths can apply Article 501 SME and Article 501a infrastructure
support separately or together. IRB calculation is:

`RWEA_before = EAD * RWA_MULTIPLIER[PILLAR1] * K`
`RWEA_after = RWEA_before * SME_factor * infrastructure_factor`

K, PD, LGD, EAD, expected loss, shortfall and excess are not reduced by this step.
The pre-existing SME correlation adjustment is a different mechanism.

The SME helper uses the weighted Article 501 formula: the first EUR 2.5 million
of E* at 0.7619 and the remainder at 0.85, divided by E*. E* must be positive
and determined under the Article's institution-group/connected-client rules,
including residential collateral exclusions and the fallback when the initially
calculated amount is zero. Do not substitute individual EAD or annual turnover.
Infrastructure support is 0.75 by default. Both factors can apply together.

Values are in the versioned SUPPORTING_FACTOR parameter rows:
SME_THRESHOLD_EUR, SME_LOWER, SME_UPPER, SME_SALES_MAX_EUR, INFRASTRUCTURE.
Use existing controlled parameter overrides for sensitivities; do not edit code.
An older dataset needs these explicit parameter rows only if claiming new support.
They are materialized automatically when generating a new dataset.

### Public formula functions

- `sme_supporting_factor(total_amount_owed_eur, parameters=...)`: weighted factor.
- `infrastructure_supporting_factor(parameters=...)`: configured infrastructure rate.
- `apply_credit_supporting_factors(rwea, sme_factor=1, infrastructure_factor=1)`:
  applies both components once.
- `irb_risk_weighted_assets(ead, capital_requirement, ..., parameters=...)`:
  complete RWA amount from unadjusted K.

Python uses keyword-only optional arguments. R allows named arguments.
These are numeric building blocks, NOT eligibility certificates. Amounts supplied
to the SME helper are EUR. Other pure amount calculations preserve the input unit.

### Input contract and eligibility

Optional additive fields on both `sa_classification` and `irb_parameter`:

| Field | Meaning |
|---|---|
| sme_supporting_eligible | Explicit attestation that ALL applicable Article 501 conditions hold |
| infrastructure_supporting_eligible | Explicit attestation that ALL applicable Article 501a conditions hold |
| sme_total_amount_owed_eur | Reviewed E* in EUR; required when SME support is requested |
| supporting_factor_reference | Non-empty bank-owned evidence/checklist reference |
| supporting_factor_approved_by | Non-empty governance approval reference |

`irb_parameter` additionally accepts `supporting_factor_type` and
`supporting_factor`, already present in the SA input contract.
The type can be NONE (derive from flags), SME, INFRASTRUCTURE or SME_INFRASTRUCTURE.
Leave the numeric factor blank to derive it. If supplied, it must match the
calculated product; it is not an unrestricted discount override.

The engine rejects defaulted exposures, invalid/missing numeric values and
unsupported classes for requested relief. SME support excludes ADC and checks
available turnover against the configured SME ceiling. Infrastructure support
requires an eligible corporate class. Context is checked again against the
selected exposure snapshot, including party and real-estate data.

A flag attests all remaining qualitative criteria, including the applicable
environmental conditions for newer infrastructure lending. The engine cannot
verify bank contracts or external legal evidence. Approval text is an audit
reference, not an authentication/authorization system. Institutions remain
responsible for independent eligibility review and their own access controls.

SA comparison and IRB inputs are independent: never silently copy a supplied SA
factor to IRB. Populate both eligible paths explicitly when both qualify.

### Compatibility and audit output

Old Excel workbooks remain readable: only the new columns are filled if absent.
Old IRB inputs receive no reduction. Invalid explicitly supplied values are not
silently replaced. Historical SA factors without new eligibility data retain
their old arithmetic, with status LEGACY_SA_UNVERIFIED and a validation WARNING
LEGACY_SA_SUPPORTING_FACTOR. This preserves reference results without claiming
that historical eligibility has been established. Do not use this compatibility
path as a substitute for reviewing new production eligibility.

SA_Detail and IRB_Detail expose the overall factor, component factors, type,
status, evidence and approver, support formula ID, pre-support RWEA and relief.
Legacy SA factors are not decomposed into falsely certified component factors.
IRB's existing rw remains pre-support; effective_rw includes the factor.
IRB_Detail also exposes sa_comparison_supporting_factor and
supporting_factor_path_difference. A difference is diagnostic, not an automatic
error: eligibility may differ by approach and legacy SA data can be unverified.

U-TREA uses adjusted actual IRB/SA RWEA. S-TREA uses the independently adjusted
SA comparison. The existing output floor is then applied once. Neither TREA nor
the floor uplift is multiplied again by a support factor. A binding floor can
absorb some or all of an IRB-only reduction. Applied and fully-loaded views use
the same controlled exposure data with their respective rule contexts.

The input tables retain their bitemporal metadata. New disclosures are additive;
no tables or metrics are removed. Historical bundled workbooks/output runs remain
unchanged reference artifacts, not recomputed 1.2.0 runs. Generated new workbooks
use the extended effective schema.

### Verification and limits

Focused tests cover numeric boundaries and non-finite values, combined factors,
missing evidence, ineligible/defaulted/ADC exposures, unchanged K/EL, old inputs,
parameter sensitivity, Excel round trips and both floor regimes/views.
Existing portfolio golden results remain regression evidence with no new relief.
Synthetic eligibility references are fictional examples, never customer evidence.

### Primary sources

- [CRR, Articles 501 and 501a, consolidated 2026-01-01](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:02013R0575-20260101)
- [EBA Q&A 2020_5551: both factors may apply when both sets of conditions hold](https://www.eba.europa.eu/single-rule-book-qa/qna/view/publicId/2020_5551)

Source documents are not bundled. This correction does not automatically explain
differences to a particular bank's published RWA.
See [supporting-factor documentation](SUPPORTING_FACTORS.md) for inputs, eligibility, compatibility and audit output.
