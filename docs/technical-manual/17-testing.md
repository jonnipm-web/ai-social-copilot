# 17 — Test Architecture

All counts below are **static declaration counts** (grep of `test(`/`testWidgets(`,
`Deno.test(`, `def test_`) — **not** pass/fail results. This mission did not execute test
suites. Reported pass counts from other missions are `HISTORICAL_EVIDENCE_ONLY`.

## 1. Static inventory — E-MAIN

DATE 2026-09-28 · SHA `ff8ef34` · SCOPE `ai-social-copilot@main`

| Suite | Location | Files | Static declarations | Runs in CI? |
|---|---|---|---|---|
| Flutter unit/widget/integration | `test/` | 37 | 392 | Yes — `flutter-validation.yml` (PR to main) |
| Deno — Edge Functions + `_shared` | `supabase/functions/**/*_test.ts` | 15 | 205 | **Partially** — `edge-function-tests.yml` runs only `context-copilot/index_test.ts` and `_shared/quota_test.ts` |
| Deno — AEF kernel + adapter | `aef/*_test.ts`, `aef/adapters/*_test.ts` | 2 | 63 | Yes — job `contract-and-aef-ci` |
| Deno — AEF contracts | `contracts/aef/validators_test.ts`, `schema_parity_test.ts` | 2 | 75 (65 + 10) | Yes |
| SQL authorization / fingerprint | `supabase/tests/*.sql` | 4 | n/a (PASS/FAIL notices) | Only via `x4r-authorization-matrix.yml` (branch-restricted push + manual) |
| Real-DB Deno tests | `_shared/quota_realdb_test.ts`, `project_ownership_realdb_test.ts` | 2 | 23 | No (need a database) |

Not run in CI on E-MAIN (static evidence): `_shared/auth_test.ts` (11), `safe_fetch_test.ts` (31),
`stripe_test.ts` (10), `language_test.ts` (6), `stripe-webhook/index_test.ts` (17),
`process-file/index_test.ts` (10), `create-checkout-session` (5), `analyze-website` (5),
`extract-knowledge` (5), `generate-campaign` (5), `generate-strategy` (5). → R-TEST-01.

Functions with **no** tests: `competitor-discovery`, `content-cluster`, `decision-simulator`,
`gap-analysis`, `generate-project-actions`, `generate-project-opportunities`, `improve-post`,
`market-analysis`, `niche-discovery`, `opportunity-discovery`, `revenue-planner`, `ive-agent-runner`.

Security/adversarial coverage on E-MAIN: AEF security matrix + confused-deputy + concurrency
(`aef/kernel_test.ts`), contract adversarial matrix, SSRF matrix, quota idempotency/replay, Stripe
signature/ordering, route-policy completeness, diagnostic sanitizer, IVE auth/intro gates.

## 2. Static inventory — other baselines

| Baseline | DATE / SHA | Suite | Static count |
|---|---|---|---|
| E-INT02 | 2026-09-28 / `d841ebf` | Flutter `test/` | 633 |
| E-INT02 | same | Deno `supabase/functions/` | 864 |
| E-INT02 | same | Deno `aef/` + `contracts/` | 238 |
| E-INT02 | same | `supabase/tests/` files | 29 |
| E-QUANT | 2026-09-28 / `ff6518b` | pytest `def test_` | 2496 |
| E-AGENT | 2026-09-28 / `7f7f46f` | pytest `def test_` | 103 |

Reported (not re-run) results: E-INT02 final report — Flutter 656/656, Deno functions 956/956,
AEF+contracts 182/182 passing; disposable-PostgreSQL RLS suite **NOT RUN** ("no local PostgreSQL 17").
E-QUANT README claims "1212 testes, 95% cobertura" (older text; the static count is now higher).
All `HISTORICAL_EVIDENCE_ONLY`.

## 3. Other verification systems

| System | Evidence | Status |
|---|---|---|
| Build gates | `flutter analyze --fatal-warnings`, `flutter build web --release` (gate only) on PR | `IMPLEMENTED` |
| Source-map verification | `tool/stability09o/verify_build_sourcemap.mjs` in `deploy-web.yml` | `IMPLEMENTED` |
| SPA route-restore check | `scripts/ci/verify_spa_hash_restore.mjs` | `IMPLEMENTED` |
| Deploy-governance self-test | `deploy-selftest.yml` | `IMPLEMENTED` |
| Physical-device tests | E-DOC only (e.g. "Physical E2E Gate 05", Samsung S25 closures on Quant/Impact lines, `build-debug-device-test.yml` builds a debug APK) | `HISTORICAL_EVIDENCE_ONLY` |
| Codex adversarial reviews | Recorded in READMEs/reports (AEF rounds 1–4, INT02 audit) | `HISTORICAL_EVIDENCE_ONLY` |
| Integration tests against a live backend | none automated | `NOT_IMPLEMENTED` |
