# Module Portfolio — InsightValues

Mission: `INSIGHTVALUES-MODULE-PORTFOLIO-ARCHITECTURE-01`
Branch: `claude/insightvalues-module-architecture` (Module Lab)
Status: AUDIT — built from the repository at Module Lab base `ffd7361`, not from the mission brief.
Gate owner: Agente Martins / Paulo

## 0. Relationship to existing docs (no duplication)

- **Module metadata source of truth stays `lib/core/modules/module_registry.dart`**
  (`kModuleRegistry`, 37 entries) + `route_policy.dart`. This file does NOT
  re-list registry fields; see `docs/commercial/MODULE_LIFECYCLE_MATRIX.md`
  for why the registry is the single metadata source.
- This file adds what the registry does not carry: a **capability-level**
  view (several registry entries collapse into one capability; several
  capabilities have no registry entry at all — AEF, external IVE agent,
  verticals), plus maturity / product-role / surface classification and
  the Three Pillars assessment.

## 1. Classification vocabulary

- **Maturity:** READY · PARTIAL · ARCHITECTURE_ONLY · PLANNED · EXPERIMENTAL · DUPLICATED · DEPRECATED · UNKNOWN
- **Product role:** CORE · COMMERCIAL · PRO · PREMIUM · ENTERPRISE · VERTICAL · EXPERIMENTAL · INFRASTRUCTURE
- **Surface:** ANDROID · WEB · PWA · EXTENSION · BACKEND · IVE · AEF · MULTI-SURFACE

"READY" means: code exists, is wired, has tests or prior mission verification,
and is live in the commercial build. It does NOT mean "promotable to a new
tier" — that is the Promotion Gate's job (`MODULE_PROMOTION_GATE.md`).

`MULTI-SURFACE` below means "Flutter client (Android + Web build from the same
code) + Supabase backend". There is no PWA-specific or Extension code today.

## 2. Capability inventory (45)

### 2.1 Core & infrastructure (12)

| # | Capability | Evidence | Maturity | Role | Surface |
|---|---|---|---|---|---|
| C1 | Auth & Identity (Supabase GoTrue, Google OAuth) | `features/auth`, `auth_service.dart`, `_shared/auth.ts` | READY | CORE | MULTI |
| C2 | Projects / Project Context | `features/projects`, `PROJECT_CONTEXT_CONTRACT.md`, migration `20260919…ownership_boundary_closure` | READY | CORE | MULTI |
| C3 | Knowledge Vault (PDF/DOCX/TXT/CSV, SAF, Google Drive) | `features/knowledge`, `file_import_service.dart`, `drive_service.dart`, EF `process-file`/`extract-knowledge` | READY | CORE | MULTI |
| C4 | Strategy Generation (Knowledge sub-flow) | EF `generate-strategy`, `knowledge_strategies` | READY | COMMERCIAL | MULTI |
| C5 | Usage / AI Quota | `try_reserve_ai_quota`/`refund_ai_quota`, `ai_quota_reservations`, `_shared/quota.ts` | READY | INFRASTRUCTURE | BACKEND |
| C6 | Module Registry + Route Policy | `lib/core/modules/*`, `route_policy_test.dart` | READY | INFRASTRUCTURE | MULTI (client) |
| C7 | Entitlements / Plans | `profiles.role` (`free/pro/premium/beta_tester/admin`), `ModulePlan` (`free/pro/admin`) | PARTIAL | INFRASTRUCTURE | BACKEND+client |
| C8 | Billing (Stripe TEST mode) | EF `create-checkout-session`, `stripe-webhook`, `apply_stripe_subscription_state` | PARTIAL (HOLD) | COMMERCIAL | BACKEND |
| C9 | Admin Panel | `features/admin`, RLS `admin_all_profiles`, `prevent_self_privilege_escalation` | READY | INFRASTRUCTURE | MULTI |
| C10 | Diagnostics / Observability | `lib/core/diagnostics`, `diagnostic_events/_sessions`, build SHA | PARTIAL (forensic, not product analytics) | INFRASTRUCTURE | MULTI |
| C11 | Feature Flags (DB table) | `feature_flags` table, `feature_flag.dart` (6 flags defined; `opportunity_lab_enabled` and `action_engine_enabled` duplicate registry availability) | DUPLICATED (vs `commercialEnabled`) | INFRASTRUCTURE | BACKEND |
| C12 | Intelligence Debug | `features/debug`, admin-gated | READY | INFRASTRUCTURE (internal) | MULTI |

### 2.2 IVE (6)

| # | Capability | Evidence | Maturity | Role | Surface |
|---|---|---|---|---|---|
| I1 | IVE Intelligence (context, interaction contract, issues, event bus, route/project awareness) | `ive_provider.dart`, `ive_context_provider.dart`, `IveInteractionRequest`, `IveIssue`, `ive_event_bus.dart`, `IVE_INTERACTION_AND_QUOTA_CONTRACT.md` | PARTIAL | CORE | IVE (client) |
| I2 | Context Copilot (LLM backend for "Ask IVE") | EF `context-copilot` (identity fields: `project_id`, `source_module`, `source_entity_*`, `correlation_id`) | READY | CORE | MULTI |
| I3 | IVE Visual / Avatar (Flutter fallback, placement engine) | `features/ive/visual`, `ive_placement_engine.dart`, `ive_overlay.dart` | READY | COMMERCIAL | IVE |
| I4 | IVE Rive runtime | `ive_rive_runtime.dart`, `docs/ive/IVE_RIVE_FREEZE_RECORD.md` | DEPRECATED (frozen) | EXPERIMENTAL | IVE |
| I5 | IVE Memory (device-local) | `ive_memory_provider.dart` → `SharedPreferences` | DUPLICATED (vs I6) | CORE | ANDROID/WEB local |
| I6 | Business Memory (server) | `business_memory` table, `business_memory_service.dart` | PARTIAL | CORE | BACKEND |

### 2.3 Intelligence pipeline (10)

| # | Capability | Evidence | Maturity | Role | Surface |
|---|---|---|---|---|---|
| P1 | Website Analyzer | EF `analyze-website` (uses `safe_fetch`), `website_analyses` (**no `project_id`**) | READY (silo) | COMMERCIAL | MULTI |
| P2 | Market Intelligence hub + 6 sub-modules | 7 EFs, `market_analyses` (project-bound, versioned, provenance `source_ids`) | READY | COMMERCIAL | MULTI |
| P3 | Opportunity Lab | `opportunity_lab` (+ `knowledge_item_ids`, `origin/sources/rationale/confidence/risks`) | READY | COMMERCIAL | MULTI |
| P4 | Legacy `opportunities` table | `opportunities.market_analysis_id`, no `project_id` | DUPLICATED (vs P3) | — | BACKEND |
| P5 | Action Engine | `action_queue` (+ `opportunity_lab_id`, same provenance shape), EF `generate-project-actions` | READY | COMMERCIAL | MULTI |
| P6 | OS Command Center | `features/home`, aggregates P2/P3/P5/C3 | READY | COMMERCIAL | MULTI |
| P7 | Business Dashboard | `features/dashboard` | DUPLICATED (overlaps P6; flagged in registry notes) | COMMERCIAL | MULTI |
| P8 | Executive layer (Executive Dashboard, Decision Center, Resource Allocation, Weekly Briefing) | `features/ecosystem`, `features/dashboard`, client-side aggregation | EXPERIMENTAL (registry: beta, not released) | PREMIUM candidate | MULTI |
| P9 | Decision Simulator | EF `decision-simulator`, no UI | PARTIAL | PRO candidate | BACKEND |
| P10 | Advisor Onboarding | `features/advisor`, orphan route | EXPERIMENTAL | EXPERIMENTAL | MULTI |

### 2.4 Content & marketing — post-V1 (8)

All functional, all `commercialEnabled: false` in the registry (route-guarded).

| # | Capability | Maturity | Role | Surface |
|---|---|---|---|---|
| M1 | Improve Post / Content Generation (EF `improve-post`) | READY | PRO candidate | MULTI |
| M2 | Personas / Brands (+ training) | READY | PRO | MULTI |
| M3 | Content Library | READY | PRO | MULTI |
| M4 | Editorial Calendar | READY | PRO | MULTI |
| M5 | Campaigns (EF `generate-campaign`) | READY | PRO candidate | MULTI |
| M6 | Performance (manual metrics, no platform connectors) | READY | PRO candidate | MULTI |
| M7 | ROI Tracker | READY | PRO candidate | MULTI |
| M8 | History (deliberately unclassified route) | READY | COMMERCIAL | MULTI |

### 2.5 Agentic execution (3)

| # | Capability | Evidence | Maturity | Role | Surface |
|---|---|---|---|---|---|
| A1 | AEF v0 (contracts + kernel) | `contracts/aef/*`, `aef/*` — mocks only, in-memory stores, USER identity only, zero runtime callers | PARTIAL (library; not wired) | INFRASTRUCTURE | AEF |
| A2 | `ive-agent-runner` Edge Function | retired stub, returns 410, excluded from deploy allowlist | DEPRECATED | — | BACKEND |
| A3 | IVE Strategic Execution Agent (separate repo `jonnipm-web/insightvalues-ive-agent`, Python/ADK, Cloud Run) | inserts into `action_queue` with the user's JWT (RLS enforced, no service_role) — **outside AEF: no Human Gate, no ExecutionReceipt** | EXPERIMENTAL | EXPERIMENTAL | BACKEND (external) |

### 2.6 Showcase (1)

| # | Capability | Evidence | Maturity | Role |
|---|---|---|---|---|
| S1 | InsightValues Showcase (SHOW-00/01A) | `docs/showcase/*` — mixed statuses ("implementation complete — validation blocked", "blueprint", "awaiting approval") | UNKNOWN | EXPERIMENTAL |

### 2.7 Planned / verticals (5)

| # | Capability | Evidence in repo | Maturity | Role |
|---|---|---|---|---|
| V1 | Social Intelligence & Distribution | Only channel names as strings in Campaigns/Calendar/Knowledge prompts. Zero connectors, zero OAuth to social platforms, zero posting code. | PLANNED | PREMIUM (future) |
| V2 | InsightValues Quant | Registry entry `ive-quant` = NOT_IMPLEMENTED; AEF contract fixtures (`quant-example.json`, `quant-live-without-human-gate.json`) and a hard Quant/Impact domain boundary in `action_classification.ts`. No market data, no broker code. | PLANNED | VERTICAL |
| V3 | InsightValues Impact | AEF fixture `impact-example.json` + domain boundary only. Nothing else. | PLANNED | VERTICAL |
| V4 | Browser Extension | Nothing. | PLANNED | EXPERIMENTAL → future surface |
| V5 | Enterprise Governance (org/workspace/RBAC/SSO) | Nothing — tenancy is `user_id` only. | PLANNED | ENTERPRISE |

## 3. Duplications (5)

| # | Pair | Risk | Disposition |
|---|---|---|---|
| D1 | `feature_flags` DB table ↔ registry `commercialEnabled` | Two availability switches for Opportunity Lab / Action Engine; can disagree. | Module Lab: define one availability authority (see architecture §7). |
| D2 | IVE Memory (SharedPreferences) ↔ `business_memory` (server) | IVE memory does not follow the user across devices/surfaces; blocks Web/Extension IVE. | Candidate for IVE Intelligence Core. |
| D3 | `opportunities` (legacy) ↔ `opportunity_lab` | Legacy table has no `project_id`. | Audit callers before any deprecation migration (not in this mission). |
| D4 | Business Dashboard ↔ OS Command Center | Product overlap already flagged in registry. | Owner product decision. |
| D5 | `projects` ↔ `assets` (+ `parent_asset_id`) | Two "thing the user works on" models; ownership triggers exist for both. | Document; resolve only with a data-model mission. |

## 4. Summary counts

| Metric | Count |
|---|---|
| Capabilities inventoried | 45 |
| CORE role | 7 (C1, C2, C3, I1, I2, I5, I6) |
| COMMERCIAL role | 10 (C4, C8, I3, P1, P2, P3, P5, P6, P7, M8) |
| PARTIAL maturity | 7 (C7, C8, C10, I1, I6, P9, A1) |
| PLANNED | 5 (V1–V5) |
| VERTICALS | 2 (Quant, Impact) |
| DUPLICATED pairs | 5 (D1–D5) |
| DEPRECATED | 2 (I4 Rive, A2 ive-agent-runner) |
| UNKNOWN | 1 (S1) |

## 5. Three Pillars — per capability family

Scale per pillar: **H**igh / **M**edium / **L**ow, with the reason. No numeric scores (arbitrary numbers would imply precision the audit does not have).

| Family | Automation | Monetization | Security readiness |
|---|---|---|---|
| Knowledge (C3) | H — structured ingestion, reusable by every module | M — Core, not sold alone; drives retention | H — auth gate, type allowlist, size cap, zip-bomb guard, prompt-injection delimiter (a1fa942), RLS |
| Market→Opportunity→Action (P2/P3/P5) | H — already produces structured `origin/sources/rationale/confidence/risks/action_steps` | H — the paid "outcome" chain | M — project isolation closed server-side (6941a00); Website Analyzer not project-bound |
| IVE Intelligence (I1/I2) | H — the orchestrator surface | H — the product differentiator | M — context-copilot authenticated + quota; memory is local; no tool execution today (good) |
| AEF (A1) | H (potential) — the only governed execution path | indirect | M — fail-closed kernel, but in-memory only and not wired; external agent (A3) bypasses it |
| Content/marketing (M*) | M | M — classic PRO features | M — standard RLS; no external posting (good) |
| Entitlements (C7/C8) | — | H — gating is the monetization mechanism | L — module availability is client-side only; plan and role share one column |
| Social (V1) | H | H | L — would add third-party OAuth tokens, posting (destructive/public), rate limits |
| Quant (V2) | M | H (separate product) | L — regulated domain; hard boundary exists only in contracts |
| Impact (V3) | M | L–M (ads model) | L — reputational/defamation risk from "corruption signals" |
