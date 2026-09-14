# Upstream and migration provenance

This native R package ports the published `risk-weighted-assets` Python package
version 1.0.0 by RiskDataScience GmbH. It preserves the public workflow,
canonical schema, regulatory configuration, formulas, validation semantics,
synthetic profiles and golden results while using idiomatic R data frames, S3
objects and conditions. It is not a Python wrapper and requires no Python
runtime.

The construction scaffold, Python environments, build products and downloaded
regulatory documents are outside this source tree. Development-only scripts in
`data-raw/` document creation of compressed R fixtures and are excluded from
the CRAN source tarball.
