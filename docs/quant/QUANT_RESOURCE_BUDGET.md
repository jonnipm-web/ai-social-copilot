# InsightValues Quant — Resource Budget (preliminary, IV-QUANT-REAL-DATA-READINESS-03)

**Preliminary technical budget, not a commercial limit.** Numbers come from
`tool/quant_benchmark.ts` on local Deno 2.9.6 (V8 15.0), 3–5 runs, median.
**PLATFORM_RUNTIME_NOT_MEASURED**: the Supabase Edge runtime itself was not
measured (that needs a deploy, which this mission forbids). Platform ceilings
used for the margins, from the public limits page
(supabase.com/docs/guides/functions/limits, read 2026-09-25): **2 s CPU time
per request**, **256 MB memory**, wall clock 150 s (free) / 400 s (paid).

## 1. Bounds in force

| Bound | Value | Where |
|---|---|---|
| Request body | 6 MiB (Content-Length and streamed count) | `MAX_ANALYZE_BODY_BYTES` |
| CSV per dataset | 5 MiB | `csv.ts` |
| Rows / bars per series | 50 000 | `MAX_BARS_PER_SERIES` |
| Series per multi analysis | 10 | `MAX_SERIES_PER_ANALYSIS` |
| Rows across a multi request | **50 000** (chosen by measurement, §3) | `MAX_TOTAL_ROWS` |
| Watchlist instruments per analysis | 10 (larger lists must pass `item_ids`) | `runWatchlistAnalysis` |
| Watchlist lookback | 30..1 100 days | `MAX_LOOKBACK_DAYS` |
| SMA windows | ≤ 8, each ≤ 50 000 | v1 parser |
| Watchlists / items | 50 per user / 200 per list | watchlist contract + DB |
| Provider response | adapter `maxResponseBytes`; request timeout `timeoutMs` | `AdapterSpec` + `safeFetch` |
| Market cache | 256 entries per isolate (LRU) | `quant-analyze` |
| Rate limits | 30 analyses / min / user (+ watchlist buckets) | QUANT_RATE_LIMIT_POLICY.md |

## 2. Measurements (after the calendar fix in §4)

| Scenario | Median | Max | Heap peak | Body |
|---|---|---|---|---|
| A — v1, 1 series × 50 000 rows, 8 SMA windows | 509 ms | 539 ms | 152.6 MB | 2.5 MB |
| B — multi, 10 × 10 000 rows (100 000) + portfolio | 1 206 ms | 1 303 ms | 106.6 MB | 5.0 MB |
| B — multi, 10 × 5 000 rows (**50 000**) + portfolio | 417 ms | 454 ms | 55.0 MB | 2.5 MB |
| B — multi, 10 × 3 000 rows (30 000) + portfolio | 313 ms | 376 ms | 60.9 MB | 1.5 MB |
| C — watchlist, 10 × 1 100 days, cold cache | 54 ms | 106 ms | 32.7 MB | — |
| C — watchlist, 10 × 1 100 days, warm cache | 44 ms | 50 ms | 33.8 MB | — |

Process RSS during the runs ≈ 245–257 MB **including the whole Deno
runtime** (not comparable to the Edge 256 MB per-request memory figure).

## 3. Decision — multi total rows = 50 000

100 000 rows used ~60 % of the 2 s CPU ceiling **on a desktop CPU**; an Edge
worker can be slower, so the margin is insufficient. 50 000 rows (the same
ceiling as one v1 series) runs in ~0.42 s with a ~55 MB heap peak — ~20 % of
the CPU budget. Enforced exactly (test MC-03b). A request above it gets
`413 DATASET_TOO_LARGE {max: 50000}` before any analysis work.

## 4. Optimization made (measured need)

Calendar-aware analysis rebuilt each year's holiday set on every
`isTradingDay()` call (once per bar and per scanned day). Memoizing the pure
year rule (`memoByYear`, `calendar.ts`) gave, same results:

| Case | Before | After |
|---|---|---|
| 10 000 XNYS bars, analysis stage | 183 ms | 51 ms |
| multi 10 × 5 000 | 1 187 ms | 417 ms |
| watchlist 10 × 1 100 d (cold) | 258 ms | 54 ms |

Calendar regression suites (CAL-*, incl. 2021-12-31, 2021-06-18, Juneteenth,
DST, Easter, observed holidays) pass unchanged.

## 5. Known risk (not changed — contract preservation)

Scenario A (the existing `quant.analyze.v1` bound of 50 000 rows with 8 SMA
windows) peaks at ~153 MB of JS heap. It is inside 256 MB but with limited
headroom once the Edge runtime's own footprint is added. Lowering the v1
bound would silently change a published contract, so it is **not** changed
here; it is a mandatory re-measurement item on the real platform before any
promotion beyond INTERNAL (PLATFORM_RUNTIME_NOT_MEASURED).

## 6. Timeout assumptions

* Provider fetch: per-adapter `timeoutMs` (synthetic adapter: in-process, no network).
* Whole request: bounded by the 2 s CPU budget; wall clock only matters for
  a future network provider (per-instrument calls are sequential today —
  10 instruments × provider latency must stay well under 150 s; a real
  provider needs a total deadline, recorded for the vendor mission).
