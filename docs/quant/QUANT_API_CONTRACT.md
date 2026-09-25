# InsightValues Quant — API Contract (IV-QUANT-DATA-PLANE-AND-API-02, extended by REAL-DATA-READINESS-03)

Two Edge Functions, both **INTERNAL (admin-only)**, both **NOT deployed**
(Quant Lab only; not on `.github/deploy-allowlist.tsv`).

| Function | Module | Action class | Purpose |
|---|---|---|---|
| `quant-analyze` | `quant-analytics` | READ_ONLY | dataset → deterministic analysis |
| `quant-watchlists` | `quant-watchlists` | REVERSIBLE | user-owned watchlist CRUD |

`ive-quant` (CONSEQUENTIAL) has **no** Edge Function (MP-09 unchanged).

## 1. Request order (both functions)

```
OPTIONS → authenticate (resolveAuthenticatedUser: real GoTrue session, anon key rejected)
        → entitlement (requireModuleAccess, server policy, fails closed)
        → method (POST only) → Content-Type (application/json)
        → body cap (Content-Length AND streamed bytes) → JSON parse
        → strict schema (unknown fields rejected at every level)
        → project ownership (caller JWT + RLS, when project_id is sent)
        → work → structured response + allowlisted log line
```

Identity is derived only from the JWT. `user_id`, `plan`, `role`,
`module_access`, provider/trust claims, `source_as_of` or URLs in the body
are **rejected with 400** (not silently ignored).

## 2. `quant-analyze` — `quant.analyze.v1`

```json
{
  "contract_version": "quant.analyze.v1",
  "instrument": { "asset_class": "EQUITY|ETF|INDEX", "symbol": "AAPL", "exchange_mic": "XNAS",
                  "currency": "USD", "exchange_timezone": "…", "isin": "…", "figi": "…" },
  "dataset": { "format": "csv", "frequency": "DAILY|WEEKLY|MONTHLY|INTRADAY_1M|INTRADAY_5M|INTRADAY_1H",
               "adjustment": "UNADJUSTED|SPLIT_ADJUSTED|SPLIT_AND_DIVIDEND_ADJUSTED|UNKNOWN",
               "csv": "date,open,high,low,close,volume\n…", "source_label": "optional ≤120 chars" },
  "options": { "periods_per_year": 252, "price_basis": "close|adjusted_close",
               "sma_windows": [20, 50], "crossover": { "fast": 20, "slow": 50 },
               "sharpe": { "risk_free_rate_per_period": 0.0002, "periods_per_year": 252 },
               "accepted_freshness": ["FRESH", "DELAYED"] },
  "project_id": "uuid (optional)"
}
```

* `periods_per_year` must be stated (number > 0 or `null`).
* CSV: the Foundation parser (`csv.ts`) — 5 MiB, 50 000 rows, strict
  headers/timestamps/numbers, BOM/CRLF, RFC 4180. No second parser.
* Provenance is set **by the server**: `providerKind USER_UPLOAD`,
  `trust USER_SUPPLIED`, `retrievedAt` = server receipt time, no `sourceAsOf`
  (a client cannot claim provider-grade data) → evidence strength `WEAK`.
* No URL ingestion: the endpoint cannot fetch anything (no SSRF surface).
* No LLM, no quota reservation (no paid dependency; bounds in §6).

**200 response**

```json
{ "contract_version": "quant.analyze.v1", "correlation_id": "…", "analysis": QuantAnalysisResult }
```

`QuantAnalysisResult` (engine `quant-foundation-0.2.0`): `analysisId`,
`computedBy: DETERMINISTIC_ENGINE`, `subject`, `instruments`, `period`,
`dataSnapshot { provenance, contentHash, freshness, calendar, evidenceStrength }`,
`metrics[] { id, value, unit, formulaId, observations, parameters }`,
`signals` (descriptive), `risk` (FOUNDATION_PARTIAL + notImplemented),
`assumptions`, `warnings`, `generatedAt`.

Reproducibility: same dataset + engine version + options → same
`analysisId` and numbers; only `generatedAt`/freshness follow the clock
(test QA-02). Row order is irrelevant (QA-22).

## 3. `quant-watchlists` — `quant.watchlists.v1`

`{ "contract_version": "quant.watchlists.v1", "action": … }` with actions
`list`, `create {name, project_id?}`, `rename {watchlist_id, name}`,
`delete {watchlist_id}`, `add_item {watchlist_id, instrument}`,
`remove_item {watchlist_id, item_id}`. See QUANT_WATCHLIST_MODEL.md.

## 4. Error contract and HTTP mapping

Body: `{ "error": "<CODE>", "correlation_id": "…", "details"?: {…} }` — the
code is the contract; there is no human message to parse.

| HTTP | Codes |
|---|---|
| 400 | INVALID_PARAMETER, INVALID_INSTRUMENT, INVALID_DATASET, INVALID_JSON |
| 401 | Unauthorized (shared auth helper) |
| 403 | MODULE_NOT_AVAILABLE / PLAN_REQUIRED / MODULE_DISABLED (entitlement), PROJECT_ACCESS_DENIED |
| 405 | METHOD_NOT_ALLOWED |
| 413 | DATASET_TOO_LARGE (body, rows, bars, watchlist limits) |
| 415 | UNSUPPORTED_MEDIA_TYPE |
| 422 | DATA_QUALITY_ERROR, INSUFFICIENT_DATA, INSUFFICIENT_OVERLAP, CURRENCY_MISMATCH, UNSUPPORTED_ASSET_CLASS, STALE_DATA, CALCULATION_ERROR, INVALID_PORTFOLIO |
| 429 | RATE_LIMITED (+ `Retry-After`; QUANT_RATE_LIMIT_POLICY.md) |
| 500 | INTERNAL_ERROR (cause never echoed) |
| 502 | PROVIDER_MALFORMED (provider answered with an unusable payload) |
| 503 | ENTITLEMENT_UNAVAILABLE, OWNERSHIP_UNAVAILABLE, PROVIDER_UNAVAILABLE, PROVIDER_RATE_LIMITED, RATE_LIMIT_UNAVAILABLE (fail closed) |
| 504 | PROVIDER_TIMEOUT |

## 5. Observability

`quant-analyze`: exactly the `quantLogEvent` allowlist (analysis id,
provider id, instrument count, dataset size, period, calculation ids,
freshness, latency, error code) plus, since READINESS-03, `contract`
(one of the three contract versions, else null) and `cache_hits` /
`cache_misses` (counts only). `quant-watchlists`: operation, item count,
success, status, error code, latency, correlation id. Never logged: JWT,
CSV, prices, symbols, watchlist names, ids, project id (tests QA-50, QW-07).

## 6. Resource protection

READINESS-03: a per-user request rate limit now exists (429, fixed 60 s
window, enforced in Postgres; QUANT_RATE_LIMIT_POLICY.md). The monthly AI
quota remains the wrong unit for deterministic work. Protection is also by bounds, all enforced before or during
parsing: 6 MiB request body (streamed count), 5 MiB CSV, 50 000 rows/bars,
≤ 8 SMA windows (O(n) each), windows ≤ 50 000, calendar scans bounded,
16 KiB watchlist body, 200 items / 50 watchlists. Measured cost: see
QUANT_CURRENT_STATE.md §8. Multi-series: ≤ 10 series, ≤ 50 000 rows
in total, same 6 MiB body cap.

## 7. `quant-analyze` — `quant.analyze.multi.v1` (READINESS-03)

Same endpoint, dispatched by `contract_version`; `quant.analyze.v1` is
unchanged. Module `quant-analytics` (READ_ONLY).

```json
{
  "contract_version": "quant.analyze.multi.v1",
  "series": [ { "instrument": { …as v1… },
                "dataset": { "format": "csv", "frequency": "DAILY", "adjustment": "…", "csv": "…" } } ],
  "options": { "periods_per_year": 252, "price_basis": "close|adjusted_close",
               "weights": [ { "index": 0, "weight": 0.6 }, { "index": 1, "weight": 0.4 } ] },
  "project_id": "uuid (optional)"
}
```

* 1..10 series, ≤ 50 000 rows in total (measured, QUANT_RESOURCE_BUDGET.md); each CSV goes through the one
  Foundation parser; provenance is set by the server (USER_UPLOAD).
* Weights refer to series by position; policies in QUANT_MULTI_SERIES.md §4.
* 200: `{ contract_version, correlation_id, multi_analysis: MultiSeriesResult }`
  (`multiAnalysisId`, per-series `analysis` + `alignedCumulativeReturn` +
  `droppedFromAlignment`, `alignment`, `correlation[]`, `portfolio|null`,
  `assumptions`, `warnings`). Errors carry `details.series` = offending index.

## 8. `quant-analyze` — `quant.analyze.watchlist.v1` (READINESS-03)

```json
{ "contract_version": "quant.analyze.watchlist.v1", "watchlist_id": "uuid",
  "item_ids": ["uuid", …], "data_source": "SYNTHETIC_PROVIDER",
  "lookback_days": 365, "options": { "periods_per_year": 252 } }
```

* Requires BOTH `quant-analytics` and `quant-watchlists` entitlements (the
  second gate is evaluated after the first; either failing closes the call
  before the watchlist is read — test QM-05).
* Instruments are read **server-side** from the caller's own watchlist with
  the caller's JWT (RLS) plus a user-id filter; the body carries ids only.
  A watchlist the caller cannot see is `400 INVALID_PARAMETER {reason: NOT_FOUND}`
  (no existence oracle). Unknown `item_ids` → the same.
* More than 10 selected items → `413 DATASET_TOO_LARGE {reason: SELECT_ITEM_IDS}`.
* `data_source` accepts only `SYNTHETIC_PROVIDER` today (server-generated
  synthetic data through the provenance cache — QUANT_CACHE_POLICY.md). A
  licensed provider is a future, separately gated value; no URL, key or
  provider name is accepted from the client.
* 200: as §7 plus `multi_analysis.dataSource { kind, providerId, cache {hits, misses, staleFallbacks, uncached} }`.
