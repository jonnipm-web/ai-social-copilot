# 26 — Legacy / Deprecation Register

Purpose: stop future agents from resurrecting obsolete architectures.

| Component | Classification | Replaced by / reason | Do NOT | Evidence |
|---|---|---|---|---|
| "AI Social Copilot" single-post app + root `README.md` | `SUPERSEDED` | InsightValues business OS; README still describes Anthropic + 2 migrations | Follow README setup steps (migration names and LLM are wrong) | `README.md` vs `supabase/functions/improve-post/index.ts` |
| Anthropic Claude in `improve-post` | `SUPERSEDED` | Groq `openai/gpt-oss-120b` | Re-add provider keys per README | grep |
| Groq `llama-3.3-70b-versatile` | `SUPERSEDED` | `openai/gpt-oss-120b` | Cite the Aug-2026 gap matrix as current | `SHOW_00_CAPABILITY_GAP_MATRIX.md` §20 |
| Legacy migrations 001–021 (+ duplicate 001) | `DEPRECATED` (archived) | Canonical baseline `20260907120000` | Replay them; they diverge from production | `docs/legacy-migrations-archive/` |
| Recursive `profiles_admin_select/update` policies | `DEPRECATED` (never live) | `admin_all_profiles` | Recreate | baseline header |
| `ive-agent-runner` original implementation (branch `release/phase-10-stabilization`) | `FROZEN` / `DEPRECATED` | 410 stub; future AEF | Redeploy v5 or treat as spec | `docs/ive/SR04_SR05_CLOSURE.md` |
| Context Copilot as a standalone "copilot" product | `ABSORBED` | IVE overlay | Build a second assistant | registry `context-copilot` |
| Action Engine as execution | `LEGACY` semantics (status queue only) | AEF (future) | Add real side effects to Action Engine without AEF | `COMMERCIAL_PRODUCT_ARCHITECTURE.md`, E-INT02 report |
| `copilot_sessions/messages/context` tables | `LEGACY` (dead) | in-memory transcript | Write new code against them without a decision | E-INT02 IVE-F08 |
| `opportunities` table | `LEGACY` (duplicate) | `opportunity_lab` | Extend it | `MODULE_PORTFOLIO.md` D3 |
| `feature_flags` table for module availability | `LEGACY` (duplicate authority) | registry `commercialEnabled` (E-MAIN), server manifest (E-INT02) | Add new flags there for modules | D1 |
| Client email-based admin auto-promotion (`profile_service.dart`) | `LEGACY` (neutralized by trigger) | Admin role via admin panel / SQL | Rely on it | `profile_service.dart`, migration 022 |
| `build-android.yml` ("LEGACY — GERAR APK") | `LEGACY` (still active on push to main) | `build-apk.yml` | Add secrets or steps to it | workflow name |
| `test-context-copilot.yml` deploy capability | `DEPRECATED` (removed) | `deploy-edge-functions.yml` | Re-add a second deploy route (governance gate fails) | workflow header |
| Rive avatar runtime | `FROZEN` | `IveVisualFallback` | Flip `IveRiveFeatureGate.enabled` on a commercial branch | freeze record |
| Old Market Intelligence (business niche/SEO LLM analysis) vs Financial Intelligence | Distinct, `CURRENT` | — | Treat Market Intelligence numbers as financial computation | E-INT02 `QUANT_CURRENT_STATE.md` §5 |
| IVE Invest / `ive-quant` placeholder | `SUPERSEDED` by Quant Lab (E-INT02) + E-QUANT | — | Build Quant code inside `ive-quant` placeholder | registry |
| Standalone Quant (`insightvalues-quant`) vs integrated Quant Lab | Both exist; `RECOVERED` contracts only (Dart mirror) | — | Port Python logic without its tests | `FINANCIAL_INTELLIGENCE_POSITIONING.md` |
| E-QUANT legacy `backtest/`, `portfolio/`, `strategy/base.py` | `DEPRECATED` | official pipeline | Use signal-based modules | E-QUANT README |
| `insightvalues-quant` branch `claude/insightvalues-quant-setup-65c7on` (also in this repo) | `LEGACY` (name only) | — | Treat as Quant code | `QUANT_CURRENT_STATE.md` |
| Standalone agents (ADK agent) vs AEF-governed execution | `EXPERIMENTAL` outside AEF | AEF runtime | Extend the agent's write tools without AEF | E-AGENT |
| Showcase repository plan | `PLANNED` never executed | — | Assume `insightvalues-showcase` exists | ADR-019 |
| Growth vs Social Copilot | Growth `CURRENT`; Social Copilot `SUPERSEDED` | — | — | ch. 09 |
| Multiple unmerged mission branches (≈70) | Mostly `ABSORBED` or `SUPERSEDED` | E-INT02 / main | Branch new work from a stale mission branch | `git ls-remote` |
