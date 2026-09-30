# InsightValues Quant — Data Model (Foundation)

## 1. Raw vs canonical

RAW provider/CSV data never reaches a calculation. The only path is
`SOURCE → VALIDATE → NORMALIZE → (STORE/CACHE) → ANALYZE`, and
`createPriceSeries` is the only constructor of a canonical `PriceSeries`.

## 2. Frequencies

`DAILY, WEEKLY, MONTHLY, INTRADAY_1M, INTRADAY_5M, INTRADAY_1H`.

## 3. Provenance

`DataProvenance {providerId, providerKind, sourceAsOf?, retrievedAt,
frequency, currency, adjustment, trust, sourceLabel?}`

* `providerKind` ∈ FIXTURE | USER_UPLOAD | EXTERNAL_PROVIDER, and `trust`
  must match it (SYNTHETIC_FIXTURE | USER_SUPPLIED | PROVIDER_REPORTED): a
  user upload cannot claim to be provider data.
* `adjustment` ∈ UNADJUSTED | SPLIT_ADJUSTED | SPLIT_AND_DIVIDEND_ADJUSTED | UNKNOWN.
* Timestamps are ISO 8601 UTC with `Z`.
* **Evidence strength** is `STANDARD` only for provider-reported data with a
  known adjustment and a known source as-of; everything else is `WEAK` and
  the analysis carries `PROVENANCE_WEAK`. Weak evidence is still computed —
  the math does not change — but must not be presented as strong evidence.

## 4. Freshness

`assessFreshness(asOfMs, nowMs, policy)` → `FRESH | DELAYED | STALE |
UNKNOWN` with `ageMs`, `asOf`, `evaluatedAt`. Pure: `now` is injected, the
engine never reads the wall clock.

| Frequency | FRESH ≤ | DELAYED ≤ | beyond | future tolerance |
|---|---|---|---|---|
| INTRADAY_1M | 2 min | 20 min | STALE | 1 min |
| INTRADAY_5M | 10 min | 30 min | STALE | 1 min |
| INTRADAY_1H | 2 h | 6 h | STALE | 1 min |
| DAILY | 4 days | 7 days | STALE | 1 day |
| WEEKLY | 10 days | 21 days | STALE | 1 day |
| MONTHLY | 35 days | 70 days | STALE | 1 day |

* Reference time (assumption `FRESHNESS_REFERENCE`): `provenance.sourceAsOf`
  when declared, otherwise the newest bar timestamp. `createPriceSeries`
  rejects (`DATA_QUALITY_ERROR`) a `sourceAsOf` outside
  [newest bar, newest bar + one bar span] (Codex Gate 1 CX1-01: a provider
  claiming 2020 data while returning 2026 bars was reported FRESH), and
  `validateProvenance` rejects `sourceAsOf` later than `retrievedAt` + 5 min.
  Daily bars without `sourceAsOf` are labelled 00:00Z of the session date,
  so age is over-stated by up to one day — the conservative direction.
* An unusable clock or timestamp yields UNKNOWN (and `analyzeSeries`
  returns INVALID_PARAMETER for an unusable clock) — never an exception
  (Claude finding CL-02).
* Daily thresholds are **calendar-naive**: wide enough to span a weekend plus
  one holiday. A longer market closure can read DELAYED; an exchange
  calendar (Q1) will tighten this.
* Data in the future beyond the tolerance ⇒ UNKNOWN (clock/provider error),
  never FRESH.
* No state means "live". Stale data is analyzed (describes the past) with a
  `DATA_STALE` warning, or refused with `STALE_DATA` when the caller passes
  `acceptedFreshness`.

## 5. Time series

`PriceBar.t` is epoch ms UTC (safe integer) in [1800-01-01, 2300-01-01) —
outside it `INVALID_DATASET` (Claude finding CL-01: timestamps beyond the
ECMAScript Date range crashed `toISOString()`). Prices must be finite and > 0,
volume finite and ≥ 0, `low ≤ min(open, close)`, `high ≥ max(open, close)`.
`adjustedClose` is on every bar or on none.

**Timezone / calendar**: stored instants are UTC. Date-only daily bars are
session-date labels at 00:00Z, not exchange-local instants. The instrument
may carry `exchangeTimezone`. There is no exchange calendar (holidays,
half-days, sessions) in the Foundation — every analysis carries the
`CALENDAR_NAIVE` warning/assumption. The Foundation never assumes a 24/7
market and does not analyze 24/7 asset classes.

## 6. Normalization rules

| Situation | Behavior |
|---|---|
| out-of-order rows | sorted, `ROWS_REORDERED` warning |
| exact duplicate rows | collapsed, `EXACT_DUPLICATES_COLLAPSED` warning |
| different rows, same timestamp | `DATA_QUALITY_ERROR` (never pick one) |
| missing required field / NaN / ≤ 0 price | `INVALID_DATASET` (never filled) |
| OHLC inconsistent | `DATA_QUALITY_ERROR` |
| spacing > threshold (DAILY 4 d, WEEKLY 10 d, MONTHLY 35 d) | `TIME_GAPS_DETECTED` warning — **never interpolated** |
| > 50 000 bars | `DATASET_TOO_LARGE` |
| currency ≠ instrument currency | `CURRENCY_MISMATCH` |
| unsupported asset class | `UNSUPPORTED_ASSET_CLASS` |
| malformed instrument identity | `INVALID_INSTRUMENT` (validated + canonicalized by `createInstrument`, CX1-05) |
| zero bars | `INSUFFICIENT_DATA` (never an empty successful series, CX1-09) |
| `sourceAsOf` inconsistent with bars | `DATA_QUALITY_ERROR` (CX1-01) |

The returned `PriceSeries` is a deep-frozen copy: bars, instrument,
provenance and warnings cannot be mutated, and later mutation of the
caller's input objects does not reach it (CX1-06).

Pair-wise alignment (`alignOnTimestamps`) is an inner join: a timestamp
missing on either side is dropped from both — no forward fill.

## 7. CSV schema validation

A CSV is untrusted; it becomes a series only via `parseOhlcvCsv` +
`createPriceSeries`.

* Header required; case-insensitive; any order. Required: `date|timestamp,
  open, high, low, close`. Optional: `volume, adj_close|adjusted_close`.
  Unknown columns ignored (`UNKNOWN_COLUMNS_IGNORED`); duplicate/ambiguous
  columns rejected.
* RFC 4180 quoting, CRLF/LF, UTF-8 BOM, blank lines.
* Timestamps: `YYYY-MM-DD` or ISO 8601 **with** `Z`/offset. Rejected:
  `01/02/2026`, zone-less datetimes, epoch numbers, impossible dates.
* Numbers: plain decimal/exponent only. Rejected: thousands separators,
  decimal commas, currency symbols, `NaN`, `Infinity`, empty.
* Every row must have the header's field count.
* Limits: 5 MiB (UTF-8 bytes) and 50 000 data rows, checked before the work
  scales. Parser is a single linear pass (no backtracking regex on
  unbounded input).
* A non-OHLCV CSV (e.g. `name,email`) is rejected; a well-shaped CSV with
  inconsistent OHLC is rejected by normalization.
* Fixture: `supabase/functions/_shared/quant/fixtures/golden_g1_daily.csv`.

Existing app CSV import (`file_import_service.dart`) stores CSV as text in
Knowledge; that remains the document path. The Quant path is this
validator, server-side, invoked by a future Quant API.

## 8. Storage strategy

The Foundation persists **nothing**: no migration, no table, no bucket.

| Kind | Future home | Notes |
|---|---|---|
| user-owned state (watchlists, manual portfolios) | Postgres, RLS `user_id = auth.uid()`, optional `project_id` FK checked by ownership pattern | Q1/Q3 |
| analysis artifacts | Postgres row per `QuantAnalysisResult` (JSONB), owner + project scoped | only when a UI needs history |
| market-data cache | NOT millions of bars in Supabase. Short-TTL cache keyed by `(instrumentKey, frequency, range, adjustment, provider)`; object storage or a columnar store if volume demands — architectural decision | Q1 |
| raw datasets (uploads) | Knowledge / Storage bucket with existing ownership; normalized on read | Q1 |

## 9. Storage decisions (IV-QUANT-DATA-PLANE-AND-API-02)

| Kind | Now | Why |
|---|---|---|
| Watchlists (user-owned state) | **persisted** — `quant_watchlists`, `quant_watchlist_items` (QUANT_WATCHLIST_MODEL.md) | small, user-owned, needs RLS |
| Uploaded CSV datasets | **not persisted** — validated and analyzed in-request | no need yet; avoids storing user financial files |
| Analysis results | **not persisted** — reproducible from dataset + options (`analysisId`) | no history UI yet |
| Market bars | **not persisted** | no vendor; never millions of bars in Supabase |
| Knowledge files | reused only as a future source; the Lab imports a local `.csv` client-side (same 5 MB cap) and sends it to the API | no new bucket |
