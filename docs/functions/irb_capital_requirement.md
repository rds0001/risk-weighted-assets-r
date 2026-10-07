# irb_capital_requirement

Returns the unexpected-loss capital rate K for one exposure. See the R help
page `?irb_capital_requirement` for the full argument reference.

Since 1.2.1, defaulted calls require `lgd_treatment = "SUPERVISORY"` or
`"OWN_ESTIMATES"`. The former returns zero independently of ELBE; the latter
returns `max(lgd - elbe, 0)`. Default PD is normalised to one; PD of one
without default is rejected. Performing calls retain their arithmetic.

```r
irb_capital_requirement(1, .4, .2, 2.5, defaulted = TRUE,
                       elbe = .1, lgd_treatment = "SUPERVISORY")
# 0
```

The function returns K, not EL or RWEA. The portfolio API calculates all three
consistently. See [methodology and migration](../IRB_DEFAULT_CORRECTION.md).
