# Documentation map

This documentation describes the R implementation itself. Regulatory source
documents are not part of the repository or package.

| Document | Purpose |
|---|---|
| [Complete documentation](RISKWEIGHTEDASSETS_COMPLETE_DOCUMENTATION.md) | Standalone end-to-end manual |
| [R reference manual](riskweightedassets-reference.pdf) | Generated package and function reference |
| [API](API.md) | Public functions, objects and integration patterns |
| [Architecture](ARCHITECTURE.md) | Components, data flow and side-effect boundaries |
| [Data model](DATA_MODEL.md) | Canonical tables, history and spreadsheet layout |
| [Methodology](METHODOLOGY.md) | Pillar 1, capital, IRRBB and ICAAP methods |
| [Governance and controls](GOVERNANCE_CONTROLS.md) | Validation, controls, lineage and acceptance |
| [Parity contract](PARITY_CONTRACT.md) | Python-to-R equivalence rules and tolerances |
| [Reference profiles and testing](REFERENCE_PROFILES_TESTING.md) | Synthetic data and quality gates |
| [Regulatory sources](REGULATORY_SOURCES.md) | External-source boundary and provenance |
| [Installation and CRAN](INSTALLATION_CRAN.md) | Installation, checks and release process |
| [GitHub publication](GITHUB_RELEASE.md) | Repository staging, CI and release discipline |
| [Local verification](LOCAL_VERIFICATION.md) | Candidate hash and executed check evidence |
| [Legal](LEGAL.md) | License, disclaimer, imprint and privacy |

Function-level Markdown pages are in [`functions/`](functions/). Native R help
is generated from roxygen2 and available through
`help(package = "riskweightedassets")`.
