# Module Architecture — InsightValues Core + Module Lab

Mission: `INSIGHTVALUES-MODULE-PORTFOLIO-ARCHITECTURE-01`
Status: §1–§11 were the mission-01 PROPOSAL. §13 (Entitlement Core) is
IMPLEMENTED in Module Lab by MODULE-FOUNDATION-AND-ENTITLEMENT-02 — not
deployed, migration not applied to production. §12.1/§12.2 supersede the
mission-01 status of MPA-F01..F07 (e.g. MPA-F04 re-classified in §12.1).
Gate owner: Agente Martins / Paulo

Companion docs: `MODULE_PORTFOLIO.md` (inventory), `MODULE_DEPENDENCY_MAP.md`
(graph), `MODULE_PROMOTION_GATE.md` (lifecycle + gate). Existing docs this
builds on and does not replace: `docs/commercial/MODULE_LIFECYCLE_MATRIX.md`,
`PROJECT_CONTEXT_CONTRACT.md`, `IVE_INTERACTION_AND_QUOTA_CONTRACT.md`,
`COMMERCIAL_PRODUCT_ARCHITECTURE.md`, `aef/README.md`, `contracts/aef/README.md`.

## 1. Two lines, one Core

```
                 ┌──────────── InsightValues CORE (shared) ────────────┐
                 │ Auth · Projects · Knowledge · Quota · Entitlements  │
                 │ IVE Intelligence · Context Copilot · Module Registry│
                 │ AEF contracts/kernel · Diagnostics                  │
                 └──────────────▲───────────────────────▲──────────────┘
                                │                       │
     COMMERCIAL / STABLE  ──────┘                       └──── MODULE LAB / NEXT
     claude/commercial-experience-closure-16r              claude/insightvalues-module-architecture
     Android release, Play-18, P0/P1 only                   new capabilities, isolated, flag-off
                                │                       │
                                └──── Promotion Gate ◄──┘   (MODULE_PROMOTION_GATE.md)
```

Rules:

1. Module Lab never writes to the commercial branch or `main`.
2. Commercial fixes flow **into** Module Lab by merge from the commercial
   branch (or from `main` once reconciled) at explicit sync points, never the
   other way around without a Promotion Gate.
3. A Module Lab capability reaches users only through the existing registry
   switch (`commercialEnabled`) after its gate — it can ship dark
   (`commercialEnabled: false`, route-denied) long before that.

## 2. Module Lab baseline (decision record)

| Item | Value |
|---|---|
| origin/main | `ff8ef34` |
| Commercial branch head | `a1fa942` (`claude/commercial-experience-closure-16r`) |
| 17A approved checkpoint | `c36edf5` (ancestor of `a1fa942`) |
| Merge-base main↔commercial | `f9c20f7` |
| main-only commits | 20 (AEF contracts + kernel v0, deploy pipeline P0/P1 shell-injection fixes, governance gate) |
| commercial-only commits | 23 (IVE, Android, auth, Knowledge, Play-18 security) |
| Module Lab base | `a1fa942` + merge of `origin/main` → `ffd7361` |

Why not `main`: it lacks the entire 17A Core (447-test commercial state).
Why not `c36edf5`: the two Play-18 commits after it are security hardening
(`ccb065c` disables a compromised keystore pipeline; `a1fa942` adds the
prompt-injection delimiter in `extract-knowledge` + CSV import, physically
verified). Excluding them would leave the lab with an armed compromised
pipeline. Neither commit adds release-signing material.
Why merge `main`: `main` touches zero files under `lib/` — it only adds
`aef/`, `contracts/aef/`, workflow hardening, scripts and docs. The merge
was conflict-free (`git merge-tree`), and AEF is a Module Lab dependency.
Known inheritance: Play-18 is **not concluded**; later Play-18 commits will
reach Module Lab only through an explicit sync merge.

## 3. InsightValues Core — definition

A capability is **Core** when at least two independent modules depend on it
and it owns a security or data boundary. By that rule, Core is:

| Core capability | Owns | Why Core |
|---|---|---|
| Auth & Identity | user identity, sessions | every EF and table |
| Projects / Project Context | project ownership boundary | Knowledge, MI, Opportunity, Action, IVE, Copilot |
| Knowledge | source → normalized content | Opportunity provenance, Strategy, Website, IVE, Copilot |
| Usage / Quota | AI cost reservation/refund | every AI EF |
| Entitlements | plan + module availability | every commercial surface |
| Module Registry + Route Policy | module identity & availability metadata | Admin, drawer, route guard |
| IVE Intelligence + Context Copilot | assistant context, interaction contract | every screen |
| AEF contracts + kernel | governed execution | every future write-capable agent path |
| Diagnostics | forensic telemetry | all |

Not Core (modules that consume Core): Website Analyzer, Market Intelligence,
Opportunity Lab, Action Engine, Content/marketing suite, Executive layer,
Social, Quant, Impact.

## 4. IVE architecture — presentational vs intelligence

| Layer | Components | Reusable by new modules? |
|---|---|---|
| **Presentational IVE** | `features/ive/visual/*` (fallback avatar, status ring, speech anchor), `ive_overlay.dart`, `ive_placement_engine.dart`, `ive_exclusion_region.dart`, intro gate/sheet, detail sheet, explain button | Yes, as-is — modules register exclusion regions / ask-IVE CTAs; they never own avatar code. Rive stays frozen. |
| **Intelligence IVE** | `ive_provider.dart` (state/expressions), `ive_context_provider.dart` (project-scoped context, ecosystem alerts), `IveInteractionRequest` (Ask-IVE contract), `IveIssue` (error taxonomy), `ive_event_bus.dart`, EF `context-copilot` | Yes — `IveInteractionRequest` + `context-copilot` identity fields (`project_id`, `source_module`, `source_entity_type`, `source_entity_id`, `correlation_id`) are already the right shape for any module to ask IVE about its own entities. |
| **Memory** | `ive_memory_provider.dart` (SharedPreferences) and `business_memory` (server) | Gap: device-local memory cannot follow the user to Web/Extension (duplication D2). |
| **Tool access** | none | Correct today. IVE has **no** tool-execution capability in the app; any future tool use must go through AEF (§5). |

IVE Core status: **PARTIAL** — intelligence contract and backend are real;
memory is split and client-bound; route awareness is per-screen
(`IveInteractionRequest` call sites), not a registry-driven capability map;
no tool layer (by design).

## 5. AEF architecture (verified state)

`aef/README.md` + code confirm the historical record is still true on this base:

- Kernel pipeline: identity → contract validation → delegation → policy →
  Human Gate → idempotency → sealed tool registry → mock execution → receipt.
- USER identity verified via GoTrue; SERVICE/SYSTEM = `UNSUPPORTED_BY_V0`, fail-closed (F-02 closed for USER only).
- All stores in-memory; all tools mock; zero network exposure; zero runtime callers (`grep` of `lib/` and `supabase/functions/`).
- F-09 (consequential-action risk taxonomy incl. Impact) still deferred.
- CI: `edge-function-tests.yml` type-checks/lints/tests `contracts/aef` and `aef/` on PRs to `main`.

AEF status: **PARTIAL** (tested library, not a running system).
`IV-AEF-PERSISTENCE-01` remains the planned next AEF mission — not started here.

**Gap found in this audit:** the external IVE Strategic Execution Agent
(`jonnipm-web/insightvalues-ive-agent`, Cloud Run) writes `action_queue`
rows autonomously with the user's JWT. RLS bounds it to the user's own data
(no privilege escalation), but it runs **outside** AEF: no Human Gate, no
ExecutionReceipt, no idempotency guard. This contradicts
`contracts/aef/NO_DIRECT_EXECUTION.md`'s intent. See finding MPA-F04.

## 6. Knowledge as transversal infrastructure

Current pipeline (verified):

```
SOURCE            local file (SAF picker) · Google Drive (drive.readonly) · manual text · URL
 → VALIDATE       auth gate · extension/MIME allowlist (PDF/DOCX/TXT/CSV) · 6 MB cap · DOCX zip-bomb guard
 → EXTRACT        client-side decode (TXT/CSV) · EF process-file (PDF/DOCX) · Drive export for native Docs
 → NORMALIZE      knowledge_items.content + auto_title/auto_type/auto_niche/auto_audience
 → KNOWLEDGE      knowledge_items (RLS, project_id) · knowledge_analysis · knowledge_strategies
 → PROJECT CTX    project_id binding · document_context_builder.dart
 → INTELLIGENCE   extract-knowledge (prompt-injection delimiter) · Opportunity knowledge_item_ids · IVE context · Copilot
```

Knowledge Core status: **PARTIAL** as infrastructure (READY as a commercial feature):
- no chunking/embedding/semantic retrieval — consumers receive whole-document text;
- provenance is recorded on Opportunity (`knowledge_item_ids`) but not uniformly (Website Analyzer links `knowledge_item_id` yet has no `project_id`);
- Drive scope is broader than needed (`drive.readonly`, already flagged in registry notes).

Rule for Module Lab: **no module creates its own document store.** New
sources (e.g. social exports, financial CSVs for Quant) enter through the
same SOURCE→VALIDATE→EXTRACT stages and land in `knowledge_items` with a
`source_type`.

## 7. Entitlements — availability vs usage

**Status after MODULE-FOUNDATION-AND-ENTITLEMENT-02: implemented in Module
Lab — see §13.** Kept here as the problem record from mission 01:

- `profiles.role ∈ {free, pro, premium, beta_tester, admin}` carried both
  authorization role and commercial plan in one column; `premium` had no
  `ModulePlan` counterpart and `ModulePlan.admin` modelled a role as a plan.
- Module availability (`commercialEnabled` + `minimumPlan`) was enforced
  **only in the client**; a free user with a valid JWT could call the Edge
  Function of an unreleased module directly (MPA-F03). Quota and RLS still
  bounded cost and data.
- Two availability switches existed (`feature_flags` table and the registry, D1).

## 8. Security architecture — module threat model

| Threat | Current control (verified) | Gap for Module Lab |
|---|---|---|
| Tenant isolation | RLS enabled on all 45 tables **per migration source** (45 CREATE TABLE, 45 ENABLE ROW LEVEL SECURITY) — static evidence only; live production RLS NOT_VERIFIED in this mission; `user_id` tenancy | No org/workspace tenant — enterprise needs a second isolation axis |
| Project isolation | ownership triggers (`validate_asset_*_ownership`), opportunity↔knowledge server-side filter (6941a00) | `website_analyses`, `copilot_sessions` not project-bound |
| Authorization | `_shared/auth.ts` on every business EF; admin via RLS + anti-self-promotion trigger | module availability client-only (§7) |
| Prompt injection | `<documento_do_usuario>` delimiter in `extract-knowledge` | other EFs that embed user/web content (analyze-website, market-analysis, context-copilot) should adopt the same pattern; no tool execution exists, which bounds blast radius |
| Tool misuse | IVE has no tools; AEF tools are mock + sealed registry | external agent writes outside AEF (MPA-F04) |
| SSRF | `_shared/safe_fetch.ts` (analyze-website, extract-knowledge) | any new fetching module must use it — make it a gate item |
| Data exfiltration | no outbound integrations besides Drive (read) and LLM calls | Social/Impact would add outbound surfaces |
| Secrets | CI secrets; governance deploy allowlist | **compromised KEYSTORE_* secrets still present; compromised pipeline still armed on `main`** (MPA-F01) |
| Admin escalation | `prevent_self_privilege_escalation` trigger, role CHECK | role/plan conflation means billing code writes the authz column (MPA-F03) |
| Cross-module access | modules read each other's tables directly via RLS | no module-level data scopes; acceptable until enterprise |
| Human Gate | AEF v0 only (not wired) | required for any write-capable automation |
| Audit trail | quota reservations, diagnostic events, processed webhook events | no per-action audit log for user-visible automated actions |
| Rate limiting / quota | server-side quota + idempotency | not per-module |

## 9. Module Contract — proposal

The contract **already exists** (`ModuleDefinition`). Proposal: extend it,
do not replace it. New optional fields, all with safe defaults so the 37
existing entries compile unchanged:

```dart
// PROPOSAL ONLY — not implemented in this mission.
final ModuleLifecycle lifecycle;          // EXPERIMENTAL…DEPRECATED (MODULE_PROMOTION_GATE.md); derives today's `status`
final ModuleRiskClass riskClass;          // A (read-only) · B (writes own data) · C (external/destructive/financial)
final List<String> dataScopes;            // tables read/written, e.g. ['knowledge_items:r', 'action_queue:w']
final List<String> toolScopes;            // AEF tool ids this module may request (empty = none)
final List<String> dependsOnModules;      // moduleIds — enables a CI cycle check
final IveIntegration iveIntegration;      // none | askIve | contextProvider | agentTools
final AefIntegration aefIntegration;      // none | receiptsOnly | humanGated
final Set<ModuleSurface> surfaces;        // android, web, pwa, extension, backend
final String? telemetryNamespace;         // diagnostic/analytics event prefix
final String? featureFlag;                // single availability key (replaces feature_flags table usage)
final List<String> migrationDependencies; // migration file names required
```

And one structural change: `minimumPlan` must be mirrored server-side
(§7). Until then, the client registry is presentation + navigation only —
exactly what its own header already says.

## 10. Multi-surface architecture

Flutter already builds Android and Web from one codebase (`deploy-web.yml`
→ GitHub Pages on push to `main`). Business logic is split between
Dart services (client) and Edge Functions (server).

| Capability | Surface-independent today? | Needed for Web/PWA/Extension |
|---|---|---|
| Auth | yes (GoTrue) | extension OAuth flow (chrome.identity) |
| Knowledge ingestion | partially — TXT/CSV decode is client-side Dart | move decode into `process-file` so non-Flutter clients reuse it |
| Market / Opportunity / Action generation | yes (EFs) | none |
| Context Copilot | yes (EF, identity fields) | `source_module` values for "browser page" contexts |
| IVE context assembly | **no** — `ive_context_provider.dart` aggregates in Dart | server-side context endpoint |
| IVE memory | **no** — SharedPreferences | server memory (D2) |
| Module availability | **no** — Dart registry | server entitlement (§7) |
| Quota | yes (RPC) | none |

Browser Extension (not implemented): the minimum surface-independent
contracts it needs are (1) server entitlement check, (2) server-side IVE
context assembly, (3) server-side memory, (4) `context-copilot` accepting a
page-context source with SSRF-safe fetching and the injection delimiter.

## 11. Future enterprise requirements (not for MVP)

organization · workspace · members · org roles (RBAC, later ABAC) · SSO
(SAML/OIDC) · SCIM · org-level audit log · retention policies · data
residency · policy engine · multi-step approval chains (AEF Human Gate is
the natural base) · shared Knowledge per workspace · organizational memory.

Blocking prerequisites already visible: plan/role separation (§7), a tenant
axis above `user_id`, server-side module availability. None should be built
before a paying individual/professional base exists.

## 12. Findings and disposition (Claude audit + Codex round 1)

| ID | Sev | Finding | Codex | Disposition |
|---|---|---|---|---|
| MPA-F01 | P1 | `origin/main` still has the compromised keystore pipeline armed: `build-android.yml` runs on every push to `main` with `secrets.KEYSTORE_*`, `generate-keystore.yml` holds a plaintext password, and the four `KEYSTORE_*` Actions secrets still exist. Fixed only on the commercial line (`ccb065c`), which this branch inherits. | CX-04 | ESCALATED — Owner: delete/rotate `KEYSTORE_*` secrets (neutralizes all three workflows without touching `main`); promote `ccb065c` to `main` through the commercial gate. |
| MPA-F02 | P1 | `ccb065c` and `a1fa942` on the commercial branch are **authored by Codex**. Global governance makes Codex read-only unless a mission explicitly authorizes writes; the authorization is not verifiable from the repo. | — | ESCALATED — Agente Martins to confirm the Play-18 authorization. Content of both commits reviewed and inherited deliberately (§2). |
| MPA-F03 | P1 (architecture) / P2 (current commercial impact) | Module availability and plan are enforced client-side only; no EF checks module × plan (verified: `generate-campaign` authenticates + reserves quota, no entitlement). Today no released module is PRO-only, so the bypass reaches unreleased-but-working modules, bounded by the user's own quota and RLS. | CX-01 (P1) | ACCEPTED. Architecture: hard blocker added to the Promotion Gate (no module with an EF reaches RELEASE_CANDIDATE without server entitlement). Implementation DEFERRED to a dedicated mission (runtime change out of scope here). OPEN. |
| MPA-F04 | P1 (conditional) | External IVE agent writes `action_queue` outside AEF (no Human Gate/receipt/idempotency). Deployment state of the Cloud Run service not verified. | CX-03 | ESCALATED — Owner to confirm whether the service is live; Promotion Gate hard blocker added. OPEN. |
| MPA-F05 | P3 (residual) | Route-classification invariant test was a hand-maintained mirror of `app.dart`, so a new route missing from both lists fell through to "allow" with CI green — false guarantee in `MODULE_LIFECYCLE_MATRIX.md` §2. | CX-02 (P1) | FIXED — new source-derived test in `route_policy_test.dart`. Mutation evidence (Claude, this mission): removing the `/roi-tracker` ownership entry made the new test fail with `Unclassified app.dart routes … [routeRoiTracker (/roi-tracker)]`; file restored. Codex R2: VERIFIED_FIXED (scoped). Residual P3: routes declared outside `lib/app.dart` or via route-list spreads/ShellRoute are not scanned; `module == null` / unknown `moduleId` fail-open is client UX, not an authorization boundary. |
| MPA-F06 | P1 (escalated) | Project-ownership migration (`20260919…`, already on `main`) can leave pre-existing mismatched rows readable/deletable but un-updatable. Pre-existing and self-documented in the migration; affected-row count in production unknown. | CX-05 (P1) | ACCEPTED at Codex's severity (Claude initially P2; agreed after R2 because the production count cannot be verified here). Gate item G14 added. ESCALATED — Owner/Agente Martins: run the read-only preflight query in production. No disagreement left open. |
| MPA-F07 | P2 | AEF tests F-08/N-04 used a fixed 2026-09-18T13:00Z expiry while relying on the real clock → deterministic failure since that instant; CI on `main` fails for any PR touching `aef/` or `supabase/functions/`. | CX-08 (on first fix) | FIXED on Module Lab (fixed far-future instants, no `Date.now()`); 138/138. `main` still affected until synced. |
| MPA-F08 | P2 | Doc inaccuracies: registry count, feature-flag count, RLS evidence level, graph caveats. | CX-06/07/09/10 | FIXED. |
| MPA-F09 | P2 | Project `CLAUDE.md` ("maximum automation… create migrations without asking") is weaker than the global governance policy (owner approval, production protection). | — | RECORDED, not rewritten (mission §07). Global policy prevails. |
| MPA-F10 | P3 | Environment: Flutter 3.47.4 at `~/flutter` not on PATH; Supabase CLI absent; Deno 2.9.6 at `~/.deno`. Main clone and commercial worktree carry uncommitted work. | — | RECORDED; nothing touched. |

### 12.1 Updates from MODULE-FOUNDATION-AND-ENTITLEMENT-02

| ID | Sev (now) | Resolution | Status |
|---|---|---|---|
| MPA-F01 | P1 → OWNER_ACTION | Evidence corrects the `ccb065c` narrative: the four `KEYSTORE_*` secrets (created 2026-07-14 with `fd8e0fb`, a fixed CI key for the Google Sign-In SHA-1) predate `generate-keystore.yml` (2026-07-28, **0 runs**, different secret names). Classified **STALE** legacy CI key, not the Play upload key; still consumed by `build-android.yml` on `main` (91 successful runs, last 2026-09-18). Lab is safe (inherits `ccb065c`: 0 active `secrets.KEYSTORE` references). Transport patch `main-transport/0002-*` applies cleanly to `origin/main`. | Lab: SAFE · main: OWNER_ACTION (delete secrets or promote patch) |
| MPA-F02 | P1 → P3 | The repository's local `.git/config` sets `user.name=Codex`, `user.email=noreply@openai.com` (since 2026-07-18): **234 commits** carry that author, including Claude's own mission-01 commits. `ccb065c`/`a1fa942` were made in the commercial worktree with `Co-Authored-By: Claude Sonnet 5`. Content reviewed on merit and kept. | **METADATA_ONLY**; Owner may fix the repo identity (commits of this mission pass an explicit Claude identity per command) |
| MPA-F03 | P1 | Server-side entitlement authority built and wired into 17/17 module Edge Functions (§13). | FIXED in Module Lab (not deployed) |
| MPA-F04 | P1 → P2 | The external agent only **inserts** suggestions (`action_queue` with `origin: 'ive_agent'`, deterministic id; `business_memory` with a source tag) under the user's own JWT/RLS; no external side effects → AEF class REVERSIBLE (B), not CONSEQUENTIAL (C). No caller in this repo; Cloud Run deployment state NOT_VERIFIABLE (production read not authorized). Class C remains blocked by MP-03. | BLOCKED_BY_GATE |
| MPA-F06 | P1 | The ownership migration is **already applied in production** (version 20260915194037), so the preflight is now a post-hoc check for stuck rows. Read-only aggregate query delivered: `supabase/tests/preflight_ownership_and_entitlement_readonly.sql`. An automated production read was denied by the session's permission policy and not retried. | READY_FOR_OWNER |
| MPA-F07 | P2 | Fix preserved in Lab; transport patch `main-transport/0001-*` applies cleanly to `origin/main`. | AEF_DATE_FIX_READY_FOR_MAIN = YES |
| MPA-F11 | P3 | Pre-existing Deno lint issues in `_shared/quota.ts`, `quota_realdb_test.ts`, `project_ownership_realdb_test.ts` and 6 EF test files (identical on HEAD). | PRE_EXISTING, backlog |

### 12.2 Codex dispositions (MODULE-FOUNDATION-AND-ENTITLEMENT-02)

| ID | Codex sev | Claude evaluation | Resolution |
|---|---|---|---|
| CX1-01 | P1 | Accepted — enforcement not yet wired at Gate 1 (by design of the gate order). | FIXED: 17/17 wired, MP-06 + GH-* |
| CX1-02 | P1 | Accepted — one column cannot hold "paying beta tester" / "admin who subscribes". | FIXED in Lab: `subject_roles` migration + `ProfilePlanAndSubjectRolesSource` behind rollout flag (EN-32/33/34, RLS T09/T10) |
| CX1-03 | P1 | **Rejected as a defect** — existing `beta`-status modules staying admin-only is deliberate legacy preservation (the client already denied them); exposing them is a product decision. | OWNER DECISION (per-module `lifecycleOverride`) |
| CX1-04 | P2 | Accepted. | FIXED: `isSubjectBoundTo` (EN-30/31) |
| CX1-05 | P2 | Accepted. | FIXED: executed harness for all 17 functions (GH-*) |
| CX1-06 | P2 | Accepted — live admin/self-promotion behaviour cannot be verified here. | NOT_VERIFIED (documented §13.11) |
| CX1-07 | P2 | Accepted. | FIXED: pseudonymous `subject_ref`, no raw id/token/body (EN-35). Limitation: the hash is not keyed — anyone who already knows a user UUID can recompute it. |
| CXF-01 | P1 | Accepted — the diff of `generate-keystore.yml` necessarily reproduced the removed hardcoded password. Caught **before push**; the local commit was amended so the literal was never published by this branch. | FIXED: `0003-generate-keystore.yml.replacement` (whole file, literal redacted); 0 literals in 9e9b53f..HEAD |
| CXF-02 | P2 | Accepted. | FIXED: MP-09 (no function of any kind may serve a CONSEQUENTIAL module) + MP-10 (closed allowlist of non-MODULE kinds) |
| CXF-03 | P2 | Accepted. | FIXED: exact code match in `entitlementErrorCode` + collision tests |
| CXF-04 | P3 | Accepted (cheap). | FIXED: invalid `ENTITLEMENT_SUBJECT_ROLES` fails closed with a log line (EN-36) |
| CXF-05 | P2 | Accepted. | FIXED: `scripts/ci/run_disposable_db_tests.sh` + CI job `disposable-db-rls-ci` (PostgreSQL 17 service; refuses non-local hosts); path filter now includes migrations and SQL tests |
| CXF-06 | P3 | Accepted. | FIXED: commercial GH test asserts the source was consulted; mutation (gate removed from `revenue-planner`) fails 4 tests |
| CXV-01 (fix verification) | P2 | Accepted — transport README steps referenced files absent on `main`. | FIXED: extract-then-switch procedure, re-verified |
| CXV-02 (fix verification) | P2 | Partly accepted — the harness proves the gate ran and did not deny, not a full 200 path; full 200 paths with a free subject are exercised by the per-function tests of analyze-website, extract-knowledge, generate-strategy, context-copilot and process-file. | P3 residual (backlog: per-function valid bodies in the harness) |
| CXV-03 (fix verification) | P2 | **Rejected — false positive**: `test-key-ci` (pre-existing on `main`) and the ephemeral CI Postgres password are placeholders that grant access to nothing real. | NO_CHANGE |

## 13. Entitlement Core (MODULE-FOUNDATION-AND-ENTITLEMENT-02)

Implemented in Module Lab. **Not deployed; migration not applied to production.**

### 13.1 Domain model — five separate responsibilities

```
IDENTITY      subject {type, id}        auth.ts resolveAuthenticatedUser (GoTrue)       user today; organization/workspace reserved
ROLE          admin | beta_tester       subject_roles (+ legacy profiles.role)           what you may administer / preview
PLAN          free < pro < premium      profiles.role (Stripe writes it)                 what you paid for
AVAILABILITY  lifecycle + minimumPlan   _shared/module_policy.ts (server manifest)       whether a module is exposed, and to which plan
USAGE         quota per period          _shared/quota.ts + try_reserve_ai_quota          how much you may still consume (unchanged)
```

Rules: ROLE ≠ PLAN · PLAN ≠ AVAILABILITY · AVAILABILITY ≠ QUOTA. Admin and
beta_tester are never plans (`ModulePlan` is now `free/pro/premium`; the old
`ModulePlan.admin` was removed and "admin-only" is expressed by lifecycle).

Request order in every protected Edge Function:
`authenticate → entitlement → quota → operation` (checked by MP-06 and by
the executed harness GH-*).

### 13.2 Server authority

`supabase/functions/_shared/entitlement.ts`:

- `mapLegacyProfileRole` — the only place the legacy column is split
  (free/pro/premium → plan; admin/beta_tester → role on plan free; anything
  else → plan `null` → deny).
- `decideModuleAccess(subject, moduleId)` — pure, deterministic, default deny:
  unauthenticated → `AUTH_REQUIRED`; unknown module → `MODULE_NOT_AVAILABLE`;
  DEPRECATED → `MODULE_DISABLED`; unknown plan → `ENTITLEMENT_UNAVAILABLE`;
  admin → allow; EXPERIMENTAL/INTERNAL → `MODULE_NOT_AVAILABLE`;
  ALPHA/BETA/RC → beta_tester required; plan below minimum → `PLAN_REQUIRED`.
- `requireModuleAccess(req, user, moduleId, cors, source?)` — the one call
  each module EF makes; any exception or an unbound subject → 503, fail closed.
- `isSubjectBoundTo` — a source's answer must be exactly the authenticated
  user, from a known source, with a real plan and known roles (Codex CX1-04).
- Nothing from the request body or custom headers is read to decide access.

### 13.3 Lifecycle → access

| Lifecycle | free | pro | premium | beta_tester (own plan) | admin |
|---|---|---|---|---|---|
| COMMERCIAL | by plan | by plan | by plan | by plan | allow |
| RELEASE_CANDIDATE / BETA / ALPHA | deny | deny | deny | allow if plan ≥ minimum | allow |
| INTERNAL / EXPERIMENTAL | deny | deny | deny | deny | allow |
| DEPRECATED | deny | deny | deny | deny | deny |

Admin policy: admins reach every non-deprecated module, **server-side and
audited** (`ADMIN_ROLE` decisions are always logged) — parity with the
legacy client route guard, not a new privilege. Beta policy: beta_tester is
never an implicit pro/premium.

Existing registry mapping (derived, legacy-preserving): released →
COMMERCIAL; planned/inDevelopment → EXPERIMENTAL; disabled → DEPRECATED;
every other unreleased module → INTERNAL (admin-only, exactly as the client
already behaved). No module is BETA today; exposing the executive layer to
beta testers is an Owner product decision (explicit `lifecycleOverride`).

### 13.4 Single source of truth and drift

- The server manifest (`module_policy.ts`, JSON block) is authoritative for
  lifecycle / minimumPlan / actionClass and the Edge Function → module map.
- The Flutter registry stays authoritative for presentation.
- `test/core/modules/server_module_policy_drift_test.dart` fails CI if the two
  disagree (ids, lifecycle, plan, commercialEnabled ⇔ COMMERCIAL, EF names).
- `contracts/entitlements/decision_vectors.v1.json` (105 cases) must be
  satisfied by **both** the server decision (`entitlement_vectors_test.ts`)
  and the client route guard (`entitlement_parity_test.dart`).

### 13.5 Feature flags vs entitlement vs registry vs quota

| Concept | Owns | Where |
|---|---|---|
| Module registry | what a capability is (identity, presentation) | `module_registry.dart` |
| Entitlement | who may use it (plan, role, lifecycle) | `module_policy.ts` + `entitlement.ts` |
| Feature flag | operational rollout / kill switch — never a grant | `feature_flags` table (legacy; 2 of 6 flags duplicate availability = debt D1); `ENTITLEMENT_SUBJECT_ROLES` env |
| Quota | how much may be consumed | `quota.ts` (unchanged) |

A feature flag may only narrow what entitlement allows. D1 is not refactored
in this mission (no functional need for the Entitlement Core).

### 13.6 Edge Function enforcement matrix (21)

| Kind | Functions | Entitlement |
|---|---|---|
| MODULE (17) | analyze-website, competitor-discovery, content-cluster, context-copilot, decision-simulator, extract-knowledge, gap-analysis, generate-campaign, generate-project-actions, generate-project-opportunities, generate-strategy, improve-post, market-analysis, niche-discovery, opportunity-discovery, process-file, revenue-planner | `requireModuleAccess` — **17/17 wired**, static (MP-06) + executed (GH-*) |
| ENTITLEMENT (1) | module-access (new) | the discovery endpoint itself; auth required |
| BILLING (1) | create-checkout-session | auth only — upgrade must stay reachable (parity with `kAlwaysAllowedRoutes`) |
| PUBLIC_WEBHOOK (1) | stripe-webhook | Stripe signature, no user |
| RETIRED (1) | ive-agent-runner | 410 for everyone |

Intended behaviour change vs production: direct calls to `generate-campaign`,
`improve-post` (INTERNAL) and `decision-simulator` (EXPERIMENTAL) by
non-admins now get 403. No commercial screen calls them (their only callers
are route-denied screens); the project bootstrap calls `revenue-planner`,
`generate-project-opportunities` and `generate-project-actions`, all
COMMERCIAL/free.

### 13.7 Error contract

`{ "error": CODE, "module_id": ..., "required_plan"?: ..., "correlation_id": ... }`
— `AUTH_REQUIRED` 401 · `MODULE_NOT_AVAILABLE` 403 · `MODULE_DISABLED` 403 ·
`PLAN_REQUIRED` 403 · `ENTITLEMENT_UNAVAILABLE` 503. `QUOTA_EXCEEDED` (429) is
unchanged and separate. Lifecycle and internal reasons are never returned.
Flutter translates the codes in `core/utils/snackbar_utils.dart`. Audit
lines log a pseudonymous `subject_ref`, never the raw id, token or body.

### 13.8 Client, IVE and AEF boundaries

- The Flutter route guard mirrors server semantics for UX (lifecycle,
  premium, beta) and is **not** a security boundary. An unresolved profile
  never unlocks a paid or beta route.
- IVE capability discovery: `module-access` EF → `EntitlementService` →
  `serverModuleAccessProvider` (`ServerModuleAccess`, default-deny cache). IVE
  offers only `allowedModuleIds` and never infers entitlement from the UI; an
  error means "nothing extra", never "everything". Not yet consumed by a
  screen (no new autonomous tools in this mission).
- AEF boundary: entitlement answers "may this subject use this capability";
  AEF answers "may this action execute, with which approval and receipt".
  Future flow: `IDENTITY → ENTITLEMENT → MODULE → AEF POLICY → HUMAN GATE → TOOL → RECEIPT`.
  `actionClass` (READ_ONLY / REVERSIBLE / CONSEQUENTIAL — AEF's own taxonomy)
  is promotion metadata, not runtime enforcement; MP-03 blocks any
  CONSEQUENTIAL module from RC/COMMERCIAL while `AEF_PERSISTENCE_AVAILABLE = false`.

### 13.9 Storage, migration and rollback

Migration `20260923000000_entitlement_subject_roles.sql` (Lab only): additive
`public.subject_roles`, RLS select-own, no client writes, backfill of existing
admin/beta_tester, idempotent. `profiles.role` untouched and still written by
Stripe as the PLAN. Verified on a disposable PostgreSQL 17 with all 17
migrations applied: `supabase/tests/entitlement_subject_roles_rls_test.sql`
(owner, non-owner, anon, self-grant, service_role, CHECKs, billing rewrite)
PASS, mutation-checked (a permissive SELECT or INSERT policy makes it fail).

Controlled rollout: (1) Owner runs the read-only preflight
`supabase/tests/preflight_ownership_and_entitlement_readonly.sql`;
(2) apply the migration; (3) deploy the EFs with the default legacy source;
(4) set `ENTITLEMENT_SUBJECT_ROLES=1` to read roles from the new table.
Rollback — **order matters**: first unset the flag everywhere (instant),
then redeploy previous EF versions if needed, and only then
`DROP TABLE public.subject_roles` (nothing else depends on it). Dropping the
table while any function still has the flag set denies every protected
call (fail closed, an outage — never a grant).

CI: `edge-function-tests.yml` job `disposable-db-rls-ci` applies every
migration to a PostgreSQL 17 service container and runs the RLS test via
`scripts/ci/run_disposable_db_tests.sh` (which refuses any non-local host). No user is
reclassified at any step. Revoking a role = remove it from `subject_roles`
and from `profiles.role` if it is a legacy role there.

### 13.10 Tenancy (future-proofing, not tenant-ready)

`subject_type` is part of the subject and of the `subject_roles` primary key;
the CHECK allows only `user`. Organization/workspace needs membership, scope
and data isolation in the decision — not built (YAGNI). `isSubjectBoundTo`
rejects non-user subjects until then.

### 13.11 Verified vs not verified

VERIFIED (Module Lab): decision logic, default deny, forged client state,
subject binding, 17/17 EF wiring executed, client/server parity, registry
drift, RLS of the new table on a disposable database, legacy role mapping.
NOT_VERIFIED: production RLS, deployed EF behaviour, live admin/self-promotion
trigger behaviour, Supabase log retention/access for the audit lines, the
CI jobs on GitHub until a run on this branch completes.

Cost: each protected call adds one primary-key read of the caller's own
`profiles` row (plus one `subject_roles` read once the flag is on) before
quota — the same order of magnitude as the existing quota RPC.
