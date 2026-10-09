# official_snapshot()

Selects the latest eligible official records at a business date and UTC knowledge
instant, then applies explicit official designations. Arguments default to run_config.
Returns a canonical table list without changing the input. Version 1.2.3 preserves
ISO time-of-day; see [timestamp contract and regression case](../SNAPSHOT_TIME.md).

```r
tables <- generate_synthetic_tables(bank_profile = "KSA_BANK")
snapshot <- official_snapshot(tables)
stopifnot(nrow(snapshot$business_indicator_item) == 30L)
```
