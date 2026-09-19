# Local verification record

## Supporting-factor release 1.2.0 — 2026-09-19

Linux x86_64, R 4.1.2. Candidate: `riskweightedassets_1.2.0.tar.gz`.
SHA-256: `b39584d330afab48887e7a417b3fb0d76c4aa8e0ac01859b82640dededcd2714`.

- `R CMD build .`: successful, including all vignettes.
- `devtools::check(error_on="warning", args="--no-manual")`:
  0 errors, 0 warnings, 1 NOTE (external current time could not be verified).
- Connected `R CMD check --as-cran`: 0 errors, 0 warnings, 2 NOTEs:
  New submission; external current time could not be verified.
- Full devtools test stage: 222 passed, 0 failed, 0 warnings, 0 skipped.
  The old local testthat locale warnings disappear when LC_ALL is unset for the
  check process; no package behavior or tests were suppressed.
- All 77 exports have Rd aliases. The four new public functions have individual
  manpages, Markdown pages and executable examples. Both documentation PDFs
  were regenerated.
- New tests cover weighted/combined factors, eligibility evidence, invalid
  inputs, unchanged K/EL, independently adjusted floor paths, Excel round trips
  and full public calculations in applied and fully-loaded views.
- Source boundary verification passes; no customer data or downloaded sources
  were added. Historical reference outputs remain unchanged.

This is the GitHub development release. The separate pending CRAN 1.1.1
submission and its working directory were not modified.

## Historical verification: version 1.1.0

Date: 2026-09-14  
Platform: Linux x86_64  
R: 4.1.2  
Candidate: `riskweightedassets_1.1.0.tar.gz`
SHA-256: `024a94167a05d45294d5cfdd20925df55420ac18794beec3a9cd7e36aab94cf3`

## Results

- `devtools::test()`: 0 failures, 0 skips; both complete golden profiles pass.
- `devtools::check()`: 0 errors, 0 warnings, 0 notes.
- `R CMD build .`: successful; source tarball approximately 276 KiB.
- `R CMD check --as-cran`: 0 errors, 0 warnings, 2 local infrastructure
  notes (restricted sandbox DNS prevented remote URL checks; external current
  time could not be verified).
- Installed-tarball smoke test: successful installation, KSA dataset creation,
  calculation, six result workbooks and run manifest.
- Test inventory in the final built-tarball check: 142 passed, 0 failed,
  0 skipped.
- Export/documentation gate: all 73 exports have installed Rd aliases; all 34
  granular formula wrappers execute through the public namespace.

The old R 4.1 development environment reports 168 `testthat` warnings saying
that changing language has no effect while `LC_ALL=C.UTF-8`; these originate in
the installed `testthat`/`withr` locale helper on each expectation. They do not
originate in package calculations, and R CMD check classifies the test stage as
OK. Connected current-R and CRAN external-platform checks remain mandatory.

## Not yet a CRAN submission artifact

The candidate still uses RiskDataScience GmbH in the `cre` role. Before CRAN
submission, a responsible natural person's given and family name must be
supplied, the package rebuilt, and every check repeated against that exact new
tarball. The GitHub repository URL must also exist before connected URL checks.
