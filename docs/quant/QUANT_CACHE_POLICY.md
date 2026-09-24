# InsightValues Quant — Market-Data Cache & Provenance Policy (IV-QUANT-REAL-DATA-READINESS-03)

Code: `_shared/quant/market_cache.ts` (`InMemoryMarketCache`,
`CachingProvider`, `DEFAULT_CACHE_POLICIES`), tests CA-01..04 and MC-06.

## 1. What is cached

Only **provider** responses (historical bars) — never user uploads
(`USER_UPLOAD` is refused by `put`), never analysis results, never
anything client-supplied.

Key = JSON tuple `(providerId, providerVersion, instrumentKey, frequency,
adjustment, from, to)` with the period normalized (date for DAILY and
slower, minute for intraday), so identical requests within the TTL share an
entry and different adjustments/providers never collide.

## 2. Provenance is preserved, never refreshed

A hit returns the **original** provenance (`retrievedAt` = when the provider
answered) plus a separate `cache` block:

| Field | Meaning |
|---|---|
| `status` | `HIT`, `MISS`, `STALE_FALLBACK` |
| `state` | `FRESH_CACHE` / `STALE_CACHE` (null on MISS) |
| `providerRetrievedAt` | original provider time |
| `cacheServedAt` | server time of this answer |
| `ageMs` | cacheServedAt − stored time |

Freshness of the **market data** is still computed from the bars and the
exchange calendar — the cache never makes old data look fresh.

## 3. TTLs (`DEFAULT_CACHE_POLICIES`)

| Frequency | Fresh | Stale-serve (only if the provider fails) |
|---|---|---|
| INTRADAY_1M | 1 min | 5 min |
| INTRADAY_5M | 5 min | 20 min |
| INTRADAY_1H | 30 min | 3 h |
| DAILY | 6 h | 3 days |
| WEEKLY | 1 day | 7 days |
| MONTHLY | 1 day | 14 days |

A stale entry is served **only** when the provider call fails, is marked
`STALE_FALLBACK`, and the watchlist analysis adds a `CACHE_STALE` warning.

## 4. Scope and isolation

* In-memory LRU per Edge isolate (256 entries in `quant-analyze`). Market
  data is not user-specific, so a shared cache does not leak user data; the
  key contains no user id and no user input beyond validated instrument
  identity.
* Entries from a different `providerId` are never served (CA-03).
* No persistent cache table exists. A persistent/shared cache (Postgres or
  KV) is an architectural decision tied to vendor licensing (storage and
  redistribution terms differ per vendor — see
  QUANT_VENDOR_LICENSING_DOSSIER.md) and is **not** introduced here.

## 5. Observability

`cache_hits` / `cache_misses` counts per call in the allowlisted Quant log
line (stale fallbacks count as hits); never keys or symbols.
