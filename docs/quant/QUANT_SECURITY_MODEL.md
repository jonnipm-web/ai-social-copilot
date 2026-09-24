# InsightValues Quant — Security Model (Foundation)

The Foundation has **no deployed surface**: no Edge Function, no table, no
bucket, no network client, no secret. Its security properties are therefore
properties of the library, enforced by tests, plus rules any future Quant
API must follow.

## 1. Threat model

| Threat | Foundation mitigation | Rule for future Quant API |
|---|---|---|
| Cross-user portfolio access | no persistence | owner-scoped tables with RLS `user_id = auth.uid()`; user id from JWT only |
| Cross-project access | `projectId` is a UUID-validated **label**, not authorization | verify ownership server-side (existing `project_ownership` pattern) before attaching/persisting; RLS on project FK |
| Forged instrument | `createInstrument` strict charset/length, ISIN/FIGI check digits, MIC/ISO 4217 formats | resolve through provider lookup before trusting |
| Malformed CSV | strict schema, strict numbers/timestamps, field-count check, RFC 4180 parser | same validator server-side |
| Oversized dataset | 5 MiB / 50 000 rows (CSV), 50 000 bars, 500 positions, 200 watchlist items, 8 SMA windows | also cap request body before parsing |
| Prompt injection via research/docs | documents are `UntrustedDocumentEvidence`; explanation request carries only engine facts + codes, never raw documents or free-text CSV columns | IVE delimiting as in `extract-knowledge` |
| Provider poisoning | provenance + trust + evidence strength; normalization rejects inconsistent OHLC / conflicting duplicates | cross-provider sanity checks (Q1) |
| Stale data | freshness on every result; `DATA_STALE` warning; `STALE_DATA` refusal on request | UI must show as-of time next to every figure |
| API-key leakage | no keys exist; tripwire QB-02 forbids `Deno.env` in Quant modules | keys only in server env of the provider adapter, never logged, never returned |
| SSRF / untrusted URL | no network access in Quant (QB-02) | fixed allowlisted hosts via `_shared/safe_fetch.ts`; no user-supplied URLs to providers |
| Calculation manipulation | engine is pure, deterministic, versioned; `analysisId` binds engine version + data hash + options | persist `contentHash` with artifacts |
| Client-forged metrics | metrics computed server-side only; nothing accepts a metric from a client | API accepts data/instrument references, never metrics |
| Entitlement bypass | `ive-quant` EXPERIMENTAL ⇒ admin-only (QB-11); MP-09 forbids an Edge Function for it | `requireModuleAccess` after auth, before work; plan never from body |
| LLM hallucinated numbers | template narratives: figures only via `{{FACT_ID}}`; `renderNarrative` refuses digits, numeric chars, %, number words, unknown/malformed placeholders | narrator output must render or be discarded |
| Future broker credential leakage | no broker code, no credential type, QB-04 forbids execution symbols | credentials only inside a future AEF-governed broker adapter |

## 2. Server authority

Any future Quant Edge Function: JWT required; user derived server-side
(`resolveAuthenticatedUser`); **never** accept `user_id`, `plan`, `role`
or a metric from the client; `requireModuleAccess` before any work
(entitlement-core pattern); quota if it spends provider money.

## 3. Structural tripwires (boundary_test.ts)

* QB-01 every production module is enumerated (a new file must be reviewed).
* QB-02 no `fetch`, `Deno.env`, Deno I/O, WebSocket, XHR, wall clock,
  `Math.random`, `eval` in production modules (comments excluded).
* QB-03 production modules import only sibling Quant modules.
* QB-04 no exported order/broker/trade/execute/submit/rebalance/transfer/
  recommendation symbol.
* QB-10/11/12 `ive-quant` EXPERIMENTAL + CONSEQUENTIAL, denied to every
  non-admin plan, served by no Edge Function.
* QB-20 AEF hard-denies real-money quant tiers.

Mutation check performed during the mission: a file importing IVE Core,
calling `fetch`, reading `Deno.env` and exporting `submitOrder` made
QB-01..QB-04 fail.

## 4. First real market-data provider — requirements

1. Vendor chosen by audit (license for display/redistribution, cost,
   delayed vs real-time terms) — architectural decision, not a code choice.
2. Fixed host allowlist via `safe_fetch.ts`; timeouts; response-size cap.
3. Key in server env only; never logged; never sent to the client.
4. Errors map to `PROVIDER_UNAVAILABLE`, never to an empty successful series.
5. `trust = PROVIDER_REPORTED`, `sourceAsOf` and `adjustment` filled from
   the vendor's own metadata, not assumed.
6. Tests with recorded fixtures; no live calls in the unit suite.

## 5. Regulatory / product boundary

Quant is positioned technically as **financial intelligence, analytics,
research and decision support**. It does not act as, and must not be
described as, a financial/investment adviser, broker or portfolio manager
without legal/regulatory analysis. This is enforced architecturally (no
recommendation type, descriptive-only signals, narrative rules, no
execution path), not by a disclaimer.

## 5a. Codex Gate 1 hardening (summary)

Instrument identity is validated/canonicalized at every entry point
(series, portfolio, watchlist); series are deep-frozen; empty datasets
fail; `sourceAsOf` must agree with the data; non-finite results fail
closed; no price-basis inference. Full list: mission report §41.

## 6. Observability

`quantLogEvent` is the only log shape: analysis id, provider id, instrument
count, dataset size, period, calculation types, freshness, latency, error
code. Built from an allowlist with a safe-token filter, so symbols,
quantities, prices, portfolio composition, document text and keys cannot
be logged (test AN-50).

## 7. Residual risks (accepted, documented)

* **Narrative misattribution**: a narrator can cite a real fact under a
  wrong description (e.g. present volatility as a return). Placeholders
  carry labels, but semantic correctness of prose is not machine-checked.
* **Excluded number words**: "one", "um", "uma", "first", "primeiro" double
  as articles/ordinary words and are not blocked; Roman numerals written
  with Latin letters ("IV") are indistinguishable from words; number words
  in languages other than EN/PT are not detected (the narrator contract
  restricts output to EN/PT). Zero-width/bidi/control characters are
  rejected (Codex Final CXF-02), so split words cannot evade the lexicon.
  Acceptable for the Foundation because no narrator integration exists;
  must be re-assessed at the IVE Quant integration gate (Q6).
* **Forged explanation requests**: `renderNarrative` refuses facts that do
  not look like engine output (CXF-01); the robust fix — an opaque,
  engine-signed request — belongs to the Q6 integration gate.
* **Calendar-naive freshness and gaps** until an exchange calendar exists.
* **Float64 analytics** are not a ledger (see QUANT_CALCULATION_SPEC §1).

## 8. Data plane threat model (IV-QUANT-DATA-PLANE-AND-API-02)

| Threat | Mitigation | Test |
|---|---|---|
| Forged JWT / anon key | `resolveAuthenticatedUser` (GoTrue getUser) | GH-*, QA-40, QW-04 |
| Forged user_id / plan / role / module_access in body | strict schema rejects unknown fields (400) | QA-10, QW-05 |
| Entitlement bypass via API | `requireModuleAccess` before any work; fail closed on source outage | GH-*, QB-13 |
| Entitlement bypass via direct PostgREST (CXA-01) | RLS predicate `quant_watchlists_access_allowed()` + drift test | Q09, Q10, QB-16 |
| Forged / foreign projectId | ownership via caller JWT (API) + RLS WITH CHECK (DB); lookup failure → 503 | QA-41, QW-03, Q02, Q05 |
| Cross-user watchlist | owner RLS; immutable user/project | Q04, Q05, QW-02 |
| Malformed / oversized CSV, NaN/Infinity, timestamps | csv.ts + normalization; body cap streamed | QA-20..22 |
| Calculation DoS | bounded rows/windows, O(n) SMA; measured 358 ms worst case | QA-20, CX1-07, perf |
| Provider poisoning / forged provenance | server-set USER_UPLOAD provenance; no client trust/sourceAsOf | QA-01, QA-10 |
| Stale data shown as fresh | calendar-aware sessions; unknown calendar → naive + warning | QA-30, SF-*, CAL-* |
| Currency mismatch | instrument ↔ provenance currency check | DT-27 |
| SSRF | no URL input, no fetch in Quant EFs | QA-51, QB-14 |
| Vendor-key leakage | no vendor, no key; future provider rules §4 | QB-02 |
| LLM numerical authority | no LLM in either API | QA-51, QB-14 |
| Broker path from analytics | none; AEF deny unchanged | QB-04, QB-14, QB-20 |
| Log leakage | allowlisted events | QA-50, QW-07 |

Legacy commercial LLM-generated numbers: QUANT_LEGACY_LLM_NUMERIC_RISK.md.

## 9. Real-data readiness threat model (IV-QUANT-REAL-DATA-READINESS-03)

| Threat | Control | Evidence |
|---|---|---|
| Request flooding / cost amplification | per-user fixed-window limit in Postgres (SECURITY DEFINER, `auth.uid()`), checked before the body is read | RL-01..05, QB-17, R01–R05, 10-session concurrency proof |
| Rate-limit store outage used to bypass | fail closed → 503 RATE_LIMIT_UNAVAILABLE | RL-03 |
| Forged user id to reset/move counters | identity from JWT only; counter table unreachable (RLS, no policies, revoked) | RL-02, R03/R04 |
| Watchlist analysis reading another user's list | instruments read with the caller JWT (RLS) + user-id filter; invisible list = NOT_FOUND | QM-03, QM-04 |
| Watchlist analysis without watchlist entitlement | second `requireModuleAccess('quant-watchlists')` before the store is touched; fails closed | QM-05 |
| Client-chosen data source / URL (SSRF, provider spoofing) | `data_source` enum = SYNTHETIC_PROVIDER only; unknown fields rejected; no URL accepted | MC-04, QM-04 |
| Provider credential leak | secret only from server env, sent as header, never in URL (`key=`/`token=` refused), never logged | PC-06 |
| Credential following a redirect | `safeFetch` `allowedHosts` re-checked per hop | safe_fetch "allowedHosts" test, PC-02 |
| Malformed / hostile provider payload | adapter identity echo checks, size cap, normalized errors (PROVIDER_MALFORMED) — never an empty success | PC-02, PC-03, PC-04 |
| Cache making stale data look fresh | original provenance preserved, separate cache meta; stale only on provider failure + CACHE_STALE | CA-01, CA-02, MC-06 |
| Cache poisoning across providers / from users | provider-id check; USER_UPLOAD never cached; key built from validated identity only | CA-02, CA-03 |
| Multi-series amplification | ≤ 10 series, ≤ 100 000 rows total, 6 MiB body, rate limit | MS-11, MC-02, MC-03 |
| Misleading cross-currency numbers | per-currency returns + MIXED_CURRENCY_RETURNS; mixed-currency portfolio refused | MS-08 |
| Misleading alignment (filled gaps) | intersection only, dropped bars counted, never filled | MS-06, MS-07 |
| Dev transport shipped to users | `QUANT_API_BASE_URL` honored only in debug and only for loopback http; cleartext config only in `src/debug` | Flutter "dev base URL" test; release builds never read it |
| Hostile file via Android SAF | type decided by name + magic bytes; spreadsheets/JSON NOT_IMPLEMENTED, PDF/images/binary rejected, 5 MiB cap, UTF-8 required; server re-parses anyway | Flutter file-matrix test; physical matrix in QUANT_REAL_DATA_READINESS.md |
