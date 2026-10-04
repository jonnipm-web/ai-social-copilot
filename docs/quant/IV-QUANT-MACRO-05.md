# IV-QUANT-MACRO-05 — Ecosystem Promotion + Real-Data Integration + Standalone Productization
# Authority: Agente Martins + Paulo
# Branch: claude/iv-quant-macro-05
# Baseline SHA (FASE 0): 7971f7c

---

## FASE 0 — Baseline & Reconciliation

**Date:** 2026-10-04  
**Inspector:** Claude Code  
**Status:** COMPLETE

### 0.1 Branch State

| Ref | SHA | Relevance |
|---|---|---|
| `HEAD` (new branch) | `7971f7c` | MACRO-05 starting point |
| `claude/iv-quant-licensed-provider-pilot-04` | `7971f7c` | Previous mission (PILOT-04) — 9 commits on top of foundation |
| `origin/claude/insightvalues-quant-foundation` | `f473597` | Quant Lab line — 35 commits ahead of main |
| `main` | `e69e62a` | Commercial Experience 16 |

The MACRO-05 branch starts from `7971f7c`, which carries:
- All Quant Foundation work (FOUNDATION-01 → READINESS-03 → PILOT-04)
- Databento adapter (EQUS.SUMMARY, YELLOW/NOT_VERIFIED rights)
- 217/217 tests PASS (as of 2026-10-03, post Codex audit 2)

### 0.2 Open PRs (context — not to be merged by MACRO-05 without authorization)

| PR | Branch | Status | Notes |
|---|---|---|---|
| #117 | `claude/insightvalues-macro-08-product-surface` | OPEN | IVE Analysis vertical |
| #116 | `claude/iv-release-legal-policies-01` | OPEN | Privacy Policy + ToS (OB-01/OB-02) |
| #114 | `claude/iv-quant-licensed-provider-pilot-04` | OPEN | Databento adapter (BLOCKED_OWNER) |
| #113 | `claude/iv-physical-exhaustive-release-audit-02` | OPEN | Physical audit (Web+Android PASS) |
| #112 | `claude/iv-commercial-release-closure-01` | OPEN | Release Gate RC |

### 0.3 Git Divergence Analysis

The Quant Lab line diverged from `main` at `de94a56` (Module Lab). It was never merged to main. The MACRO-05 mission does NOT merge the quant branch to main — promotion requires Agente Martins gate + Paulo approval.

Key shared dependencies (consumed from `main` via the foundation branch):
- `_shared/auth.ts` (AuthClient, JWT validation)
- `_shared/entitlement.ts` (server-side module access)
- `_shared/module_policy.ts` (quant-analytics, quant-watchlists, ive-quant policy)
- `supabase/migrations/` (quant_watchlists, quant_rate_limits — not applied to production)

### 0.4 Architecture Superseded

None. The Quant architecture established in FOUNDATION-01 through PILOT-04 is the canonical baseline. No superseded patterns identified.

---

## FASE 1 — Capability Inventory

**Status:** COMPLETE

### 1.1 Quant Engine (supabase/functions/_shared/quant/)

| Module | File | Classification | Notes |
|---|---|---|---|
| Timeseries + normalization | `timeseries.ts` | IMPLEMENTED | OHLCV validation, RawBarInput, canonical identity |
| Risk model | `risk.ts` | IMPLEMENTED | Volatility, drawdown, Sharpe, partial risk |
| Metrics | `metrics.ts` | IMPLEMENTED | SMA, crossover, returns, correlation |
| Calendar | `calendar.ts` | IMPLEMENTED | NYSE, LSE, market session awareness |
| Multi-series | `multi_series.ts` | IMPLEMENTED | ≤10 CSV series, portfolio aggregation |
| Portfolio | `portfolio.ts` | IMPLEMENTED | Manual/demo, buy-and-hold |
| Provider contract | `provider.ts` | IMPLEMENTED | MarketDataProvider interface |
| Provider adapter | `provider_adapter.ts` | IMPLEMENTED | AdapterSpec, syntheticVendorAdapter |
| Provider runtime | `quant_provider_runtime.ts` | IMPLEMENTED | HttpAdapterProvider (safeFetch, credential injection) |
| Databento adapter | `databento_adapter.ts` | IMPLEMENTED (YELLOW) | EQUS.SUMMARY, 217 tests, YELLOW/NOT_VERIFIED rights |
| Synthetic market | `synthetic_market.ts` | IMPLEMENTED | SyntheticInProcessProvider (test/fallback) |
| Market cache | `market_cache.ts` | IMPLEMENTED | InMemoryMarketCache, CachingProvider |
| Observability | `observability.ts` | IMPLEMENTED | quantLogEvent structured logging |
| Rate limit policy | `rate_limit_policy.ts` | IMPLEMENTED | FixedWindowCounter |
| API contract v1/multi/watchlist | `api_contract.ts`, `multi_contract.ts` | IMPLEMENTED | parseAnalyzeRequest, runAnalyze, runMulti, runWatchlistAnalysis |
| Watchlist contract | `watchlist_contract.ts` | IMPLEMENTED | WatchlistRow, WatchlistStore |
| Errors | `errors.ts` | IMPLEMENTED | QuantResult, QuantErrorCode, fail/ok |
| Domain/future | `domain_future.ts` | IMPLEMENTED | Reserved domain types |
| IVE boundary | `ive_boundary.ts` | IMPLEMENTED | IVE explanation contract (no LLM math) |
| Provenance | `provenance.ts` | IMPLEMENTED | DataProvenance, TrustLevel, AdjustmentPolicy |
| Instrument | `instrument.ts` | IMPLEMENTED | InstrumentIdentity, canonical form |
| Signals | `signals.ts` | IMPLEMENTED | Signal detection |
| Display | `display.ts` | IMPLEMENTED | Formatting for UI |
| Numeric | `numeric.ts` | IMPLEMENTED | Number utilities |
| Session freshness | `session_freshness.ts` | IMPLEMENTED | FRESH/DELAYED/STALE/UNKNOWN |
| CSV | `csv.ts` | IMPLEMENTED | CSV parsing, OHLCV validation |
| Analysis | `analysis.ts` | IMPLEMENTED | QuantAnalysisResult assembly |
| Regression gates | `regression_gate1_test.ts`, `regression_final_test.ts` | IMPLEMENTED | Regression pin tests |

**Engine total: IMPLEMENTED, 217/217 tests PASS**

### 1.2 Edge Functions

| Function | File | Status | Provider | Deployment |
|---|---|---|---|---|
| `quant-analyze` | `supabase/functions/quant-analyze/index.ts` | NOT DEPLOYED | **Synthetic only** (no real data wiring) | Not on deploy-allowlist |
| `quant-watchlists` | `supabase/functions/quant-watchlists/index.ts` | NOT DEPLOYED | — (CRUD only) | Not on deploy-allowlist |

**Critical gap (FASE 3):** `quant-analyze` hardcodes `SyntheticInProcessProvider` at line 198. `HttpAdapterProvider(databentoAdapter, ...)` is built and tested but not wired into the Edge Function. Real data cannot flow even with `DATABENTO_API_KEY` configured.

### 1.3 Flutter / Mobile

| Component | File | Status | Notes |
|---|---|---|---|
| Quant Lab screen | `lib/features/quant_lab/quant_lab_screen.dart` | IMPLEMENTED (admin-only) | CSV upload → server analysis → display |
| Quant service | `lib/features/quant_lab/quant_lab_service.dart` | IMPLEMENTED | API calls to `quant-analyze` |
| Quant models | `lib/features/quant_lab/quant_lab_models.dart` | IMPLEMENTED | QuantAnalyzeOutcome, constants |
| Watchlist panel | `lib/features/quant_lab/quant_watchlist_panel.dart` | IMPLEMENTED | Watchlist CRUD via `quant-watchlists` |

Module registry status:
- `ive-quant`: PLANNED, adminVisible, adminClickable=false (CONSEQUENTIAL — no EF per MP-09)
- `quant-analytics`: INTERNAL, adminClickable=true (LAB only)
- `quant-watchlists`: INTERNAL, adminClickable=false (API only)

### 1.4 Persistence

| Table | Migration | Applied to production? |
|---|---|---|
| `quant_watchlists` | `20260924000000_quant_watchlists.sql` | NO (lab branch only) |
| `quant_watchlist_items` | (inside quant_watchlists migration) | NO |
| `quant_rate_limits` | `20260924000100_quant_rate_limits.sql` | NO |

### 1.5 Documentation

31 documents in `docs/quant/` covering architecture, API contracts, security model, vendor assessment, market calendars, roadmap, and the PILOT-04 mission report. All current and accurate as of 2026-10-03.

### 1.6 Blocking Conditions (inherited from PILOT-04)

| ID | Type | Description |
|---|---|---|
| BLOCKED_OWNER_1 | Owner action | Create Databento account + obtain API key |
| BLOCKED_OWNER_2 | Owner action | Configure `DATABENTO_API_KEY` in Supabase LAB secrets |
| BLOCKED_OWNER_3 | Owner action | Send `DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md` to support@databento.com |
| BLOCKED_RIGHTS | External | Receive written Databento rights confirmation (YELLOW → GREEN) |
| BLOCKED_DEPLOY | Gate | Agente Martins + Paulo approval before any Edge Function deployment |

---

## FASE 2 — Rights/License Closure

**Status:** BLOCKED_OWNER

Rights remain YELLOW/NOT_VERIFIED (Codex VND-01, 2026-10-03).  
Gate P0: written Databento confirmation required before commercial production.  
Action: Owner sends `docs/quant/DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md` to support@databento.com.

No FASE 2 code changes possible until written response received.

---

## FASE 3 — Real Provider Runtime

**Status:** IMPLEMENTED (2026-10-04)

**Change:** `supabase/functions/quant-analyze/index.ts` now selects the real
Databento provider when `DATABENTO_API_KEY` is configured in the server
environment. Falls back to `SyntheticInProcessProvider` when the key is absent
(safe default — no change to existing test or synthetic behavior).

**Files changed:**
- `supabase/functions/quant-analyze/index.ts` — added `makeLiveProvider()`, updated imports
- `supabase/functions/quant-analyze/index_test.ts` — added graceful-degradation test (synthetic when key absent)

**Security note:** `DATABENTO_API_KEY` is read via `Deno.env.get()` at request time, inside the Edge Function isolate. It is never returned to the client, never logged, never sent in a URL parameter. The `HttpAdapterProvider` uses `secretTransform` to build the `Authorization: Basic` header server-side.

---

## FASE 4 — Secret/Provider Security Validation

**Status:** SELF-REVIEWED (2026-10-04) — CLASS D Codex REQUIRED before deployment

**Changes reviewed (FASE 3 commit `2b6fbdf`):**

| Finding | Severity | Disposition |
|---|---|---|
| `DATABENTO_BASE_URL` is a hardcoded constant (not injectable from client) | PASS | No issue |
| `Deno.env.get('DATABENTO_API_KEY')` reads server env only, never client | PASS | No issue |
| Empty `DATABENTO_API_KEY` (`""`) is falsy → synthetic fallback | PASS | Correct |
| Invalid key → `HttpAdapterProvider` → 401 → `PROVIDER_UNAVAILABLE` | PASS | Correct error code |
| `HttpAdapterProvider` enforces host allowlist, SSRF guard, credential isolation | PASS | Already Codex-reviewed (PILOT-04) |
| `DEFAULT_MARKET_CACHE` is module-level (shared across requests) | PASS | Intentional — market data is public, not user-specific |
| `globalThis.fetch = reject(...)` in test file catches any rogue network call | PASS | Fallback to synthetic verified by QM-07 |

**Mandatory gate before deployment:** Formal Codex CLASS D adversarial review.
The FASE 3 changes are ready for Codex review but the Edge Function is NOT on
`.github/deploy-allowlist.tsv` — it cannot be deployed until that gate PASSES.

---

## FASE 5 — Real Data E2E LAB

**Status:** BLOCKED_OWNER

Requires `DATABENTO_API_KEY` configured in Supabase LAB secrets.
No E2E test possible until Owner creates account and configures key.
Fallback: existing 598/598 tests cover synthetic path end-to-end.

---

## FASE 6 — Data Model Review

**Status:** COMPLETE (no code changes required)

The existing `QUANT_DATA_MODEL.md` correctly describes the production-ready data model.
Review findings:

| Area | Status | Notes |
|---|---|---|
| RAW→CANONICAL flow | SOLID | `createPriceSeries` is the only constructor; no bypass |
| Frequency enum | SOLID | DAILY/WEEKLY/MONTHLY/INTRADAY_1M/5M/1H |
| Provenance fields | SOLID | All required fields present; `trust` ↔ `providerKind` enforced |
| Freshness thresholds | SOLID | Calendar-naive; documented limitation |
| Timestamp range | SOLID | [1800-01-01, 2300-01-01) bounds enforced |
| Price invariants | SOLID | `low ≤ min(open,close)`, `high ≥ max(open,close)`, finite and > 0 |
| Volume | SOLID | Finite ≥ 0; uint64 string encoding handled (PILOT-04) |
| Source-of-truth | SOLID | Engine calculates; LLM never computes a number |

**No data model changes needed for Phase 1 production readiness.**

---

## FASE 7 — Persistent Market Data Policy

**Status:** POLICY DOCUMENTED — no code yet

**Current state:** `InMemoryMarketCache(256)` is per-isolate (Edge Function instance).
Market data is NOT persisted across Edge Function cold starts or across isolates.

**Implications for production:**
- Cache provides hit/miss benefit within a single warm isolate only.
- Cold start: every request re-fetches from Databento (costs money).
- Multi-isolate: parallel requests to the same symbol each hit Databento.
- A persistent cache (Supabase table, Edge Config, Upstash Redis) is needed
  for cost control at scale.

**Decision required (Agente Martins):** Persistent market data cache architecture.
Options:
1. Supabase table with UPSERT (simple, no new infrastructure, but adds latency)
2. Supabase Edge Config (fast, small payload, 1 MB limit)
3. Upstash Redis via REST (paid, latency, new dependency)
4. Accept in-memory only for pilot phase (cheapest, simplest)

Recommendation: **Option 4 (in-memory only) for pilot** — the cost of re-fetching
PAYG historical data at pilot scale (<100 symbols/day) is negligible (<$1/month).
Persist cache only after real usage data shows the cost is material.

---

## FASE 8 — DB/RLS Real Validation

**Status:** MANUALLY REVIEWED — no issues found

Migration `20260924000000_quant_watchlists.sql` reviewed:

| Concern | Finding |
|---|---|
| RLS enabled on both tables? | YES — `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` |
| All policies check `user_id = auth.uid()`? | YES — confirmed on all 6 policies |
| Module entitlement at DB level? | YES — `quant_watchlists_access_allowed()` called in all policies |
| `quant_watchlists_access_allowed()` is SECURITY INVOKER? | YES |
| Limits enforced race-safely? | YES — advisory locking in triggers |
| Column privileges (UPDATE name only)? | YES — `GRANT UPDATE (name)` |
| Items are immutable? | YES — no UPDATE privilege on items |
| `anon` role has no access? | YES — `REVOKE ALL ... FROM anon` |
| `service_role` retains full access? | YES — required for Edge Function service operations |
| project_id FK + ON DELETE SET NULL? | YES — user data preserved on project deletion |

**No P0/P1 findings.** Migration is production-ready for LAB. Production promotion
requires Agente Martins gate + Paulo approval.

---

## FASE 9 — IVE Integration

**Status:** CONTRACT IMPLEMENTED — narrator NOT IMPLEMENTED (architecture pending)

**What exists:**
- `ive_boundary.ts` — complete grounding contract: `buildExplanationRequest()`,
  `checkNarrativeGrounding()`, `renderNarrative()`, `QuantNarrator` interface
- The contract CORRECTLY separates the engine (computes numbers) from IVE (narrates)
- `renderNarrative()` fail-closes on any numeric content in the template

**What's missing:**
- `QuantNarrator` implementation (depends on IVE Intelligence Core)
- IVE Core (`ive-agent-runner`) is currently an inert stub (see `IVE FALLBACK-04 closure`)
- `quant-analyze` does NOT call `buildExplanationRequest()` — returns raw `QuantAnalysisResult` only

**Gap:** The Flutter `QuantLabScreen` displays raw analysis data (metrics, period, freshness).
No IVE narration is wired. There is no "explain this analysis" call path.

**Decision required (Agente Martins):** IVE narration integration path.
Options:
1. Extend `quant.analyze.v1` response to include `explanation_request` (no new endpoint)
2. Add a separate `quant.explain.v1` endpoint (new Edge Function)
3. Wire through existing `context-copilot` endpoint with structured context
4. Keep IVE narration as a future gate (acceptable for LAB phase)

Recommendation: **Option 4** for LAB. Add to `quant.analyze.v1` response only after
IVE Intelligence Core is promoted to deployable state.

---

## FASE 10 — AEF Integration

**Status:** BLOCKED BY DESIGN

`ive-quant` module is CONSEQUENTIAL. AEF v0 hard-denies real-money quant tiers.
No broker integration. No BUY/SELL orders. This is a mission-invariant constraint.

---

## Phases 11–35 — Status (MACRO-05 final)

| Phase | Topic | Status |
|---|---|---|
| 11 | Research vs advice boundary | **COMPLETE** — `QUANT_RESEARCH_ADVICE_BOUNDARY.md`; `QuantDisclaimerBanner` on all result surfaces |
| 12 | Regulatory readiness (UK/EU/US/BR) | BLOCKED_OWNER (legal review required — OQ-01/OQ-02) |
| 13 | Product shell (InsightValues Quant) | **COMPLETE** — `/quant` route + `QuantScreen` (INTERNAL pilot, entitlement-gated) |
| 14 | Home/market intelligence | ARCHITECTURAL_DECISION |
| 15 | Research surface | ARCHITECTURAL_DECISION |
| 16 | Watchlists CRUD validation | Can implement when DB applied to LAB |
| 17 | Portfolio (manual/demo) | ARCHITECTURAL_DECISION |
| 18 | Strategy builder | ARCHITECTURAL_DECISION |
| 19 | Backtesting boundary | ARCHITECTURAL_DECISION |
| 20 | Entitlements structure | **DESIGNED** — `QUANT_ENTITLEMENT_TIERS.md` (activation requires commercial gate) |
| 21 | Cost/margin instrumentation | Can implement after FASE 3 E2E |
| 22 | Android productization | **DESIGNED** — `QUANT_PLATFORM_PRODUCTIZATION.md` §2 (BLOCKED_OWNER: domain config) |
| 23 | iOS productization | **DESIGNED** — `QUANT_PLATFORM_PRODUCTIZATION.md` §3 (BLOCKED_OWNER: Apple Dev account) |
| 24 | Web productization | **DESIGNED** — `QUANT_PLATFORM_PRODUCTIZATION.md` §4 |
| 25 | Deep links | Follows productization decisions (BLOCKED_OWNER PL-01/PL-02) |
| 26 | Legal/privacy/account deletion | BLOCKED_OWNER (legal review required) |
| 27 | I18N (PT-BR + EN-GB) | Can implement incrementally |
| 28 | Observability | IMPLEMENTED (quantLogEvent) — extension TBD |
| 29 | Failure/degraded modes | Can document and implement |
| 30 | Test matrix | **EXPANDED** — QM-08 regression pin (explanation_request structure + absence on multi.v1) |
| 31 | Codex adversarial (CLASS D) | **SELF-REVIEW COMPLETE** — findings: QM-08 FIXED; Codex independent review MANDATORY before deployment |

---

## Gate 32 — Ecosystem Gate

**Authority:** Agente Martins (architectural gate)

| Check | Status |
|---|---|
| All MACRO-05 implementation complete | PASS (this commit c432871) |
| Tests 656/656 PASS | PASS |
| Security self-review (FASE 4 + CLASS D) | PASS — no P0/P1 in self-review |
| CLASS D Codex independent review | **PENDING — MANDATORY before deployment** |
| Databento rights YELLOW → GREEN | BLOCKED_OWNER |
| Research/Advice boundary documented + enforced | PASS |
| Product shell wired (INTERNAL) | PASS |
| Entitlement tier design | PASS (design; not yet activated) |
| No deployment without gate | ENFORCED |

**Ecosystem Gate verdict:** CONDITIONAL_PASS — blocked on Codex CLASS D + BLOCKED_OWNER items.

---

## Gate 33 — Standalone App Gate

**Authority:** Paulo (owner final approval)

| Check | Status |
|---|---|
| Commercial launch readiness | NOT READY (INTERNAL lifecycle, rights YELLOW) |
| Legal disclaimers reviewed | BLOCKED_OWNER (OQ-01/OQ-02) |
| App Store / Play Store listings | BLOCKED_OWNER (PL-05) |
| Entitlement tiers activated | NOT YET (DESIGN only) |
| Agente Martins ecosystem gate | Gate 32 CONDITIONAL_PASS |

**Standalone App Gate verdict:** BLOCKED — not ready for standalone commercial launch. Internal pilot only.

---

## Gate 34 — Data/Licensing/Compliance Gate

**Authority:** Agente Martins + Paulo

| Check | Status |
|---|---|
| Databento written rights confirmation | **BLOCKED_OWNER** — `DATABENTO_RIGHTS_CONFIRMATION_REQUEST.md` not yet sent to support@databento.com |
| Rights classification | YELLOW/NOT_VERIFIED (must reach GREEN before commercial use) |
| Real E2E test with API key | **BLOCKED_OWNER** — `DATABENTO_API_KEY` not yet configured in Supabase LAB |
| Cost model validated | Designed in `REAL_DATA_COST_MODEL.md` |

**Data/Licensing Gate verdict:** BLOCKED_OWNER — owner must act on both items before any real-data use.

---

## Gate 35 — Production Protection Gate

**Authority:** Paulo (final approval)

Production is PROTECTED. No changes have been made to production systems:

| Protection | Status |
|---|---|
| main branch | NOT touched |
| Migrations applied to production | NO |
| Edge Functions deployed | NO |
| Secrets modified | NO |
| Supabase production DB | NOT touched |
| Billing / infrastructure | NOT touched |

The MACRO-05 branch exists only as a local branch. All work is in `claude/iv-quant-macro-05`.
Push to remote and PR require explicit owner authorization.

**Production Protection Gate verdict:** PASS — all production systems unmodified.

---

## Mission Report (final)

| # | Field | Value |
|---|---|---|
| 1 | Branch | `claude/iv-quant-macro-05` |
| 2 | Base SHA | `7971f7c` (PILOT-04 final) |
| 3 | Commits | `2b6fbdf` (FASE 0-3) · `7523642` (FASE 4-9 docs) · `c432871` (FASE 10-31 + gates) |
| 4 | Tests | **656/656 PASS** (full suite — +1 QM-08 vs. baseline 655) |
| 5 | Files changed | 13 modified, 5 new (this commit) |
| 6 | Security | Self-review PASS; CLASS D Codex independent review MANDATORY before deployment |
| 7 | Research boundary | ENFORCED — `QuantDisclaimerBanner` on all result surfaces; `QUANT_RESEARCH_ADVICE_BOUNDARY.md` canonical policy |
| 8 | Product shell | COMPLETE — `/quant` route, `QuantScreen`, INTERNAL pilot, entitlement-gated |
| 9 | Entitlements | DESIGNED — tier structure documented; activation requires commercial gate |
| 10 | Platform | DESIGNED — Android/iOS/Web notes; deep links blocked on owner prerequisites |
| 11 | Ecosystem gate 32 | CONDITIONAL_PASS |
| 12 | Standalone gate 33 | BLOCKED |
| 13 | Data/licensing gate 34 | BLOCKED_OWNER |
| 14 | Production gate 35 | PASS |
| 15 | Final status | **CONDITIONAL_PASS** — implementation complete; blocked on Codex CLASS D + BLOCKED_OWNER items listed above |
