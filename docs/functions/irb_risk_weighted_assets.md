# `irb_risk_weighted_assets()`

```r
irb_risk_weighted_assets(ead, capital_requirement, sme_factor = 1,
                        infrastructure_factor = 1, parameters = NULL)
```

Inputs: Non-negative EAD and original K rate (not a currency amount), each factor in (0, 1], optional governed parameters.

Returns: EAD * RWA_MULTIPLIER[PILLAR1] * K * SME factor * infrastructure factor. K and expected loss are not changed.

Inputs must be finite; invalid values raise an error. Where accepted, `parameters`
can be the result of `regulatory_parameters()` or a parameter store. Use
`override_regulatory_parameters()` with a reason and approver for sensitivities.

```r
irb_risk_weighted_assets(1000000, 0.08, infrastructure_factor = 0.75) # 750000
```

This arithmetic helper does not certify eligibility. The table API requires
explicit eligibility flags, evidence and approval, and validates exposure context.
See [Supporting factors](../SUPPORTING_FACTORS.md) for legal scope, independent
SA/IRB inputs, legacy compatibility and output-floor treatment. Native help:
`?irb_risk_weighted_assets`.
