# Reference profiles and testing

## Profiles

`MID_SIZE_UNIVERSAL` exercises the full mixed-method engine: SA and IRB credit,
CRM, CCR, SFT, CCP, CVA, securitisation, settlement, large exposures, market
risk, operational risk, capital, IRRBB and ICAAP.

`KSA_BANK` applies declarative profile transformations to the same canonical
base: IRB and non-applicable complex modules are emptied, all credit exposures
use KSA, and the complete capital/IRRBB/ICAAP stack remains active. It is not a
second hand-maintained dataset.

Both profiles use a 2026-08-31 base date, can be shifted to another reporting
date and contain only synthetic institutions, counterparties and transactions.

## Embedded resources

The installed package contains compressed R-native canonical tables, table
contracts, regulatory YAML, profile YAML, source metadata and the canonical
IRRBB stochastic path. `generate_synthetic_tables()` copies and materialises
these resources; callers cannot mutate the installed originals.

## Test layers

- formula tests cover SA, IRB, SA-CCR, securitisation, CVA, operational risk,
  output floor, NPE, discounting, IRRBB shocks and correlation aggregation;
- property tests cover positivity, finiteness and monotonicity over broad grids;
- contract tests guard schema inventory, boolean decoding, formula registry,
  temporal shifting and profile transformations;
- workbook tests generate all 16 inputs and validate the round trip;
- end-to-end tests calculate both profiles, require all controls, all 34 output
  tables and compare every metric against the Python 1.0.0 golden masters;
- package checks cover installability, examples, Rd files, namespace, portable
  files, code analysis and source-package contents.

## Local commands

```r
devtools::test()
devtools::check()
```

```sh
R CMD build .
R CMD check --as-cran riskweightedassets_1.1.0.tar.gz
```

Run the commands in a clean, current R installation. The package itself
supports R >= 4.1, but CRAN submission must also be tested on release, oldrel
and devel platforms.

## Expected canonical headline results

| Profile | SA RWEA | IRB RWEA | TREA | CET1 |
|---|---:|---:|---:|---:|
| MID_SIZE_UNIVERSAL | 5,401,278,717.59 | 901,108,184.57 | 8,691,246,387.71 | 1,352,732,127.71 |
| KSA_BANK | 9,752,217,943.87 | 0.00 | 11,040,467,943.87 | 1,352,732,127.71 |

These figures are regression anchors, not representative benchmarks for a
real institution.
