# riskweightedassets

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![R package](https://img.shields.io/badge/R-%3E%3D4.1-blue.svg)](DESCRIPTION)

`riskweightedassets` is the R implementation of the RiskDataScience GmbH
reference engine for CRR III risk-weighted assets, regulatory capital, IRRBB
and ICAAP. It provides a stable R API, canonical Excel contracts, realistic
synthetic portfolios, bitemporal snapshots, deterministic lineage and
reconciliation controls. No Python runtime is required.

The package is intended for research, education, prototyping and independent
model validation. It is not legal, supervisory, accounting or investment
advice and is not a certified regulatory reporting system.

## Functional scope

- credit risk under the Standardised and IRB Approaches, CRM and output floor;
- counterparty credit risk, SFT, CCP, securitisation, CVA and crypto exposures;
- settlement, large exposures, legacy market risk, parallel FRTB and operational risk;
- own funds, buffers, leverage, MREL/TLAC and capital headroom;
- IRRBB/CSRBB and ICAAP economic and normative perspectives;
- 68 canonical input tables in 16 workbooks and 34 structured result tables;
- applied and fully-loaded views from the same official snapshot;
- two complete synthetic bank profiles and Python 1.0.0 golden-master parity.

## Installation

During development, build and install the local source package:

```r
install.packages("riskweightedassets_1.0.0.tar.gz", repos = NULL, type = "source")
```

After CRAN acceptance the standard command will be:

```r
install.packages("riskweightedassets")
```

## First in-memory calculation

```r
library(riskweightedassets)

tables <- generate_synthetic_tables(bank_profile = "MID_SIZE_UNIVERSAL")
result <- calculate_tables(tables)
print(result)
result$metrics[c("RWEA_KSA", "RWEA_IRB", "TREA", "CET1_RATIO")]
```

## Excel workflow

All writes go to a destination selected by the caller. Package resources are
immutable.

```r
root <- file.path(tempdir(), "rwa-runs")
dataset <- generate_synthetic_dataset(
  root,
  as_of = as.Date("2026-08-31"),
  version = "v1.0.0",
  bank_profile = "KSA_BANK"
)
validation <- validate_dataset(dataset)
result <- calculate_dataset(dataset)
result$output_files
```

`calculate_dataset()` writes six output workbooks and a machine-readable run
manifest below `outputs/<deterministic-run-id>/`. For integration without
spreadsheets, `calculate_tables()` accepts and returns ordinary R objects.

## Synthetic data and external-source boundary

The package contains synthetic data only. It contains neither customer data
nor downloaded regulations, standards, PDFs or other third-party publications.
`regulatory_sources()` returns official URLs and archival SHA-256 values; the
documents remain outside the distribution.

## Documentation

- [documentation map](docs/README.md)
- [complete standalone documentation](docs/RISKWEIGHTEDASSETS_COMPLETE_DOCUMENTATION.md)
- [generated R function reference manual](docs/riskweightedassets-reference.pdf)
- [public R API](docs/API.md)
- [architecture](docs/ARCHITECTURE.md)
- [data model](docs/DATA_MODEL.md)
- [Pillar 1 and capital methodology](docs/METHODOLOGY.md)
- [governance, controls and acceptance](docs/GOVERNANCE_CONTROLS.md)
- [reference profiles and testing](docs/REFERENCE_PROFILES_TESTING.md)
- [regulatory source catalogue](docs/REGULATORY_SOURCES.md)
- [installation and CRAN release](docs/INSTALLATION_CRAN.md)

Within R, start with `help(package = "riskweightedassets")` and the vignettes:

```r
browseVignettes("riskweightedassets")
```

## License and legal information

Copyright © 2026 RiskDataScience GmbH. Original package content is licensed
under GNU GPL version 3. External publications remain subject to their own
rights and are not redistributed.

- [Imprint](https://riskdatascience.net/impressum/)
- [Privacy policy](https://riskdatascience.net/datenschutzerklaerung/)
- [Legal and usage notice](inst/LEGAL.md)
