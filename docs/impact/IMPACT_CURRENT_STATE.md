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

## 6. I2 — Registry Intelligence (IV-IMPACT-I2-REGISTRY-INTELLIGENCE-01)

| Asset | Classification | Where |
|---|---|---|
| Organization identity (canonical id, conservative resolution, former names, registry conflicts) | EXPERIMENTAL | `_shared/impact/organization_identity.ts` |
| Source lineage / independence (CF-04 closed) | EXPERIMENTAL | `_shared/impact/source_lineage.ts` |
| Registry-statement claims (REGISTRY_RECORD evidence) | EXPERIMENTAL | `_shared/impact/registry_claims.ts` |
| Server registry: 3 SYNTHETIC registries (XA charity, XA company, XB charity) | EXPERIMENTAL | `_shared/impact/provider_registry.ts` |
| Real adapters (Companies House, Charity Commission, IRS EO BMF) behind safe_fetch + host allowlist | written + offline-tested, **NOT enabled** | `_shared/impact_registry/` |
| Migration (lineage columns, snapshot identity, registry conflicts, REGISTRY_RECORD, entity-spoof guard) | EXPERIMENTAL — **not applied to production** | `supabase/migrations/20260925010000_impact_registry_intelligence.sql` |
| DB tests | CI (`disposable-db-rls-ci`) | `supabase/tests/impact_registry_rls_test.sql` |

Decision recorded: SERVICE_ROLE_TRUST_GATE = LAB_ONLY (IMPACT_RLS_MODEL.md §6).
Docs: IMPACT_REGISTRY_INTELLIGENCE · IMPACT_ORGANIZATION_IDENTITY ·
IMPACT_SOURCE_LINEAGE · IMPACT_REGISTRY_SOURCE_DOSSIER.

## 7. I3 — Evidence Collection (IV-IMPACT-I3-EVIDENCE-COLLECTION-01)

| Asset | Classification | Where |
|---|---|---|
| File detection + bounded extractors (PDF, DOCX, XLSX, CSV, JSON, TXT/MD; bounded ZIP) | EXPERIMENTAL | `_shared/impact/artifact_*.ts` |
| Evidence candidates (analyst locator, deterministic value match; PII / minor / injection / subject flags) | EXPERIMENTAL | `_shared/impact/evidence_candidates.ts` |
| Lab actions `ingest_artifact`, `review_candidate` | EXPERIMENTAL (admin-only, EF not deployed) | `_shared/impact/lab_service.ts`, `impact-lab/` |
| Migration (`impact_artifacts`, `impact_evidence_candidates`, artifact-bound evidence rule, 6 audit events) | EXPERIMENTAL — **not applied to production** | `supabase/migrations/20260926010000_impact_evidence_collection.sql` |
| DB tests | CI (`disposable-db-rls-ci`) | `supabase/tests/impact_evidence_rls_test.sql` |

Pre-existing assets audited, not changed: `knowledge_items` (text, no bytes /
hash), `process-file` EF (regex PDF, fflate DOCX), `extract-knowledge` (URL
fetch via safe_fetch — not used by Impact), Flutter `drive_service.dart`
(`drive.readonly`, client-side download). No storage bucket exists or was
created. Docs: IMPACT_EVIDENCE_COLLECTION · IMPACT_ARTIFACT_MODEL ·
IMPACT_FILE_SECURITY.

## 8. I4 — Verification Dossier (IV-IMPACT-I4-VERIFICATION-DOSSIER-01)

| Asset | Classification | Where |
|---|---|---|
| Dossier projection (deterministic, hashed) | EXPERIMENTAL | `_shared/impact/dossier.ts` |
| PT/EN human-readable rendering | EXPERIMENTAL | `_shared/impact/dossier_render.ts`, `dossier_i18n.ts` |
| Lab actions `get_dossier`, `export_dossier`, `verify_dossier` | EXPERIMENTAL (admin-only, EF not deployed) | `_shared/impact/lab_service.ts`, `impact-lab/` |
| Atomic artifact ingestion (I3F-03 closed) | EXPERIMENTAL | `impact_ingest_artifact()` + store bundle |
| Migration (snapshot register, ingestion RPC, DOSSIER_EXPORTED) | EXPERIMENTAL — **not applied to production** | `supabase/migrations/20260927010000_impact_verification_dossier.sql` |
| DB tests | CI (`disposable-db-rls-ci`) | `impact_dossier_rls_test.sql`, `impact_dossier_race_test.sh` |

Discovery: `report.ts` (I1 organization report) and `i18n.ts` were reused
(taxonomy, labels, verdict guard); no Flutter Impact screen exists
(`adminClickable=false`), so no UI was built; no PDF library exists and none
was added. Docs: IMPACT_VERIFICATION_DOSSIER · IMPACT_DOSSIER_SCHEMA ·
IMPACT_DOSSIER_EXPORT · IMPACT_DOSSIER_SECURITY.

## 9. I5 — Product UX (IV-IMPACT-I5-PRODUCT-UX-01)

| Asset | Classification | Where |
|---|---|---|
| Admin-only Flutter dossier UI (`/impact`, `/impact/:id`, claim detail, export/verify) | EXPERIMENTAL (admin/Lab; module stays `inDevelopment`, not commercial) | `lib/features/impact/` |
| Server labels in get/export responses (presentation, outside the hash) | EXPERIMENTAL | `dossier_i18n.ts` `dossierLabels()`, `lab_service.ts` |
| Dossier rate limit (closes I4G3-04) | EXPERIMENTAL — migration **not applied to production** | `rate_limit.ts`, `impact-lab/`, `20260928010000_impact_product_rate_limit.sql` |
| Real-engine UI fixtures + drift test | CI (Impact core) | `_shared/impact/fixtures/ui_fixtures.ts`, `ui_fixtures_test.ts`, `test/fixtures/impact/` |
| DB tests | CI (`disposable-db-rls-ci`) | `impact_rate_limit_test.sql`, `impact_rate_limit_race_test.sh` |
| Flutter tests | CI (`flutter-validation`) | `test/features/impact/` |

Module registry: `impact` now `adminClickable: true`, `route: /impact`
(lifecycle still EXPERIMENTAL ⇒ route policy admits admins only). No
deploy, no public link, no PDF, no score, no AEF action. Docs:
IMPACT_PRODUCT_UX · IMPACT_DOSSIER_UI_CONTRACT · IMPACT_RATE_LIMIT.

## 10. I6 — Privacy fail-closed + validation (IV-IMPACT-I6-PRIVACY-PHYSICAL-VALIDATION-01)

| Asset | Classification | Where |
|---|---|---|
| Field-semantic presentation privacy + identifier backstop (closes I5F-03) | EXPERIMENTAL (Lab) | `_shared/impact/privacy.ts`, used by `dossier.ts` for live view, export, snapshot and text |
| Privacy policy version in the hashed content (`impact-privacy/1`) | contract | `dossier.ts` `policyVersions.privacy` |
| Owner review DTOs marked `OWNER_REVIEW_RAW`, minor data scrubbed | EXPERIMENTAL | `lab_service.ts` |
| Keyboard / focus closure, IVE exclusion regions, authoritative MISMATCH | EXPERIMENTAL (admin UI) | `lib/features/impact/` |
| Tests | CI | `privacy_test.ts` PV-01..33, EF-15, Flutter UI-PRV / UI-KB / UI-IVE / UI-ORI |

Physical Android validation: NOT_AVAILABLE (no device connected during the
mission). No deploy, no production migration, no registry enablement.
Docs: IMPACT_PRIVACY_MODEL (new) · IMPACT_PRODUCT_UX §I6.
