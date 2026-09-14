# Local verification record

Date: 2026-09-14  
Platform: Linux x86_64  
R: 4.1.2  
Candidate: `riskweightedassets_1.0.0.tar.gz`  
SHA-256: `f407a198bab45ed7eafff9595fed2c140098bdf2995af735abc5601a569c288e`

## Results

- `devtools::test()`: 0 failures, 0 skips; both complete golden profiles pass.
- `devtools::check()`: 0 errors, 0 warnings, 0 notes.
- `R CMD build .`: successful; source tarball approximately 276 KiB.
- `R CMD check --as-cran`: 0 errors, 0 warnings, 2 local infrastructure
  notes (restricted sandbox DNS prevented remote URL checks; external current
  time could not be verified).
- Installed-tarball smoke test: successful installation, KSA dataset creation,
  calculation, six result workbooks and run manifest.
- Test inventory in the final built-tarball check: 126 passed, 0 failed,
  0 skipped.

The old R 4.1 development environment reports 148 `testthat` warnings saying
that changing language has no effect while `LC_ALL=C.UTF-8`; these originate in
the installed `testthat`/`withr` locale helper on each expectation. They do not
originate in package calculations, and R CMD check classifies the test stage as
OK. Connected current-R and CRAN external-platform checks remain mandatory.

## Not yet a CRAN submission artifact

The candidate still uses RiskDataScience GmbH in the `cre` role. Before CRAN
submission, a responsible natural person's given and family name must be
supplied, the package rebuilt, and every check repeated against that exact new
tarball. The GitHub repository URL must also exist before connected URL checks.
