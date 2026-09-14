## Submission status

First CRAN submission. The package is a native R implementation and does not
call Python. It includes compressed synthetic data but no customer data and no
downloaded regulatory publications. Examples and tests are deterministic,
offline and write only below temporary directories.

## Current local results

Environment: Linux x86_64, R 4.1.2 (local compatibility floor check).

* `devtools::test()`: 0 failures, 0 skips; local `testthat`/`withr` emits
  locale warnings only when the host forces `LC_ALL=C.UTF-8`.
* `devtools::check()`: 0 errors, 0 warnings, 0 notes.
* `R CMD check --as-cran riskweightedassets_1.0.0.tar.gz`: 0 errors,
  0 warnings, 2 infrastructure notes: the restricted sandbox had no DNS for
  CRAN/URL checks and could not verify external current time.

These results are development evidence, not the final submission record.
Connected current-R, Win-builder and R-hub results must replace or supplement
them for the exact final source tarball before submission.

## Release gate

The `cre` role in `Authors@R` must be assigned to a named natural person before
the first CRAN submission. RiskDataScience GmbH remains `aut` and `cph`.
