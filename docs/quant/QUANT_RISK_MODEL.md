# InsightValues Quant — Risk Model (Foundation)

Coverage label: **`FOUNDATION_PARTIAL`**. Every risk overview carries
`notImplemented: [VAR, CVAR, BETA, FACTOR_EXPOSURE, LIQUIDITY,
TAIL_DEPENDENCE]` and the IVE explanation request repeats the limitation,
so no surface can present it as "risk complete".

## 1. Implemented

| Measure | Scope | Function |
|---|---|---|
| Volatility (sample σ, optional annualization) | series | `seriesRiskOverview`, `volatility` |
| Drawdown / max drawdown (+ peak, trough, recovery) | series | `seriesRiskOverview`, `maxDrawdown` |
| Concentration (HHI, effective holdings, max weight) | portfolio | `concentration`, `valuePortfolio` |
| Return correlation matrix (aligned, undefined pairs explicit) | set of series | `returnCorrelationMatrix` |
| Price freshness per holding | portfolio | `valuePortfolio` |

## 2. Known limitations

* σ assumes i.i.d. returns when annualized (√k scaling); volatility
  clustering is ignored.
* Correlations are sample Pearson on simple returns over the pairwise
  common window — unstable on short windows (min 3 observations).
* No portfolio-level volatility yet: it needs a covariance matrix over a
  common window and a rebalancing assumption; deferred to Q4 with an
  explicit model (constant-weight vs buy-and-hold drift).
* No FX: multi-currency portfolios are refused, not approximated.
* No liquidity, leverage, derivatives or short exposure.

## 3. Prepared, not implemented (Q4)

| Metric | Prerequisites |
|---|---|
| Historical VaR / CVaR | ≥ 250 aligned observations, confidence level + horizon as explicit assumptions, portfolio return series model |
| Parametric VaR | covariance estimation policy (sample vs shrinkage) |
| Beta | benchmark identity + aligned benchmark series |
| Factor exposure | factor data source + regression spec — possible Python/ADR trigger |
| Stress scenarios | Scenario entity (QUANT_DOMAIN_MODEL §12) |

No metric is added until its assumptions can be stated explicitly in the
result, as annualization and risk-free already are.
