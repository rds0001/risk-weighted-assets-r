# Contributing

Contributions must preserve the canonical data contract, cross-language parity,
external-source boundary and GPL-3 licensing. Open an issue before changing a
public function, schema, formula or regulatory parameter.

Every change must include focused tests and, where relevant, updated golden
values with documented provenance. Run `roxygen2::roxygenise()`,
`devtools::test()`, `devtools::check()`, `R CMD build .` and `R CMD check
--as-cran` on the built tarball. Never commit customer data, downloaded legal
documents, credentials, local libraries or check/build artifacts.

By contributing, you certify that you have the right to submit the work under
GNU GPL version 3.
