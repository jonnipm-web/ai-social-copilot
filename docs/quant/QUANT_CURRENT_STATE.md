# InsightValues Quant — Current State (IV-QUANT-FOUNDATION-01 → REAL-DATA-READINESS-03)

Status date: 2026-09-23. Line: **Quant Lab** — branch
`claude/insightvalues-quant-foundation`, worktree `insightvalues-quant`,
base `de94a56` (Module Lab after MODULE-FOUNDATION-AND-ENTITLEMENT-02).

## 1. Git recovery

| Ref | SHA | Relevance |
|---|---|---|
| `origin/main` | `ff8ef34` | not used as base (lacks Entitlement Core) |
| `origin/claude/commercial-experience-closure-16r` | `a1fa942` | Commercial line — untouched |
| `origin/claude/insightvalues-module-architecture` | `de94a56` | Module Lab — **Quant base**; untouched |
| `origin/claude/insightvalues-quant-setup-65c7on` | `068f882` | only prior "quant"-named branch: 1 commit on top of `1784789` adding a CLAUDE.md reporting rule. **No Quant code.** |
| `origin/claude/phase-11h-market-intelligence-integration-p0` | `5ece559` | *business* market intelligence (niche/SEO analysis), not financial markets; 9 unmerged commits |
| `commercial-stability-08-market-intelligence-integrity` | `9ce6801` | already contained in `de94a56`; business market intelligence |

No branch or commit contains financial-market, portfolio, trading, backtest
or market-data code. History search (`quant|financ|portfolio|market.data|trading|backtest|ohlc|stock|volatil`)
returns only AEF contract work, module-portfolio docs and business
"Market Intelligence".

## 2. Baseline decision

`de94a56` was chosen because it is the newest **pushed** commit that
contains Auth, Projects, Knowledge, the Module Registry, the server-side
Entitlement Core (`_shared/entitlement.ts`, `module_policy.ts`) and the AEF
contract + v0 kernel — and nothing from IVE-INTELLIGENCE-CORE-01 (that work
exists only as uncommitted files in the Module Lab worktree and was **not**
copied). No branch was merged to create the Quant Lab.

## 3. Existing Quant assets (inventory)

| # | Asset | Where | Class |
|---|---|---|---|
| 1 | Registry entry `ive-quant` (planned, admin-visible, not clickable) | `lib/core/modules/module_registry.dart` | EXISTING (metadata only) |
| 2 | Server policy `ive-quant` = EXPERIMENTAL / free / CONSEQUENTIAL | `supabase/functions/_shared/module_policy.ts` | EXISTING |
| 3 | AEF contract: `Domain 'quant'`, `QuantExecutionTier` (research, backtest, paper, controlled_live, expanded_live), tier/action consistency, `human_gate_ref` required for live tiers, tier-scoped delegation audience | `contracts/aef/types.ts`, `validators.ts` | EXISTING |
| 4 | AEF v0 kernel hard-denies real-money quant tiers, even with a Human Gate | `aef/action_classification.ts` | EXISTING |
| 5 | AEF fixtures `quant-example.json`, `invalid/quant-live-without-human-gate.json` | `contracts/aef/fixtures/` | EXISTING (test data) |
| 6 | Promotion Gate: Quant execution is class C (Human Gate, AEF persistence, CLASS D review, legal review) | `docs/architecture/modules/MODULE_PROMOTION_GATE.md` | EXISTING (policy) |
| 7 | Rule: financial CSVs enter through Knowledge's SOURCE→VALIDATE→EXTRACT, no module-owned document store | `docs/architecture/modules/MODULE_ARCHITECTURE.md` §6 | EXISTING (policy) |
| 8 | Portfolio entry V2 "InsightValues Quant" | `docs/architecture/modules/MODULE_PORTFOLIO.md` | PLANNED |
| 9 | Target `QuantInterface {strategy, backtestEvidence, robustness, risk, iveAnalysis, decision}` | `docs/showcase/SHOW_00_CAPABILITY_GAP_MATRIX.md` §25 | PLANNED / ARCHITECTURE_ONLY |
| 10 | Generic CSV import (as plain text into Knowledge, no schema) | `lib/data/services/file_import_service.dart` | PARTIAL (not usable as OHLCV) |
| 11 | Branch `claude/insightvalues-quant-setup-65c7on` | remote | LEGACY (name only, no code) |

**Existing Quant assets: 11** (7 EXISTING governance/contract/metadata,
1 PARTIAL, 2 PLANNED, 1 LEGACY). **Financial-market implementation before
this mission: NONE.**

False positives excluded after inspection: `SingleTickerProviderStateMixin`
(animation), `crypto.subtle` (hashing), `provolatile` (Postgres catalog),
"portfolio" in project resource allocation (portfolio of *projects*),
`market-analysis` Edge Function (LLM niche/SEO analysis — see §5).

## 4. What this mission added

`supabase/functions/_shared/quant/` — the Quant Foundation core (pure
TypeScript/Deno, server-side), 102 tests, and `docs/quant/`. See
QUANT_ARCHITECTURE.md.

## 5. Existing *financial-looking* capabilities outside Quant (observation)

`market-analysis`, `revenue-planner` and `decision-simulator` ask an LLM for
revenue ranges, "investment_score" and ROI figures about *business niches*.
Those numbers are LLM-generated, not computed. They are out of Quant scope
and untouched, but they are the opposite of the Quant principle (engine
calculates, LLM explains) and are recorded as an out-of-scope finding.

## 6. Foundation closure (IV-QUANT-DATA-PLANE-AND-API-02, internal gate)

`IV-QUANT-FOUNDATION-01: CONDITIONAL_PASS → PASS` (the Foundation report is
not rewritten; this is the closure evidence):

| Evidence | Result |
|---|---|
| Local suites on 8d429eb | Quant 102/102 · EF 207/207 · AEF 138/138 · deploy governance OK |
| Remote CI (commit 30c804b = 8d429eb + push trigger only) | Edge Function Tests run 35836935956 ✅ (5 jobs) · Flutter Validation run 35836935976 ✅ (analyze 448 infos, 462 tests) |
| Codex recheck (new thread, read-only, post-8d429eb) | PASS WITH FINDINGS — CXF-01/03/04/05/06 hold, CXF-02 partial; 0 P0/P1; CXR-01 (P2, "first/primeiro" residual) DEFERRED to Q6, pinned by test QB-15 |

Remote CI became possible by adding a `push` trigger scoped to
`claude/insightvalues-quant-**` (workflow_dispatch needs the workflow on
the default branch; the lab line does not open PRs to main).

## 7. Data plane + API (IV-QUANT-DATA-PLANE-AND-API-02)

* Module split (Option A, approved): `quant-analytics` READ_ONLY/INTERNAL
  (`quant-analyze`), `quant-watchlists` REVERSIBLE/INTERNAL
  (`quant-watchlists`; split after Codex CXA-02), `ive-quant`
  CONSEQUENTIAL/EXPERIMENTAL with no Edge Function (MP-09 untouched).
* APIs: QUANT_API_CONTRACT.md. Persistence: QUANT_WATCHLIST_MODEL.md.
  Calendars: QUANT_MARKET_CALENDAR.md. Vendors: QUANT_VENDOR_ASSESSMENT.md.
* Lab UI: `/quant-lab` (admin-only), `lib/features/quant_lab/`.
* Legacy risk record: QUANT_LEGACY_LLM_NUMERIC_RISK.md.

## 8. Performance (measured, 5-run median, local Deno 2.9.6)

| Stage | 50 000 daily rows, 2.44 MB CSV, 8 SMA windows (2…50 000), crossover, Sharpe |
|---|---|
| CSV parse | 178 ms |
| normalize + provenance | 57 ms |
| calculate (engine + calendar) | 160 ms |
| full pipeline (JSON → schema → CSV → series → analysis) | 358 ms |
| heap used after runs | 69 MB (RSS 442 MB includes the Deno runtime) |

No optimization was done without a measured need; the worst case is well
inside Edge Function time limits. Memory headroom on the Edge runtime must
be re-measured on the platform before any promotion.

Superseded for READINESS-03 by QUANT_RESOURCE_BUDGET.md (calendar memo fix,
multi-series bound, PLATFORM_RUNTIME_NOT_MEASURED).

## 9. Real-data readiness (IV-QUANT-REAL-DATA-READINESS-03, 2026-09-25)

| Area | Doc |
|---|---|
| Readiness summary + physical Android evidence (S25) | QUANT_REAL_DATA_READINESS.md |
| Rate limits (429) | QUANT_RATE_LIMIT_POLICY.md |
| Provider cache + provenance | QUANT_CACHE_POLICY.md |
| Multi-series analytics | QUANT_MULTI_SERIES.md |
| API contracts v1 / multi.v1 / watchlist.v1 | QUANT_API_CONTRACT.md §7–8 |
| Resource budget (measured) | QUANT_RESOURCE_BUDGET.md |
| Vendor licensing dossier (no winner) | QUANT_VENDOR_LICENSING_DOSSIER.md |
| Threat model update | QUANT_SECURITY_MODEL.md §9 |

Modules unchanged: `quant-analytics` READ_ONLY/INTERNAL, `quant-watchlists`
REVERSIBLE/INTERNAL, `ive-quant` CONSEQUENTIAL/EXPERIMENTAL without Edge
Function. Nothing deployed; no vendor; no real key.
