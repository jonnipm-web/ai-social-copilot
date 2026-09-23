# InsightValues Impact — Current State (IV-IMPACT-FOUNDATION-01)

Discovery date: 2026-09-23. Repo: `jonnipm-web/ai-social-copilot`.
Impact Lab: branch `claude/insightvalues-impact-foundation`, worktree
`C:\Users\jpaul\insightvalues-impact`, base `de94a56` (Module Lab —
Foundation & Entitlement 02, pushed, Codex-closed).

## 1. Git recovery

| Line | Ref | SHA |
|---|---|---|
| origin/main | `origin/main` | `ff8ef34` |
| Commercial | `claude/commercial-experience-closure-16r` | `a1fa942` |
| Module Lab | `claude/insightvalues-module-architecture` (pushed) | `de94a56` (worktree has uncommitted IVE Intelligence work — not used) |
| Quant Lab | `claude/insightvalues-quant-foundation` (local) | `452997b` (child of `de94a56`) |
| Impact base | — | `de94a56` |

No branch or commit mentioning impact / charity / ngo / nonprofit / donation /
social-impact existed before this mission (`git log --all -i --grep`,
`git branch -a`, `git ls-remote`).

## 2. Baseline decision

`de94a56` is the newest **pushed, gate-closed** commit that already contains
Auth, Projects, Knowledge, Module Registry and the server-side Entitlement
Core. Rejected alternatives:

- Module Lab HEAD: has uncommitted IVE Intelligence Core work (unstable, parallel line).
- Quant `452997b`: not pushed; would couple Impact to Quant's Foundation.
- `origin/main`: lacks the Entitlement Core.

No merge or cherry-pick was performed to form the baseline.

## 3. Asset inventory

Search terms: impact, charity, ngo, nonprofit, foundation, donation, campaign,
evidence, verification, trust, claim, source, fraud, scam, corruption, social,
beneficiary, organization, audit, registry, news, Knowledge — across `lib/`,
`supabase/functions/`, `supabase/migrations/`, `test/`, `docs/`, `aef/`,
`contracts/`, branches and commits.

| Asset | Classification | Notes |
|---|---|---|
| Social-impact domain (organizations, claims, evidence, verification) | **NONE** | Zero code. Hits for "impact" are marketing impact/effort scores (`market_analysis.dart`, `ecosystem_intelligence_service.dart`) — unrelated. "campaign" = marketing campaigns module — unrelated. |
| Entitlement Core (`_shared/entitlement.ts`, `module_policy.ts`) | **EXISTING** — reused | Impact registered as module `impact`, EXPERIMENTAL (admin-only). |
| SSRF guard (`_shared/safe_fetch.ts`) | **EXISTING** — reused | Pure URL/IP checks used for reference validation; no fetch in Impact. |
| AEF v0 kernel + contracts (`aef/`, `contracts/aef/`) | **EXISTING** — boundary only | Impact class C maps to CONSEQUENTIAL; not wired (no executor). |
| Knowledge Vault ingestion (`extract-knowledge`, `process-file`) | **EXISTING** — future reuse | Owner-scoped ingestion + prompt-injection boundary already exist; Impact does not rebuild ingestion. |
| Projects + ownership RLS (`20260919000000_project_ownership_boundary_closure.sql`) | **EXISTING** — future reuse | Investigation↔Project binding modelled, not persisted. |
| Quant Foundation (`_shared/quant/`) | **EXPERIMENTAL**, other line | Pattern reference only (read via `git show`); no dependency. |
| IVE Intelligence Core | **PARTIAL**, other line (uncommitted) | Not depended on; future adapter only. |
| Impact core (`_shared/impact/`) | **EXPERIMENTAL** — created by this mission | See IMPACT_ARCHITECTURE.md. |

## 4. Baseline tests (before any runtime change)

| Suite | Result |
|---|---|
| `flutter analyze --fatal-warnings --no-fatal-infos` | PASS (0 errors, 0 warnings, 448 infos) |
| `flutter test` | PASS 462/462 |
| Deno (`_shared/`, `module-access/`, `aef/`, `contracts/aef/validators_test.ts`) | PASS 346/346 (real-DB tests self-skip without a DB) |

## 5. I1 — Persistence + RLS (IV-IMPACT-I1-PERSISTENCE-RLS-01)

| Asset | Classification | Where |
|---|---|---|
| Lab persistence (8 tables, RLS, invariants, trigger-written audit) | EXPERIMENTAL — **not applied to production** | `supabase/migrations/20260924010000_impact_lab_persistence.sql` |
| Server-side provider registry (closes CF-06) | EXPERIMENTAL | `_shared/impact/provider_registry.ts` |
| Lab contract / store / service | EXPERIMENTAL | `_shared/impact/lab_{contract,store,service}.ts` |
| `impact-lab` Edge Function (admin-only) | EXPERIMENTAL — **not deployed** | `supabase/functions/impact-lab/` |
| DB tests (RLS + invariants, engine-row parity) | CI (`disposable-db-rls-ci`) | `supabase/tests/impact_lab_rls_test.sql`, `impact_lab_engine_rows.ts` |

Docs: IMPACT_PERSISTENCE_MODEL · IMPACT_RLS_MODEL · IMPACT_LAB_API ·
IMPACT_PROVIDER_REGISTRY.
