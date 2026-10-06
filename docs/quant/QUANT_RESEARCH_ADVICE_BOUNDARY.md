# Quant Research / Financial Advice Boundary

**Mission:** IV-QUANT-MACRO-05 FASE 11  
**Status date:** 2026-10-04  
**Authority:** Agente Martins + Paulo (architectural policy)

---

## 1. The Boundary in One Sentence

InsightValues Quant computes **mathematical properties of historical price data**.
It does **not** produce financial advice, investment recommendations, or signals to
buy, sell, or hold any security.

---

## 2. What Quant Does (Research)

| Output | Example | Classification |
|---|---|---|
| Returns series | Daily % change for AAPL 2023–2024 | RESEARCH |
| Volatility (σ) | Annualised standard deviation | RESEARCH |
| Sharpe ratio | Risk-adjusted return (engine formula) | RESEARCH |
| Correlation matrix | Pairwise r between instruments | RESEARCH |
| SMA / cross-over | Simple moving average + cross-over dates | RESEARCH |
| Buy-and-hold baseline | Hypothetical starting-$10 000 result | RESEARCH — ILLUSTRATIVE |
| Period alignment | Common trading-day intersection | RESEARCH |
| Freshness / provenance | Data source, retrieval timestamp | RESEARCH — METADATA |

All outputs are derived **deterministically by the engine** from the user's own
input data (or server-side historical data from a licensed vendor). The engine
does not call an LLM for numeric output. No number is generated or adjusted by
a language model.

---

## 3. What Quant Does NOT Do

| Prohibited output | Why |
|---|---|
| "Buy X" / "Sell X" | Investment advice — regulatory risk; denied by AEF v0 |
| Price targets or forecasts | Predictive financial advice |
| Portfolio recommendations | Advisory; requires human gate + regulatory clearance |
| "X is undervalued" / "X is a good investment" | Advisory opinion |
| Back-tested signals with optimised parameters | Curve-fitting risk; deceptive without disclosure |
| Any real-money order | DENY_BY_V0 in `aef/action_classification.ts` |

The AEF v0 kernel enforces this at runtime: `controlled_live` and `expanded_live`
quant tiers are hard-denied regardless of entitlement or human gate.

---

## 4. IVE Narration Boundary

When IVE Core is promoted to narrate a `QuantAnalysisResult` (not yet authorised),
the narration contract must satisfy:

1. **Engine-sourced facts only** — the LLM restates what the engine computed; it
   does not add numeric estimates, forecasts, or qualitative opinions about value.
2. **No recommendation language** — no "consider", "should buy", "take profit".
3. **Mandatory disclaimer** — every narration must include or reference the
   disclaimer from §6 below.
4. **Fail-closed template rendering** — `renderNarrative()` rejects any template
   that embeds raw numeric content; numbers come only from `QuantAnalysisResult`
   via the typed `QuantExplanationRequest`. This is enforced in
   `ive_boundary.ts:renderNarrative()`.

The `ive-quant` module is CONSEQUENTIAL and has no Edge Function (MP-09). IVE
narration of quant output requires a separate promotion gate.

---

## 5. UI Disclaimer Requirements (Flutter)

Every screen that displays Quant output **must** show one of the following
(wording may vary; substance is mandatory):

### Short form (inline, below charts)
> This analysis is for informational purposes only and does not constitute
> financial advice. Past performance does not guarantee future results.

### Full form (modal / help sheet, accessible from ⓘ)
> InsightValues Quant calculates mathematical properties of historical market
> data. The results do not constitute financial advice, investment
> recommendations, or a solicitation to buy, sell, or hold any security.
> Always consult a qualified financial professional before making investment
> decisions. Past performance is not indicative of future results.

**Implementation requirement (MACRO-05 FASE 11):** Both `QuantLabScreen`
(existing) and any future `QuantScreen` product shell must display the short
form below every analysis output block, with an ⓘ button linking to the
full form in a bottom sheet.

---

## 6. Canonical Disclaimer Text (source of truth)

```
INFORMATIONAL ONLY. Not financial advice. Past performance ≠ future results.
Consult a qualified financial professional before making investment decisions.
```

This string is referenced by key `quant.disclaimer.short` in `intl/` (to be added
in the Flutter i18n pass — MACRO-05 FASE 18).

---

## 7. Regulatory Context (non-exhaustive)

InsightValues is not registered as a financial advisor in any jurisdiction. The
Research boundary above ensures Quant output qualifies as "data / analytics
services" rather than "investment advice" under common regulatory interpretations
(MiFID II recital 28, SEC IA Act §202). This assessment is not legal advice;
formal legal review is required before commercial launch.

---

## 8. Open Questions (owner decision required)

| # | Question | Decision authority |
|---|---|---|
| OQ-01 | Which disclaimer is legally sufficient for target markets (BR, US, EU)? | Paulo + legal |
| OQ-02 | Is a separate Terms of Service section required for Quant? | Paulo + legal |
| OQ-03 | When IVE narration is enabled: must the narration itself carry a disclaimer or is a page-level disclaimer sufficient? | Agente Martins + Paulo |
