# `apply_credit_supporting_factors()`

```r
apply_credit_supporting_factors(rwea, sme_factor = 1, infrastructure_factor = 1)
```

Inputs: Non-negative RWEA and each factor in (0, 1].

Returns: RWEA multiplied by both factors exactly once.

Inputs must be finite; invalid values raise an error. Where accepted, `parameters`
can be the result of `regulatory_parameters()` or a parameter store. Use
`override_regulatory_parameters()` with a reason and approver for sensitivities.

```r
apply_credit_supporting_factors(1000000, 0.80595, 0.75) # 604462.5
```

This arithmetic helper does not certify eligibility. The table API requires
explicit eligibility flags, evidence and approval, and validates exposure context.
See [Supporting factors](../SUPPORTING_FACTORS.md) for legal scope, independent
SA/IRB inputs, legacy compatibility and output-floor treatment. Native help:
`?apply_credit_supporting_factors`.
