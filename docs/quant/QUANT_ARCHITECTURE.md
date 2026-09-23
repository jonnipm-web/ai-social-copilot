# InsightValues Quant — Architecture (Foundation)

Quant is a **Financial Intelligence & Decision Support** vertical, not a
trading bot.

```
DATA → NORMALIZATION → FEATURES → ANALYSIS → RISK → SIGNAL/EVIDENCE
     → SCENARIO (future) → EXPLANATION (IVE, future) → DECISION SUPPORT
```

`DECISION SUPPORT → EXECUTION` is **not** part of Quant. See §8.

## 1. Placement

`supabase/functions/_shared/quant/` — server-side TypeScript (Deno), the
same runtime as every Edge Function and the Entitlement Core.

* **Why server-side**: metrics must be computed by the server authority so a
  client cannot forge them (threat "client-forged metrics"); a future Quant
  Edge Function imports this directly.
* **Why `_shared/`**: Edge Function bundles resolve imports under
  `supabase/functions/`; the parallel IVE Core uses the same pattern
  (`_shared/ive/`).
* **Surface-independent**: no Flutter, no widget, no HTTP. Android/Web
  consume results through a future API; the engine never runs on the client.
* **No Python**: every Foundation calculation is a closed-form O(n) formula
  that float64 TypeScript handles exactly as well as NumPy. A Python service
  would add a runtime, deploy target and supply chain for no gain. Revisit
  only for optimization/statistical modelling (e.g. covariance shrinkage,
  factor models) in Q4+, as an explicit architectural decision.
* **No new dependency**: all math is implemented and tested internally.

## 2. Modules

| Module | Responsibility |
|---|---|
| `errors.ts` | `QuantResult<T>`, machine error codes, warning codes |
| `instrument.ts` | instrument identity, asset classes, ISIN/FIGI validation |
| `provenance.ts` | provenance, trust, evidence strength, freshness |
| `timeseries.ts` | canonical `PriceSeries`, normalization, alignment |
| `csv.ts` | strict OHLCV CSV schema validation |
| `numeric.ts` | compensated summation, mean, variance |
| `metrics.ts` | pure calculation engine |
| `risk.ts` | risk foundation, weights, concentration, correlation matrix |
| `portfolio.ts` | manual/demo portfolio valuation, buy-and-hold return |
| `signals.ts` | descriptive signals (MA crossover) |
| `provider.ts` | `MarketDataProvider` abstraction + `FixtureProvider` |
| `analysis.ts` | `QuantAnalysisResult` orchestration + formula catalog |
| `display.ts` | display precision (the only rounding) |
| `ive_boundary.ts` | IVE/LLM explanation contract + grounding guard |
| `observability.ts` | allowlist-only log event |
| `domain_future.ts` | watchlist, fundamentals, economic series, untrusted document evidence |

Every production module imports only sibling modules (tripwire QB-03).

## 3. Pipeline

```
SOURCE (FixtureProvider | CSV | future provider)
  → VALIDATE (csv.ts schema, provenance.ts)
  → NORMALIZE (timeseries.createPriceSeries — the only PriceSeries constructor)
  → [STORE/CACHE — not in Foundation, see QUANT_DATA_MODEL §8]
  → ANALYZE (metrics/risk/signals via analysis.analyzeSeries)
  → QuantAnalysisResult
  → buildExplanationRequest → (future) IVE narrator → checkNarrativeGrounding
```

Calculations never read provider JSON; they receive `number[]` extracted
from a validated `PriceSeries`.

## 4. Market data provider abstraction

`MarketDataProvider { id, capabilities, lookupInstrument, latestQuote, historicalBars }`.
A provider returns **raw** rows plus a `DataProvenance` (source, source
as-of, retrieval time, frequency, currency, adjustment, trust). Canonical
data is built by `createPriceSeries`, never by the provider.

Foundation ships only `FixtureProvider` (deterministic golden data, injected
clock, `trust = SYNTHETIC_FIXTURE`, latest quote stamped with the last bar
time — never "now"). **No vendor is hard-coded** (no Alpha Vantage, Polygon,
Yahoo, Bloomberg…), no API key, no paid plan. Requirements for the first
real provider are in QUANT_SECURITY_MODEL §4.

## 5. Error contract

`QuantResult<T> = {ok:true,value} | {ok:false,error:{code,message,details}}`.
Codes: `INVALID_INSTRUMENT, INVALID_DATASET, DATASET_TOO_LARGE,
INSUFFICIENT_DATA, STALE_DATA, PROVIDER_UNAVAILABLE, UNSUPPORTED_ASSET_CLASS,
CURRENCY_MISMATCH, ENTITLEMENT_DENIED, CALCULATION_ERROR, DATA_QUALITY_ERROR,
INVALID_PORTFOLIO, INVALID_PARAMETER`. `message` is never a contract. Nothing
throws for data problems, so a failed calculation cannot be read as a number.

## 6. Analysis result and explainability

`QuantAnalysisResult` answers **which data** (instrument, period, bar count,
content hash), **from where / when** (provenance, freshness, evidence
strength), **which formula** (`formulaId` → `FORMULAS` catalog), **which
assumption** (price basis, annualization, no interpolation, calendar-naive,
sqrt-time, risk-free), **which result** (unrounded metrics), and **what is
caveat** (warnings, `risk.notImplemented`). `computedBy` is the literal
`'DETERMINISTIC_ENGINE'`.

Reproducible: `analysisId = sha256(engineVersion | instrumentKey |
contentHash | options)`; same input ⇒ same id and numbers regardless of row
order or call time (test AN-31).

## 7. LLM / IVE Quant boundary

* The LLM is **never** the authority for price, return, volatility,
  drawdown, weight or risk numbers.
* `buildExplanationRequest(result)` hands the narrator pre-computed,
  pre-formatted facts (`source: 'DETERMINISTIC_ENGINE'`), formulas, period,
  freshness, evidence strength, warning codes, limitations and rules — no
  raw bars, no user documents.
* `checkNarrativeGrounding(narrative, request)` rejects any numeric token
  not present in the facts and any citation of an unknown fact id.
* **Contract, not dependency**: `QuantNarrator` is an interface. IVE
  INTELLIGENCE CORE is built in parallel and is not imported (tripwire
  QB-03). Integration happens in a future Promotion/Integration Gate.

## 8. Execution boundary

**BROKER INTEGRATION IS NOT PART OF QUANT FOUNDATION.** There is no broker
adapter, credential, order type, paper-trading connection or execution
path, and tripwire QB-04 fails if any Quant module exports an
order/broker/trade/execute/submit/rebalance/transfer symbol.

Any future consequential financial action follows, with no shortcut:

```
IVE/Quant analysis → Action Intent → AEF → risk policy → Human Gate
  → broker adapter → broker → ExecutionReceipt → reconciliation
```

Today AEF v0 hard-denies `controlled_live`/`expanded_live` even with an
AUTHORIZED Human Gate (test QB-20), `ive-quant` is `CONSEQUENTIAL`, and
MP-09 forbids any Edge Function for it until AEF persistence exists. Every
real order will require explicit, per-action human authorization; that is a
separate, future, explicitly authorized architecture.

## 9. Entitlement

`ive-quant` is registered server-side as `EXPERIMENTAL` (admin-only via the
lifecycle rule; free/pro/premium/beta_tester → `MODULE_NOT_AVAILABLE`,
test QB-11). Any future Quant API must call `requireModuleAccess(req, user,
'<quant module>')` after authentication; plan and user id are derived
server-side, never from the body. See the architectural decision in
QUANT_ROADMAP §3 about splitting analytics from execution.

## 10. Project and Knowledge integration

* Project: an analysis may carry `projectId` as a **validated label only**;
  the engine does not authorize it. A server caller must verify ownership
  (RLS / `project_ownership`) before attaching or persisting. Instruments are
  not Projects.
* Knowledge: financial statements, research PDFs and CSV reports enter via
  Knowledge (no Quant document store). Figures extracted from documents are
  `UntrustedDocumentEvidence` — they may support a narrative, never stand in
  for market data, and never enter the engine without the same schema
  validation as any dataset.

## 11. Backtesting boundary (future)

Not built. The AEF `backtest` tier exists as a contract. A future engine
must handle look-ahead bias (point-in-time data; fundamentals keyed by
`filingDate`), survivorship bias (delisted instruments), transaction costs,
slippage, corporate actions, and data snooping (out-of-sample, multiple-test
correction). Backtest output is evidence about the past, never a signal to
execute.

## 12. News / sentiment

Not implemented. Future role: UNSTRUCTURED EVIDENCE SOURCE, never a
substitute for structured price/fundamental data.
