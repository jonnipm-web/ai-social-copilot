# InsightValues Quant — Current State (IV-QUANT-FOUNDATION-01)

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
TypeScript/Deno, server-side), 96 tests, and `docs/quant/`. See
QUANT_ARCHITECTURE.md.

## 5. Existing *financial-looking* capabilities outside Quant (observation)

`market-analysis`, `revenue-planner` and `decision-simulator` ask an LLM for
revenue ranges, "investment_score" and ROI figures about *business niches*.
Those numbers are LLM-generated, not computed. They are out of Quant scope
and untouched, but they are the opposite of the Quant principle (engine
calculates, LLM explains) and are recorded as an out-of-scope finding.
