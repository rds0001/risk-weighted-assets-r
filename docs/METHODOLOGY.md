# Methodology

Version 1.2.0: [SME/infrastructure supporting factors, eligibility inputs and audit outputs](SUPPORTING_FACTORS.md).

This document describes the implemented analytical logic. It is not a legal
interpretation of CRR III and cannot replace institution-specific regulatory
assessment, permissions or supervisory reporting controls.

## Common conventions

All calculations use the official bitemporal snapshot and a strict parameter
store materialised from `crr3_eu_2026_v1.yaml`. Values are calculated without
intermediate presentation rounding. Capital requirements are converted to
risk exposure amounts using the configured Pillar 1 multiplier. The applied
and fully-loaded views differ only through their versioned rule-set context.

## Credit risk: Standardised Approach

Exposure at default starts from the Article 111 on-balance-sheet measure or a
configured override. Off-balance-sheet exposure applies the annex-class credit
conversion factor. Provisions, write-offs and value adjustments are handled in
the canonical exposure fields, and result rows expose on- and off-balance-sheet
components separately.

Risk weights are selected by exposure class, credit quality step and qualifying
flags. Dedicated branches cover central governments, institutions, corporates,
retail, defaulted exposures, specialised lending and real estate. Real-estate
treatment uses property type, income-producing/ADC/completion attributes,
prudential value, liens and exposure-to-value. Explicit, validated overrides
take precedence. Currency mismatch and eligible SME/infrastructure support are
then applied where configured.

The comprehensive CRM method applies volatility adjustments to exposure and
collateral, the maturity adjustment and foreign-exchange haircut. Unfunded
protection is allocated without exceeding the covered exposure and substitutes
the guarantor risk weight for the protected portion. The final SA RWEA is the
sum of post-CRM exposure multiplied by its effective risk weight and applicable
supporting factor.

## Credit risk: IRB

The engine supports corporate and retail correlation functions, PD and LGD
floors, maturity adjustment for non-retail exposures, default treatment,
financial-sector multipliers and expected loss. The core unexpected-loss
capital function is:

```text
K = LGD * N((G(PD) + sqrt(R) * G(q)) / sqrt(1 - R)) - PD * LGD
```

with the configured confidence quantile `q`, correlation `R`, floors and
maturity multiplier. RWEA equals EAD times `K` times the Pillar 1 multiplier.
Expected loss is reconciled against eligible provisions; shortfall and excess
flow into the capital calculation. A complete SA shadow calculation remains
available for the output floor.

## Counterparty credit risk, SFT and CCP

SA-CCR calculates replacement cost, multiplier, potential future exposure and
EAD by netting set. Add-ons use supervisory factors, maturity factors, option
delta and hedging-set aggregation. SFT applies the comprehensive method to
exposure, collateral and currency mismatch. CCP calculations distinguish trade
and default-fund components and apply their configured multipliers and floors.

## CVA, settlement and large exposures

BA-CVA aggregates counterparty-level discounted exposure terms and eligible
hedges. The parallel SA-CVA view aggregates delta, vega and curvature inputs by
bucket and risk class. Settlement risk applies delay-band factors. Large
exposure excess is converted to an additional capital requirement without
being confused with the ordinary credit exposure calculation.

## Securitisation

The hierarchy selects SEC-IRBA, SEC-SA or SEC-ERBA from approach availability
and tranche attributes. SSFA-based methods use pool capital, delinquency,
attachment and detachment points, supervisory parameters and floors. ERBA uses
rating, maturity, tranche seniority and STS status. Risk weights are capped and
floored before multiplication by tranche exposure.

## Market risk

The official 2026 rule-set calculates the legacy market-risk requirement while
also producing a non-official FRTB parallel view. The FRTB Standardised Approach
aggregates delta, vega and curvature sensitivities within buckets, across
buckets and across prescribed correlation scenarios, and adds DRC and RRAO.
The IMA input creates a separate parallel metric and is never silently added to
the official Standardised result. The fully-loaded rule set selects the FRTB
regime explicitly.

## Operational risk

Three years of accounting measures create the interest/lease/dividend,
services and financial components of the business indicator. Marginal
coefficients produce the BIC; the configured EU ILM is applied. Loss-event data
is retained for governance and reconciliation but does not replace the EU
parameter treatment.

## Output floor and total risk exposure amount

Unfloored TREA combines credit RWEA and the RWEA equivalents of relevant capital
requirements. Shadow TREA uses the complete Standardised credit calculation.
The transitional or fully-loaded floor factor is applied to shadow TREA. Legal
TREA is the greater of unfloored and floored amounts, subject only to a
configured legal cap. Any uplift is allocated back to risk components and must
reconcile exactly.

## Own funds and prudential constraints

CET1, AT1 and T2 are built from instrument and component tables after filters,
deductions, prudent valuation, IRB shortfall/excess and NPE backstop. Capital
ratios, Pillar 2 requirement, combined buffer, Pillar 2 guidance and headroom
are reported separately. Leverage, MREL and TLAC use their own denominators and
eligibility rules. Pillar 2 and economic-capital RWA equivalents are management
views and are explicitly prevented from double counting in legal TREA.

## IRRBB and CSRBB

Contractual and behavioural cash flows are assigned to repricing bands.
Currency-specific base curves are linearly interpolated, and six supervisory
shock shapes create EVE and one-year NII changes. Losses are aggregated across
currencies by scenario and compared with Tier 1 thresholds. CSRBB is a separate
stress factor applied to absolute base present value.

The stochastic EVE approximation uses 5,000 rate paths, a versioned volatility,
seed and 99% quantile. The bundled canonical seed uses the exact NumPy
PCG64/Ziggurat reference path to prove cross-language parity. Arbitrary seeds
use an isolated R stream and remain deterministic within R. VaR is the empirical
type-7 quantile; ES is the mean of losses at or above VaR.

## ICAAP

Standalone economic capital deducts provisions from VaR loss, floors the result
at zero and adds model-risk and non-diversifiable add-ons. Diversifiable amounts
are aggregated with a symmetric positive-semidefinite correlation matrix. A
policy cap limits recognised diversification. Economic capacity applies
eligibility factors, haircuts and management reserves. Normative projections
roll CET1, TREA and leverage exposure through scenario-specific profits,
distributions, OCI, issuances, redemptions and multipliers. The minimum projected
headroom and economic headroom are reported together but not netted.

## Formula governance

Every result row that exposes `formula_id` must refer to one of the 39 entries
in `formula_definition`. The formula version, legal reference and component are
materialised from the same regulatory YAML as the numerical parameters. The
`FORMULA_REGISTRY` control fails if implementation output refers to an
unregistered formula.
