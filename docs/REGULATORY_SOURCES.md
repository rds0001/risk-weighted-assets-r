# Regulatory sources and redistribution boundary

The methodology was developed against official European Union, EBA and Basel
materials recorded in `inst/sources/sources.json`. Use:

```r
riskweightedassets::regulatory_sources()
```

to retrieve source identifier, title, issuing body, official URL, publication
or access metadata, expected archival SHA-256 and redistribution status.

## Boundary

Downloaded regulations, delegated acts, implementing standards, guidelines,
consultation papers, PDFs and webpages are deliberately excluded from the R
source tree, GitHub repository and CRAN package. They remain the property of
their publishers and may change independently. Documentation refers to their
official URLs; checksums provide historical provenance only.

At calculation time, a legal-source row may identify a caller-controlled local
file. If the file exists, its SHA-256 is checked. If it is absent, the bundled
source inventory must match the row's official URL and archival hash. No
automatic network download occurs, so package installation, examples and tests
remain offline.

## Use by institutions

Before relying on a result, users must obtain the current official text,
determine the applicable consolidated/solo perimeter and permissions, validate
national options and transitional provisions, and document any local legal
interpretation. Source provenance is an audit aid, not legal assurance.
