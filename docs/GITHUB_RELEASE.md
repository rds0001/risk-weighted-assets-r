# GitHub publication and release procedure

The public repository is `rds0001/risk-weighted-assets-r`. The distributable
GitHub tree is staged in `r-lib-github`; `r-lib` remains the authoritative local
source. The internal implementation plan, compiled package archives, check
directories, downloaded publications, credentials and local environments must
not be committed.

## Initial publication

1. Run `Rscript tools/verify-source-tree.R` in the staging directory.
2. Initialize the repository with the default branch `main`.
3. Review `git status` and the complete tracked-file inventory.
4. Commit with the corporate author identity and create the GitHub repository.
5. Push `main`, then watch every job in the `R-CMD-check` workflow.
6. Protect `main` after the first green matrix run and require the check before
   merging pull requests.

No CRAN submission is implied by a GitHub release. CRAN candidate preparation,
reverse-dependency checks and submission are governed separately by
`INSTALLATION_CRAN.md` and `cran-comments.md`.

## Release discipline

Every release must have an intentional version in `DESCRIPTION`, a matching
entry in `NEWS.md`, updated generated documentation, passing tests, and a clean
`R CMD check --as-cran`. Create the source archive with `R CMD build .`; attach
only deliberate release artifacts to a GitHub release, never commit them to the
repository. A release tag uses the form `vMAJOR.MINOR.PATCH` and must identify
the exact commit from which the checked archive was built.

## Legal and data boundary

The repository contains GPL-3-licensed original code and synthetic data. It
does not redistribute downloaded regulations or standards. Official sources
are referenced by URL and archival digest. The imprint and privacy policy are
linked from the package metadata and documentation. Issues and pull requests
must not contain customer, personal, confidential or bank-sensitive data.
