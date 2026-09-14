# Installation, verification and CRAN release

## User installation

R 4.1 or newer is required. From a local source tarball:

```r
install.packages("riskweightedassets_1.1.0.tar.gz", repos = NULL, type = "source")
library(riskweightedassets)
list_reference_profiles()
```

After CRAN acceptance:

```r
install.packages("riskweightedassets")
```

## Development dependencies

Install the packages in `Imports` and `Suggests` from CRAN. `devtools` and
`roxygen2` are release tools but are not runtime dependencies.

```r
install.packages(c(
  "digest", "jsonlite", "openxlsx", "yaml",
  "testthat", "knitr", "rmarkdown", "devtools", "roxygen2"
))
```

## Reproducible verification

From `r-lib`:

```r
roxygen2::roxygenise()
devtools::test()
devtools::check()
```

Then always check the built artifact, not only the working directory:

```sh
R CMD build .
R CMD check --as-cran riskweightedassets_1.1.0.tar.gz
```

Review `00check.log`, `00install.out`, source-tarball contents and package sizes.
Expected release status is 0 ERRORs, 0 WARNINGs and 0 unexplained NOTEs.

## External platform checks

GitHub Actions must run `R CMD check` on current Linux, Windows and macOS.
Before submission, run Win-builder R release/devel and R-hub release, oldrel
and devel checks. These are complementary: local success does not establish
portability.

## CRAN-specific release sequence

1. Replace the placeholder corporate `cre` entry with the responsible natural
   person's given name, family name and confirmed email.
2. Set the intended release version and date; update `NEWS.md`.
3. Re-render roxygen help, README and vignettes.
4. Run all local and external checks in a clean environment.
5. Document a new submission and any justified NOTE in `cran-comments.md`.
6. Build once, record SHA-256 and submit that exact tarball through CRAN.
7. Answer CRAN reviewer questions promptly; do not modify unrelated behavior
   between reviewed revisions.
8. After acceptance, tag the identical Git commit and attach the source tarball,
   checksum and standalone documentation to the GitHub release.

## Troubleshooting

- A missing Suggested package under `_R_CHECK_FORCE_SUGGESTS_=true` means the
  check environment is incomplete, not that the dependency may be ignored.
- URL failures caused solely by an offline local sandbox must be repeated on a
  connected check service.
- A `VignetteBuilder` NOTE means vignettes were not built into the tarball.
- Locale-only warnings from obsolete local development packages should be
  reproduced on a current clean R release before classification.
- Never upload `r-lib-github` or a working tree as a CRAN artifact; submit the
  output of `R CMD build`.
