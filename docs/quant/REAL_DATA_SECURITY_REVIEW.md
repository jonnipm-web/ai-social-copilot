# InsightValues Quant — Real Data Security Review
# IV-QUANT-LICENSED-PROVIDER-PILOT-04

**Date:** 2026-10-02  
**Scope:** Databento DBEQ.BASIC adapter (`databento_adapter.ts`) + credential management  
**Threat model:** SSRF, redirect abuse, credential leak, provider spoof, symbol confusion,
cache poisoning, cross-user isolation, oversized response, malformed JSON, rate-limit bypass

---

## 1. SSRF Protection

| Control | Status | Evidence |
|---|---|---|
| Outbound calls via `safeFetch` only | ✓ PASS | `HttpAdapterProvider` uses `safeFetch` (or injected mock in tests); raw `fetch` not called |
| Host allowlist | ✓ PASS | `allowedHosts: ['hist.databento.com']`; re-checked on every redirect hop by `safeFetch` |
| Protocol check (HTTPS only) | ✓ PASS | `buildRequest` rejects non-https base URL; `safeFetch` enforces https scheme |
| Redirect re-validation | ✓ PASS | `safeFetch` re-validates allowedHosts + IP ranges on each hop (max 3 hops) |
| Private/loopback IP blocked | ✓ PASS | `safeFetch.isBlockedIpv4/Ipv6` covers all RFC1918, loopback, link-local, metadata |
| IPv6-mapped IPv4 | ✓ PASS | `expandIpv6Groups` handles `::ffff:127.0.0.1` correctly (X4R fix) |
| URL userinfo tricks blocked | ✓ PASS | `assertUrlShapeIsSafe` rejects URLs with username/password fields |
| Credential not in URL | ✓ PASS | Runtime checks for `key=`/`token=` in URL query; adapter uses header-only auth |
| DNS rebinding | ⚠ DOCUMENTED_GAP | Known gap in safeFetch (documented since X4C); out of scope for this mission |

---

## 2. Credential Isolation

| Control | Status | Evidence |
|---|---|---|
| Key stored server-side only | ✓ PASS | `secretEnvName: 'DATABENTO_AUTH'`; read from `Deno.env` only |
| Key never in URL | ✓ PASS | `secretHeader: 'Authorization'`; runtime enforces header-only injection |
| Key never logged | ✓ PASS | Runtime does not log headers; `DATABENTO_AUTH` is not logged anywhere in adapter |
| Key never in Flutter/client | ✓ PASS | Flutter never calls provider directly; all data flows through Edge Function |
| Key dropped on cross-origin redirect | ✓ PASS | `safeFetch.headersForHop` drops `Authorization` on origin change; `credentialHeaders: ['Authorization']` set by runtime |
| Missing key = fail closed | ✓ PASS | `HttpAdapterProvider` returns `PROVIDER_UNAVAILABLE` immediately if `readSecret` returns null |
| Secret format documented | ✓ PASS | Header must be `Basic <base64(apiKey:)>`; documented in adapter file and DECISION.md |

---

## 3. Response Validation / Provider Spoofing

| Control | Status | Evidence |
|---|---|---|
| Instrument-ID consistency | ✓ PASS | `parseResponse` rejects responses with multiple `instrument_id` values — prevents mixed-instrument responses |
| Rtype validation | ✓ PASS | Only `rtype=32` (OHLCV-1d) accepted; unexpected rtypes rejected |
| Window bounds check | ✓ PASS | Bars outside `[fromT - DAY_MS, toT]` rejected (Codex Gate 2 precedent) |
| Look-ahead guard | ✓ PASS | `ts_event > retrievedAtMs` rejected |
| Non-positive prices rejected | ✓ PASS | `parsePrice` returns null for zero/negative |
| Invalid timestamps rejected | ✓ PASS | `Date.parse` failure → `PROVIDER_MALFORMED` |
| Response size cap | ✓ PASS | `maxResponseBytes: 16MB`; safeFetch enforces it |
| Timeout | ✓ PASS | `timeoutMs: 30_000` |
| Malformed JSON | ✓ PASS | Per-line `JSON.parse` with error → `PROVIDER_MALFORMED` |
| Empty response | ✓ PASS | Returns `INSUFFICIENT_DATA` |

---

## 4. Symbol Confusion / Identity Mismatch

| Control | Status | Evidence |
|---|---|---|
| Single-symbol request | ✓ PASS | `symbols = req.instrument.symbol` — exactly one symbol per call |
| MIC/exchange validation at request time | ✓ PASS | Unsupported MICs rejected in `buildRequest` |
| Symbol not echoed in response | ⚠ DOCUMENTED_LIMITATION | Databento OHLCV-1d bars don't include symbol field; instrument_id consistency check partially mitigates |
| instrument_id consistency | ✓ PASS | Multiple IDs in one response → `PROVIDER_MALFORMED` |
| Adjustment policy mismatch | ✓ PASS | `buildRequest` rejects SPLIT_ADJUSTED requests (not available in DBEQ.BASIC OHLCV) |

**Note on symbol identity limitation:** The adapter trusts Databento's routing for the requested symbol.
A compromised or misbehaving Databento endpoint could return data for a different instrument with the same
instrument_id. Mitigation: credentials ensure we are talking to the real Databento API; HTTPS pinning is
not implemented (standard gap). No further mitigation is feasible without Databento adding symbol echo to
the OHLCV schema.

---

## 5. Cache Integrity

| Control | Status | Evidence |
|---|---|---|
| Cache key includes providerId | ✓ PASS | `marketCacheKey` includes `providerId` — no cross-provider spoofing |
| Cache key includes instrument identity | ✓ PASS | `instrumentKey(i)` in cache key |
| Cache key includes adjustment policy | ✓ PASS | Part of the cache key |
| User-upload data not cached | ✓ PASS | `InMemoryMarketCache.put` rejects `USER_UPLOAD` provenance |
| Provenance preserved through cache | ✓ PASS | `CachingProvider` returns original provenance from `Entry.provenance` |
| Stale data clearly flagged | ✓ PASS | `STALE_CACHE` state + `CACHE_STALE` warning |
| Cross-user data leakage | ✓ PASS | Cache is public market data only (no user-specific data cached) |

---

## 6. Rate Limiting

| Control | Status | Evidence |
|---|---|---|
| Quant-side rate limits preserved | ✓ PASS | Existing `rate_limit_policy.ts` buckets (analyze, watchlists) unchanged |
| Provider-side rate limit handling | ✓ PASS | 429 → `PROVIDER_RATE_LIMITED` with `retryAfterSeconds` from header |
| Cache reduces provider calls | ✓ PASS | `CachingProvider` serves FRESH entries without calling Databento |
| No rate-limit bypass | ✓ PASS | No retry loop in adapter; caller handles retries through normal error flow |

---

## 7. Observability (no secret leakage)

| Control | Status | Evidence |
|---|---|---|
| Secrets not logged | ✓ PASS | Adapter and runtime never log header values |
| Raw dataset not logged | ✓ PASS | Only provenance metadata logged by observability layer |
| Error codes are safe | ✓ PASS | `PROVIDER_MALFORMED`, `PROVIDER_UNAVAILABLE` — no internal details in user-facing errors |

---

## 8. Security Findings

### P0 / P1: NONE

### P2 (Medium):
- **P2-SEC-01: Symbol not confirmed in response** — Databento OHLCV-1d bars don't echo the requested symbol. Instrument-ID consistency is the only in-response guard. Risk: low (credentialed API, HTTPS, single-symbol request per call). Accepted for pilot; track for resolution when Databento adds symbol to bar schema.

### P3 (Low):
- **P3-SEC-01: DNS rebinding gap** — Pre-existing documented gap in `safeFetch`. Not introduced by this adapter. Track in security backlog.
- **P3-SEC-02: Attribution not confirmed** — Databento attribution requirements not confirmed in writing. If attribution is required and not shown, this could breach terms. Mitigate: confirm in writing before commercial launch.
- **P3-SEC-03: Long-term storage policy unconfirmed** — Raw data caching beyond the freshTtlMs window may exceed what Databento implicitly permits. Mitigate: confirm in writing; implement TTL-bounded persistent cache.

---

## 9. Verdict

**SECURITY: CONDITIONAL_PASS**

No P0/P1 findings. P2-SEC-01 is accepted for the pilot phase with documentation.
P3 items are pre-existing or deferred to commercial negotiation. The adapter may
proceed to pilot integration.
