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
* **Excluded number words**: "one", "um", "uma" double as articles and are
  not blocked; Roman numerals written with Latin letters ("IV") are
  indistinguishable from words.
* **Calendar-naive freshness and gaps** until an exchange calendar exists.
* **Float64 analytics** are not a ledger (see QUANT_CALCULATION_SPEC §1).
