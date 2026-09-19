# `infrastructure_supporting_factor()`

```r
infrastructure_supporting_factor(parameters = NULL)
```

Inputs: Optional governed regulatory parameter data frame or store.

Returns: Configured Article 501a factor, normally 0.75.

Inputs must be finite; invalid values raise an error. Where accepted, `parameters`
can be the result of `regulatory_parameters()` or a parameter store. Use
`override_regulatory_parameters()` with a reason and approver for sensitivities.

```r
infrastructure_supporting_factor() # 0.75
```

This arithmetic helper does not certify eligibility. The table API requires
explicit eligibility flags, evidence and approval, and validates exposure context.
See [Supporting factors](../SUPPORTING_FACTORS.md) for legal scope, independent
SA/IRB inputs, legacy compatibility and output-floor treatment. Native help:
`?infrastructure_supporting_factor`.
