# 29 — Source Evidence Index

Maps chapter claims to evidence. Paths without a prefix are in `ai-social-copilot@ff8ef34` (E-MAIN).
Prefixed paths: `E-INT02:` = `ai-social-copilot@d841ebf`, `E-QUANT:` = `insightvalues-quant@ff6518b`,
`E-AGENT:` = `insightvalues-ive-agent@7f7f46f`, `E-SITE:` = `insightvalues-site@567009a`.
No secrets are indexed.

| Chapter | Claim | Evidence (repo / path) | Kind |
|---|---|---|---|
| 01, 12, 21 | Product LLM is Groq `openai/gpt-oss-120b` | `supabase/functions/context-copilot/index.ts`, 15 other `supabase/functions/*/index.ts` | source |
| 02 | Unmerged lines and SHAs | `E-INT02:INSIGHTVALUES-INTEGRATION-MACRO-02-FINAL-REPORT.md`; `git ls-remote` | report + git |
| 02 | Repo name conflict | `contracts/aef/README.md` | doc |
| 03 | Canonical flow (in-repo) | `docs/commercial/COMMERCIAL_PRODUCT_ARCHITECTURE.md` | doc |
| 03 | Action Engine defects | same doc §3.2–3.3; `lib/data/models/action_queue_item.dart` | doc + source |
| 04 | Untrusted context, grounding, caps | `supabase/functions/context-copilot/index.ts` | source |
| 04 | Display-only action chip | `lib/shared/widgets/context_copilot_widget.dart` | source |
| 04 | Document selection budget | `lib/data/services/document_context_builder.dart`, `test/data/services/document_context_builder_test.dart` | source + test |
| 04 | IVE findings F01–F08 | `E-INT02:docs/architecture/modules/IVE_INTELLIGENCE_CURRENT_STATE.md` | report |
| 04 | Rive frozen | `lib/features/ive/visual/ive_visual_config.dart`, `docs/ive/IVE_RIVE_FREEZE_RECORD.md` | source + doc |
| 05 | Kernel pipeline and tools | `aef/kernel.ts`, `aef/tool_registry.ts`, `aef/policy_evaluator.ts`, `aef/action_classification.ts` | source |
| 05 | Contracts | `contracts/aef/schema/*.v1.schema.json`, `contracts/aef/prohibited_fields.ts` | contract |
| 05 | AEF tests | `aef/kernel_test.ts`, `contracts/aef/validators_test.ts`, `contracts/aef/schema_parity_test.ts` | test |
| 05 | AEF gaps G1–G15, LAB runtime | `E-INT02:docs/architecture/modules/AEF_CURRENT_STATE.md` | report |
| 05, 21 | External agent writes `action_queue` | `E-AGENT:ive_agent/supabase_tools.py`, `E-AGENT:ive_agent/agent.py`, `E-AGENT:README.md` | source + doc |
| 06 | Project ownership closure | `supabase/migrations/20260919000000_project_ownership_boundary_closure.sql` | migration |
| 06 | File ingestion limits | `supabase/functions/process-file/index.ts` | source |
| 06 | Drive scope | `lib/data/services/drive_service.dart` | source |
| 07 | Quant Lab state | `E-INT02:docs/quant/QUANT_CURRENT_STATE.md` | report |
| 07 | Strategy001 contracts | `E-INT02:lib/core/quant/strategy001_contracts.dart`, `E-INT02:docs/commercial/FINANCIAL_INTELLIGENCE_POSITIONING.md` | source + doc |
| 07 | Research results | `E-QUANT:docs/research/qt01research01-diagnostico-completo-v2.md`, `E-QUANT:docs/research/qt01c36-v4-backtest-comparison.md`, `E-QUANT:docs/research/baselines/paulo_trend_fibonacci_v2_real_validated_v1.json` | report |
| 07 | Quant package layout | `E-QUANT:README.md`, `E-QUANT:insightvalues_quant/` | source |
| 08 | Impact Lab | `E-INT02:docs/impact/IMPACT_CURRENT_STATE.md`, `E-INT02:supabase/functions/impact-lab/index.ts` | report + source |
| 09 | No social connectors | grep of `lib/` | source |
| 10, 11 | Tables, RLS, policies | `supabase/migrations/20260907120000_baseline_production_pre_x4r.sql` and 14 later migrations | migration |
| 11 | Role trigger | `supabase/migrations/20260907120001_x4b_search_path_and_role_protection.sql` | migration |
| 11 | Quota RPCs | `supabase/migrations/20260910190000_commercial_ai_quota.sql`, `supabase/migrations/20260918000000_ai_quota_idempotency.sql` | migration |
| 11 | Hardening backlog | `docs/legacy-migrations-archive/POST_BASELINE_HARDENING_BACKLOG.md` | doc |
| 11, 27 | Duplicate migration version | `E-INT02:supabase/migrations/20260924000000_ive_memory_governance.sql`, `E-INT02:supabase/migrations/20260924000000_quant_watchlists.sql` | migration |
| 12 | JWT policy | `supabase/config.toml`, `.github/deploy-allowlist.tsv` | config |
| 12 | Auth / quota / SSRF helpers | `supabase/functions/_shared/auth.ts`, `supabase/functions/_shared/quota.ts`, `supabase/functions/_shared/safe_fetch.ts` | source |
| 12, 23 | Retired runner deployment | `supabase/functions/ive-agent-runner/index.ts`, `docs/ive/SR04_SR05_CLOSURE.md` | source + report |
| 13 | Route policy | `lib/core/modules/route_policy.dart`, `lib/app.dart`, `test/core/modules/route_policy_test.dart` | source + test |
| 13, 23 | Module registry | `lib/core/modules/module_registry.dart`, `lib/core/modules/module_definition.dart` | source |
| 14 | Diagnostic sanitizer | `lib/core/diagnostics/diagnostic_sanitizer.dart` | source |
| 14, 27 | `is_active` not enforced | `lib/data/services/profile_service.dart`; absence in migrations | source |
| 15 | Webhook entitlements (pro 300 / free 5) | `supabase/functions/stripe-webhook/index.ts` | source |
| 15 | Client plan limits | `lib/core/constants/app_constants.dart` | source |
| 15 | UI price copy | `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb` | source |
| 15 | Monetization decisions | `E-INT02:docs/commercial/MONETIZATION_ARCHITECTURE.md` | doc |
| 17 | Static test counts | grep over `test/`, `supabase/functions/`, `aef/`, `contracts/aef/` | source |
| 18 | Workflows | `.github/workflows/*.yml`, `scripts/ci/check_deploy_governance.sh`, `scripts/ci/resolve_deploy_selection.sh` | CI |
| 19 | Out-of-band deploy threat model | `docs/ive/OUT_OF_BAND_DEPLOYMENT_THREAT_MODEL.md` | doc |
| 20 | Source-map pipeline | `.github/workflows/deploy-web.yml`, `tool/stability09o/verify_build_sourcemap.mjs` | CI |
| 21 | Gemini model | `E-AGENT:ive_agent/agent.py` | source |
| 21 | Site nature | `E-SITE:README.md` | doc |
| 22 | Responsive audit | `docs/DESKTOP_RESPONSIVE_AUDIT.md`, `docs/RESPONSIVE_SCREEN_MATRIX.md` | doc |
| 25 | Showcase repository decision | `docs/showcase/SHOW_00_REPOSITORY_BOUNDARY_DECISION.md` | doc |
| 26 | Legacy migrations | `docs/legacy-migrations-archive/README.md` | doc |
