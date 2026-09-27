# InsightValues Quant — Multi-Series Analytics (IV-QUANT-REAL-DATA-READINESS-03)

Code: `supabase/functions/_shared/quant/multi_series.ts` (engine),
`multi_contract.ts` (API contracts), tests `multi_series_test.ts`
(MS-01..13, MC-01..06) and `quant-analyze/index_test.ts` (QM-01..06).

## 1. Scope and bounds

| Bound | Value | Enforced by |
|---|---|---|
| Series per analysis | 1..10 (`MAX_SERIES_PER_ANALYSIS`) | engine + parser + UI |
| Common bars required (≥ 2 series) | 4 (`MIN_ALIGNED_BARS`) | engine → `INSUFFICIENT_OVERLAP` (422) |
| Rows across all CSV series | 50 000 (`MAX_TOTAL_ROWS`, measured — QUANT_RESOURCE_BUDGET.md) | `runMulti` → `DATASET_TOO_LARGE` |
| Frequencies | one frequency for all series | engine → `INVALID_PARAMETER` |
| Same instrument twice | refused | engine → `INVALID_PARAMETER` |
| Watchlist lookback | 30..1 100 days | `parseWatchlistAnalysisRequest` |

Each series is first analyzed alone by the unchanged single-series engine
(`analyzeSeries`): freshness, calendar, provenance, metrics and warnings are
per series and identical to `quant.analyze.v1` for the same data.

## 2. Alignment — `INTERSECTION_OF_TIMESTAMPS`

* Cross-series numbers use only timestamps present in **every** series.
* No forward-fill, no interpolation, no resampling (`NO_INTERPOLATION`
  assumption is always listed).
* Each series reports `droppedFromAlignment` (bars outside the common set);
  any drop raises `MISSING_FROM_ALIGNMENT` with the total count.
* `alignedCumulativeReturn` = last aligned price / first aligned price − 1
  (MS-06: it starts at the first common bar, not at the series' own start).
* Different exchange calendars (e.g. XNYS vs XLON) → `CALENDARS_DIFFER`;
  holidays that exist on one venue only are dropped from cross-series
  metrics, never filled (MC-05 exercises a real US+UK case).

## 3. Currency semantics

* Returns are measured in each instrument's **own** currency
  (`RETURNS_IN_OWN_CURRENCY`). No FX conversion exists in the engine.
* Mixed currencies are allowed for per-series metrics and correlations and
  raise `MIXED_CURRENCY_RETURNS`, because a correlation of local-currency
  returns is a meaningful (and common) statistic — but it is **not** the
  investor's experience in a single base currency.
* A portfolio with mixed currencies is refused with `CURRENCY_MISMATCH`
  (MS-08). FX-converted portfolios are out of scope until an FX source with
  provenance exists.

## 4. Portfolio validation policies (`INVALID_PORTFOLIO`)

| Rule | Why |
|---|---|
| weights cover exactly the analyzed series | no hidden cash / implicit 0 |
| 0 < w ≤ 1 | long-only; no shorts or leverage; zero weights must be omitted |
| unique instrument keys | no double counting |
| Σw = 1 ± 1e-9 | explicit total; float noise (0.1+0.2+0.7) tolerated |
| single currency | see §3 |
| ≥ 2 common bars | a return needs two points |

Result: `buyAndHoldReturn` over the aligned window with initial weights
(`BUY_AND_HOLD_INITIAL_WEIGHTS`, no rebalancing) and concentration (HHI,
effective holdings, max weight). Hand-derived golden: MS-09 (0.6·10 % +
0.4·(−10 %) = 2 %).

## 5. Correlation

* Pearson on aligned **simple** returns; every pair uses the same window.
* `n(n−1)/2` unique pairs, order `(i, j)` with i < j (MS-05).
* Undefined (constant series, too few returns) → `correlation: null` with an
  `error` reason — never 0, never NaN (MS-04).
* Goldens: identical returns → 1 (MS-01), mirrored → −1 (MS-02), orthogonal
  zero-mean → 0 (MS-03), antisymmetry corr(A,C) = −corr(B,C) when B = −A (MS-05).

## 6. Reproducibility

`multiAnalysisId = qm_` + SHA-256 of (engine version, each series' key and
content hash, periods per year, price basis, weights, project). Same input →
byte-identical result; different weights → different id (MS-12).

The id is a **calculation-input identity** — exactly the semantics of the v1
`analysisId` (QUANT_API_CONTRACT.md §2, test QA-02): it identifies *what was
calculated*, not *when it was evaluated*. `generatedAt` and freshness follow
the server clock and are reported alongside it; the same bars analyzed later
keep the id while freshness may change (MS-14, Codex Gate 2).

## 7. Watchlist → analysis flow

Only ids travel. The server resolves the instruments from the caller's own
watchlist (RLS + user id), fetches bars from its own provider through the
cache, and runs the same engine. Today the only provider is the in-process
`SYNTHETIC_PROVIDER` (FIXTURE / SYNTHETIC_FIXTURE → evidence WEAK), so the
flow is exercised end-to-end without any vendor, key or real market data.
