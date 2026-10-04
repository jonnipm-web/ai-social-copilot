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

## Phases 4–35 — Pending

Phases 4–35 are defined in the mission brief and will be executed in sequence. Key blocking conditions:

- **FASE 5 (Real data E2E):** BLOCKED_OWNER (API key needed for live test)
- **FASE 22–24 (Platform productization):** Requires rights GREEN or explicit authorization to proceed under YELLOW
- **FASE 31 (Codex adversarial):** CLASS D — mandatory before production promotion
- **FASE 35 (Production protection):** Agente Martins + Paulo gate

---

## Mission Report (running)

| # | Field | Value |
|---|---|---|
| 1 | Branch | `claude/iv-quant-macro-05` |
| 2 | Base SHA | `7971f7c` (PILOT-04 final) |
| 3 | Mission start | 2026-10-04 |
| 4 | Tests | 217/217 PASS (baseline); post-FASE 3 to be updated |
| 5 | Status | IN PROGRESS — FASE 3 complete; FASE 2/5 BLOCKED_OWNER |
