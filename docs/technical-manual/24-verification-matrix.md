# 24 — Documented × Verified Matrix (anti-drift)

Columns: DOCUMENTED = an in-repo doc claims it; SOURCE / TEST / DEPLOYMENT / PRODUCTION VERIFIED =
what this mission could confirm. `Y` = verified this mission; `N` = checked and not true;
`R` = reported by another mission only (`HISTORICAL_EVIDENCE_ONLY`); `—` = not checked /
`ENVIRONMENT_BLOCKED`. TEST VERIFIED = tests exist (static); nothing was executed.

LAST VERIFIED SHA/DATE = `ff8ef34` / 2026-09-28 unless another SHA is written.

| CAPABILITY | DOCUMENTED | SOURCE VERIFIED | TEST VERIFIED | DEPLOYMENT VERIFIED | PRODUCTION VERIFIED | LAST VERIFIED SHA | LAST VERIFIED DATE |
|---|---|---|---|---|---|---|---|
| Real-user auth gate on all AI functions | Y (`deploy-allowlist.tsv`, `auth.ts`) | Y (16/16 AI EFs + billing) | Y | R (AUTH-01 reports) | R | `ff8ef34` | 2026-09-28 |
| `verify_jwt=true` except `stripe-webhook` | Y | Y (`config.toml`) | Y (deploy-selftest) | R | R | `ff8ef34` | 2026-09-28 |
| Atomic monthly AI quota + idempotency | Y | Y | Y | R | — | `ff8ef34` | 2026-09-28 |
| RLS on every table | Y | Y (45/45) | Y (SQL suites, historical) | — | R (baseline captured from prod) | `ff8ef34` | 2026-09-28 |
| Anti-self-promotion trigger | Y | Y | Y | R ("verified live" in quota migration header) | R | `ff8ef34` | 2026-09-28 |
| Project-ownership WITH CHECK (market_analyses, opportunity_lab) | Y | Y | Y (realdb test file) | — | — | `ff8ef34` | 2026-09-28 |
| Project-ownership on all project-bound tables | implied by `PROJECT_CONTEXT_CONTRACT.md` | **N** (7 tables lack it) | N | — | — | `ff8ef34` | 2026-09-28 |
| SSRF protection on user URLs | Y | Y | Y (31) | R | — | `ff8ef34` | 2026-09-28 |
| IVE cannot execute actions | Y | Y (display-only chip) | partial | — | — | `ff8ef34` | 2026-09-28 |
| IVE session isolation on logout | Y (E-INT02 IVE-F01 fix) | **N** on E-MAIN | N | — | — | `ff8ef34` | 2026-09-28 |
| AEF v0 fail-closed kernel | Y | Y | Y (63 + 75 static) | N (not deployable) | N | `ff8ef34` | 2026-09-28 |
| AEF wired into runtime | "not wired" | Y (no callers) | — | N | N | `ff8ef34` | 2026-09-28 |
| AEF persistence / LAB runtime | Y | Y (E-INT02 files exist) | Y (E-INT02 static) | N ("not applied") | N | `d841ebf` | 2026-09-28 |
| Server-side module entitlements | Y (E-INT02) | N on E-MAIN; Y on E-INT02 | Y (E-INT02) | N | N | `d841ebf` | 2026-09-28 |
| Growth modules commercial at Pro | Y (E-INT02 monetization doc) | N on E-MAIN | — | N | N | `ff8ef34` | 2026-09-28 |
| Stripe checkout + webhook | Y | Y | Y | R ("implemented and deployed", TEST) | — | `ff8ef34` | 2026-09-28 |
| Stripe live mode | N ("HOLD") | N | — | N | — | `ff8ef34` | 2026-09-28 |
| Pro quota value | Y (300 in webhook; 100 in constants) | Y — `CONFLICTING_EVIDENCE` | — | — | — | `ff8ef34` | 2026-09-28 |
| `is_active` deactivation | implied by admin UI | **N** (not enforced) | N | — | — | `ff8ef34` | 2026-09-28 |
| `ive-agent-runner` retired (410) | Y | Y | N | R (v6, 2026-09-17) | R | `ff8ef34` | 2026-09-28 |
| Rive frozen, fallback avatar | Y | Y (`enabled = false`) | Y (32) | Y (in Web build) | — | `ff8ef34` | 2026-09-28 |
| Web deploy to GitHub Pages on merge | Y | Y (workflow) | — | R (workflow runs not inspected) | — | `ff8ef34` | 2026-09-28 |
| Edge Function deploy governance | Y | Y | Y (deploy-selftest) | — | — | `ff8ef34` | 2026-09-28 |
| Migrations applied to production | Mixed ("NOT APPLIED" at authoring) | — | — | — | — | — | `UNKNOWN` |
| Quant Lab analytics | Y | Y (E-INT02) | Y (static) | N | N | `d841ebf` | 2026-09-28 |
| Strategy001 engine | Y | Y (E-QUANT) | Y (static) | N/A | N/A | `ff6518b` | 2026-09-28 |
| Paulo Trend Fibonacci V10 / Strategy #001 | owner brief only | — | — | — | — | — | `ENVIRONMENT_BLOCKED` |
| Robot Builder / Strategy Lab / Validation Engine | owner brief only | — | — | — | — | — | `ENVIRONMENT_BLOCKED` |
| Impact verification dossier | Y | Y (E-INT02) | Y (static) | N | N | `d841ebf` | 2026-09-28 |
| Social publishing | N | N | N | N | N | `ff8ef34` | 2026-09-28 |
| Broker / live trading | N | N (AEF hard deny) | Y (deny tests) | N | N | `ff8ef34` | 2026-09-28 |
| External ADK agent writes `action_queue` | Y (E-AGENT README) | Y (`supabase_tools.py` inserts) | Y (static) | R ("Production E2E Verified") | — | `7f7f46f` | 2026-09-28 |
| Groq `openai/gpt-oss-120b` is the product LLM | Y | Y (16 functions) | — | — | — | `ff8ef34` | 2026-09-28 |
| i18n PT/EN | Y | Y (145 keys each) | — | Y (Web build) | — | `ff8ef34` | 2026-09-28 |
| iOS client | — | N | N | N | N | `ff8ef34` | 2026-09-28 |

Update rule: when a macro changes any row, it must update that row's SHA/date or mark it stale.
