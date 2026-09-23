# InsightValues Quant — Calculation Specification (Foundation)

All functions live in `supabase/functions/_shared/quant/metrics.ts`
(plus `risk.ts`, `portfolio.ts`, `signals.ts`). They are pure, take plain
`number[]`, never throw for data problems, and return `QuantResult`.
No LLM participates in any calculation.

## 1. Precision policy

* **Computation precision**: IEEE 754 binary64, never rounded inside the
  engine. Sums use Neumaier compensated summation (`fsum`); variance is
  two-pass (mean, then Σ(x−x̄)²) — stable for near-constant series.
* **Display precision**: `display.ts` only — `formatRatioAsPercent` (2 dp),
  `formatPrice` (2 dp + currency), `formatNumber`; no `-0.00`. Display
  strings are never fed back into calculations.
* **Monetary values**: market value = quantity × price in float64, in the
  instrument currency, unrounded. Float64 is exact to ~15–16 significant
  digits, adequate for analytics. It is **not** a ledger: any future
  accounting/settlement feature (cash balances, fees, P&L booking) needs
  decimal/minor-unit integer arithmetic and is out of Quant Foundation scope.
* **Percentages** are ratios internally (0.1 = 10 %).
* **Every successful result is finite** (Codex Gate 1 CX1-02): finite inputs
  can still overflow (`MAX_VALUE / MIN_VALUE`, squared deviations of 1e308);
  any non-finite intermediate or output returns `CALCULATION_ERROR`
  `reason: NON_FINITE_RESULT`, never `ok(Infinity)`.
* **Numerically constant series** (Claude finding CL-03): returns of a
  constant-growth series (100, 110, 121, 133.1…) differ only in the last ulp.
  Without a guard that noise produced a Sharpe of 1.2e16 and a correlation of
  −0.87. A series whose RMS deviation is ≤ 64 ulp of its largest |value|
  (`isNumericallyConstant`) is treated as zero-variance for Sharpe and
  Pearson (`ZERO_VARIANCE`). Volatility still reports the measured (≈ 0) σ.
* **Test tolerances**: goldens use relative 1e−12 (each value is < 20
  float ops ≈ ≤ 4.4e−15 relative error; ~200× margin, while any formula error
  is ≥ 1e−6). Seeded property tests over ≤ 500-point series use 1e−10 (≤ 500
  accumulated ulps ≈ 1.1e−13). Weight sums use absolute 1e−9.

## 2. Returns

| Function | Formula | Input | Output | Edge cases |
|---|---|---|---|---|
| `simpleReturns` | rₜ = Pₜ/Pₜ₋₁ − 1 | n ≥ 2 prices > 0 | n−1 values | empty/1 → INSUFFICIENT_DATA; ≤0/NaN/∞ → INVALID_DATASET |
| `logReturns` | ℓₜ = ln(Pₜ/Pₜ₋₁) | same | n−1 | same |
| `cumulativeReturn` | P_last/P_first − 1 | n ≥ 2 | scalar | same |
| `compoundReturns` | exp(Σ log1p rₜ) − 1 | returns | scalar | any rₜ ≤ −1 → CALCULATION_ERROR |
| `rollingReturns(k)` | Pₜ/Pₜ₋ₖ − 1 | 1 ≤ k ≤ n−1 | first k entries null | k invalid → INVALID_PARAMETER / INSUFFICIENT_DATA |

Price basis (Codex Gate 1 CX1-03): **always `close` unless the caller
explicitly asks for `adjustedClose`** — no inference from field presence.
Recorded as assumption `PRICE_BASIS`. `close` on UNADJUSTED/UNKNOWN data
raises `ADJUSTMENT_UNKNOWN`; `adjustedClose` always raises
`ADJUSTED_CLOSE_PROVIDER_DEFINED` (with the OHLC adjustment in details),
because `provenance.adjustment` describes the OHLC fields and the
adjusted-close method is provider-defined.

## 3. Volatility

σ = √(Σ(rₜ − r̄)² / (n − 1)) — **sample** standard deviation (ddof = 1) of
per-period simple returns; n ≥ 2 returns. Annualized σ·√k only when
`periodsPerYear = k` is passed explicitly (e.g. 252 for daily equity
sessions); `null` ⇒ not annualized. Assumption `SQRT_TIME_SCALING`
(i.i.d. returns) is recorded when annualizing. σ ≥ 0 always.

## 4. Drawdown

DDₜ = Pₜ / max_{s≤t} P_s − 1 ≤ 0. Max drawdown = min DDₜ ∈ [−1, 0],
reported with the running-peak index, trough index and the first index
after the trough whose price ≥ peak price (recovery; null if not
recovered). Convention: drawdowns are **non-positive**; 0 = never below a
prior peak (peak/trough null). One price ⇒ MDD 0.

## 5. Moving average

SMAₜ(k) = (1/k)·Σ_{i=t−k+1..t} Pᵢ for t ≥ k−1; earlier entries are `null`
(never filled). O(n) (Codex Gate 1 CX1-07 — the first version was O(n·k),
~2.5e9 operations for 50 000 bars with a 50 000 window): the window sum is
recomputed exactly with `fsum` once every k steps and updated by
add/subtract in between, so drift spans < k updates (verified ≤ 1e−9
relative against exact sums for k up to 50 000). SMA(1) = identity (tested).

## 6. Correlation

Pearson ρ = Σ(x−x̄)(y−ȳ) / √(Σ(x−x̄)²·Σ(y−ȳ)²); equal lengths; n ≥ 3
(with n = 2 ρ is always ±1 — uninformative). A constant input ⇒
CALCULATION_ERROR `reason: ZERO_VARIANCE` (never 0, never NaN). Result
clamped to [−1, 1] only against floating overshoot. For price series, the
correlation matrix uses simple returns on **timestamp-aligned** bars (inner
join per pair); undefined pairs are reported with their error code.

## 7. Sharpe ratio

S = mean(r − rf) / stdev(r − rf) · √k. Computed **only** when both
`riskFreeRatePerPeriod` (same frequency as r) and `periodsPerYear` are
passed; otherwise INVALID_PARAMETER. Zero variance ⇒ CALCULATION_ERROR.
Assumption `RISK_FREE_RATE` recorded.

## 8. Portfolio

* Market value MVᵢ = qᵢ·Pᵢ; weight wᵢ = MVᵢ / ΣMV (single currency only).
* Concentration: HHI = Σwᵢ² ∈ [1/n, 1]; effective holdings = 1/HHI; max weight.
* Weights: finite, ≥ 0 (no shorts), unique keys, |Σw − 1| ≤ 1e−9.
* Buy-and-hold return: R = Σ wᵢ·(Pᵢ(t_end)/Pᵢ(t_start) − 1) over the first
  and last timestamps shared by **every** series (no fill). Exact for a
  buy-and-hold portfolio with initial weights and no cash flows; dividends
  count only if the price basis is dividend-adjusted.
* Unrealized return vs cost basis: P/costBasis − 1 (informational).

## 9. Signals

MA crossover (fast < slow): with sₜ = sign(fast−slow) and p the last
non-zero sign before t, a cross is reported at t when p ≠ 0, sₜ ≠ 0 and
sₜ ≠ p (Codex Gate 1 CX1-08, pinned by tests): above→equal→above is a touch
(no cross); above→equal→below is CROSSED_BELOW at the first bar strictly
below; below→equal→above is CROSSED_ABOVE. Output is `DESCRIPTIVE`,
`isRecommendation: false`.

## 10. Golden datasets and verification

`fixtures/golden.ts` (derivations inline) + `golden_g1_daily.csv`:

| Set | Closes | Hand-derived expectations |
|---|---|---|
| G1 | 100, 110, 99, 108.9, 98.01 | r = ±0.1 alternating; cumulative −0.0199; σ = √(0.04/3) = 0.1154700538…; σ₂₅₂ = √3.36 = 1.8330302780…; DD 0,0,−0.1,−0.01,−0.109; MDD −0.109 (peak 1, trough 4, no recovery); SMA₂ last 103.455; SMA₃ last 101.97 |
| G2 | 100, 80, 90, 120, 60, 130 | MDD −0.5 (peak 3, trough 4, recovery 5); cumulative 0.3 |
| G3 | 50 ×4 | r = 0; σ = 0; MDD 0; ρ and Sharpe undefined |
| G4 | 10, 9, 8, 9, 11, 13, 11, 9, 7 | SMA₂×SMA₃: CROSSED_ABOVE @4, CROSSED_BELOW @7 |
| CORR | x = 1..5 | y = 2x → +1; y = 12−2x → −1; (1,2,3)/(1,3,2) → 0.5 |
| Sharpe | r = 0.02, 0, 0.04; rf = 0.01; k = 4 | excess mean 0.01, sd 0.02 → 1 |
| Portfolio | 10×50, 5×100, 20×50 | total 2000; w = .25/.25/.5; HHI .375; eff. 2.667 |
| Buy-and-hold | A 100→110, B 50→45, 50/50 | 0 |

Invariants (seeded PRNG, identical every run): Π(1+r)−1 = cumulative;
Σℓ = ln(P_n/P_0); MDD ∈ [−1, 0] and = min DD; σ ≥ 0; ρ(x,x) = 1,
ρ(x,−x) = −1, symmetric, bounded; scale invariance (P×c leaves returns, σ,
MDD, ρ unchanged); sort order does not change the canonical series,
content hash or analysis id.
