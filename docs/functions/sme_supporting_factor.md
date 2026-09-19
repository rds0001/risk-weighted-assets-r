# `sme_supporting_factor()`

```r
sme_supporting_factor(total_amount_owed_eur, parameters = NULL)
```

Inputs: Positive Article 501 E* in EUR. Aggregate connected clients and institution group, apply the prescribed residential-collateral exclusion/fallback; do not substitute single-loan EAD.

Returns: Weighted factor: (min(E*, 2500000) * 0.7619 + max(E* - 2500000, 0) * 0.85) / E*.

Inputs must be finite; invalid values raise an error. Where accepted, `parameters`
can be the result of `regulatory_parameters()` or a parameter store. Use
`override_regulatory_parameters()` with a reason and approver for sensitivities.

```r
sme_supporting_factor(5000000) # 0.80595
```

This arithmetic helper does not certify eligibility. The table API requires
explicit eligibility flags, evidence and approval, and validates exposure context.
See [Supporting factors](../SUPPORTING_FACTORS.md) for legal scope, independent
SA/IRB inputs, legacy compatibility and output-floor treatment. Native help:
`?sme_supporting_factor`.
