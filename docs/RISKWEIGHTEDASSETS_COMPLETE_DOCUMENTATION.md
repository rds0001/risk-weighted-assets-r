# riskweightedassets — complete documentation

Version 1.0 release-candidate documentation  
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
install.packages("riskweightedassets_1.0.0.tar.gz", repos = NULL, type = "source")
library(riskweightedassets)
```

After CRAN acceptance use `install.packages("riskweightedassets")`.

Runtime dependencies are `digest`, `jsonlite`, `openxlsx` and `yaml`. They are
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

The package exports ten functions:

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

The principal S3 result class is `rwa_calculation_result`. Its fields are
`status`, `run_id`, `engine_version`, `rule_set_id`, `metrics`, `controls`,
`validation`, `output_dir`, `output_files`, `results` and `parallel_results`.
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
R CMD check --as-cran riskweightedassets_1.0.0.tar.gz
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
