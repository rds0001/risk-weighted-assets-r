## Summary

Describe the purpose and scope of the change.

## Verification

- [ ] `Rscript tools/verify-source-tree.R`
- [ ] `devtools::test()`
- [ ] `devtools::check(error_on = "never")`
- [ ] `R CMD check --as-cran` where release-relevant
- [ ] Documentation, tests and `NEWS.md` are updated where applicable
- [ ] No personal, confidential, bank-sensitive or downloaded third-party data is included

## Regulatory and compatibility impact

Describe any effect on methodology, data contracts, golden-master parity, or
backward compatibility. Write “none” if there is no such effect.
