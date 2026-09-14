# Implementation Roadmap

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Implements: mission brief Sections 33, 34

## 0. Sequencing note

The mission brief's suggested phase order (Foundations → Project
Experience → Intelligence → Decision/Execution → Commercial Shell →
Visual/I18N) is **kept as proposed**, with one adjustment: the research
in this mission found the Market Intelligence project/Knowledge wiring
(Phase C) and the Opportunity Lab/Action Engine defect fixes (Phase D)
both depend on the Project Context Contract (Phase A) being in place
first — that dependency was implicit in the brief and is made explicit
below. No other reordering is proposed; repo evidence supports the
brief's sequence.

## Phase A — Foundations

**Scope**:
- `ProjectContext` value object + `iveContextDataProvider` becomes
  `.family`-keyed (see `PROJECT_CONTEXT_CONTRACT.md`).
- `CopilotContextData` gains identity fields; all 6 existing
  `showCopilotChat` call sites updated to pass explicit context.
- AI processing state enum (IDLE…RETRYABLE_ERROR) introduced; applied
  to the 8 identified AI-triggering screens.
- Quota confirmation dialog + audit event sequence (see
  `IVE_INTERACTION_AND_QUOTA_CONTRACT.md`).
- Module registry: fix the Planos/Plano drawer duplicate (one file,
  `app_drawer.dart`).
- Back-button standard applied to the 12 identified form/detail screens
  + `website_analysis_result_screen.dart`.

**Dependencies**: none (this is the foundation everything else builds
on).

**Data migrations**: none. This phase is entirely Dart/provider/widget
layer. The quota audit trail reuses the existing `diagnostic_events`
table and sanitizer (07A/07B), no new table required.

**Security risk**: low. No RLS change. The quota confirmation dialog
sits in front of the already-correct server-authoritative
`reserveQuota`/`refundQuota` calls without modifying them.

**Quota risk**: this phase's entire purpose is to reduce quota risk
(adds the missing confirmation gate); no new charge paths are
introduced.

**Expected tests**: widget tests for the new `ProjectContext`-scoped
provider (two different projects must not share state — see
`PROJECT_CONTEXT_CONTRACT.md` §6), a state-machine test per migrated
AI-triggering screen (no double-fire on rapid double-tap), a diagnostic-
event test for the new audit sequence (accept path + reject path).

**Physical test gate**: manually confirm, in production-like conditions,
that opening IVE from two different projects in sequence never leaks
the first project's question/grounding into the second.

**Codex gate**: mandatory (Class D — authorization/quota/RLS-adjacent
per governance policy) before this phase is authorized for deploy.

## Phase B — Project Experience

**Scope**:
- Project Command Center becomes a full route-addressable page
  (replacing the current list + bottom-sheet pattern), consolidating
  Identity, Configuration, Knowledge, IVE, Resources, IVE Resource
  Analysis, Briefing, Ecosystem, Idea Analysis, Knowledge Analysis
  sections per `COMMERCIAL_PRODUCT_ARCHITECTURE.md` §2.
- Resource Allocation: manual input fields added alongside presets;
  allocation items become tappable with an IVE-explanation entry point.
  **Blocked on an owner decision** (see §Open Decisions below) regarding
  whether allocation ever persists server-side.
- Weekly Briefing items become individually clickable with per-item
  contextual IVE analysis.
- Canonical `ProjectSelector` widget extracted, replacing the 6
  duplicated private implementations.

**Dependencies**: Phase A (every section on this page uses
`ProjectContext`).

**Data migrations**: only if the owner decision on Resource Allocation
persistence (§Open Decisions) resolves toward "yes, save server-side" —
otherwise none.

**Security risk**: low.

**Quota risk**: low — Idea Analysis and IVE Resource Analysis route
through the Phase A confirmation contract, no new bypass.

**Expected tests**: Project Command Center renders correctly for a
project with zero/partial/full data in each section; ProjectSelector
handles 0, 1, and 50+ projects without hiding any of them.

**Physical test gate**: navigate into 3 different real projects' Command
Centers, confirm no cross-project data bleed anywhere on the page.

**Codex gate**: standard (Class B), adversarial (Class D) if the
Resource Allocation persistence decision introduces a new write path.

## Phase C — Intelligence

**Scope**:
- Market Intelligence: wire the already-existing `projectId`/`.family`/
  `delete()` plumbing into the UI (project picker, project-scoped
  analysis list, delete action). Compact module cards on the hub's
  nav grid. I18N migration for all 8 screens into `AppLocalizations`.
- Competitor Intelligence: Open Website action, Compare-with-IVE action,
  score explanation, render `weaknesses`.
- Website Analyzer: typed route-args object for `/campaigns/new`
  (fixes the confirmed `22P02` bug), consolidate the duplicate "Criar
  Estratégia" action, Back button, delete/rerun actions.
- Knowledge Analysis becomes a reusable component embedded in the
  Project Command Center (Phase B dependency).

**Dependencies**: Phase A (project context, quota contract for new
analysis actions), Phase B (Project Command Center hosts the embedded
Knowledge Analysis component).

**Data migrations**: `ContentItem.type` single-value → multi-value tags
(additive: existing value becomes first tag, no data loss) — this
belongs to Content Library, listed here since it's the one schema
change in this phase's neighborhood; see Phase C.1 note. No migration
for Market Intelligence (all needed columns/methods already exist)
or Website Analyzer (route-contract fix only).

**Security risk**: low. `MarketAnalysisService.delete()` already exists;
confirm it enforces `auth.uid()` ownership the same way reads do before
exposing a UI delete button (verification task, not a new mechanism).

**Quota risk**: new analysis/reanalyze actions on all these screens must
route through the Phase A confirmation contract — explicit test
requirement, not optional.

**Expected tests**: `22P02` regression test (typed args object rejects
a raw URL where an ID is expected, at compile time via the type system
— this is the specific value of fixing it as a type, not a runtime
guard). I18N completeness check for the 8 Market Intelligence screens
(no hardcoded PT/EN string literals remaining, enforced by a lint or a
grep-based test).

**Physical test gate**: run a project-scoped Market Intelligence
analysis end to end (create → view → delete), confirm no quota is
charged on reopen, confirm the `22P02` scenario no longer reproduces
(navigate Website Analyzer result → Criar Campanha).

**Codex gate**: standard (Class B); Class D if the delete action's RLS
enforcement needs re-verification.

### Phase C.1 — Content Library / Knowledge integration
(Can run in parallel with the rest of Phase C — no shared files.)
- Multi-valued tags migration (additive).
- Wire `ContentItem.knowledgeItemId` into display ("Abrir Fonte
  Original") and creation (link to a Knowledge Vault source instead of
  a disconnected duplicate flow).

## Phase D — Decision/Execution

**Scope**:
- Decision Center: fix the `_BootstrapBanner` misroute (Debug Center →
  actual project), add project name to `_SimpleCard`/`_RecCard`.
- Opportunity Lab: idempotency guard on `addFromOpportunity`, `approve()`
  transitions to `'executing'` once an Action exists, project name on
  list cards, fix the raw-UUID source display, evidence/inference/
  recommendation labeling on AI justifications.
- Action Engine: add `'paused'` status + `pause()`/`resume()`
  transitions, make summary counters interactive filters, project name
  on cards, contextual "Ask IVE" (direct dialog, not navigate-away).

**Dependencies**: Phase A (context contract, IVE dialog wiring,
processing states for the approve/create-action/pause/complete
sequence — this is exactly the "no second click during processing"
requirement from Section 08, and it needs the state machine from Phase
A to be in place first).

**Data migrations**: add `'paused'` to `ActionQueueItem.statusValues`
(additive enum value, no destructive change — existing rows unaffected).

**Security risk**: low.

**Quota risk**: none directly (this phase is about workflow state, not
AI consumption) except the "Ask IVE" wiring, which reuses Phase A's
contract unchanged.

**Expected tests**: regression test proving `addFromOpportunity` is
idempotent (calling it twice for the same opportunity produces exactly
one `ActionQueueItem`); state-machine test for pause/resume; a test
confirming the `_BootstrapBanner` routes to the correct project.

**Physical test gate**: approve an opportunity, attempt to create an
action from it twice in a row (including via both list and detail
screen entry points) — confirm exactly one action is created.

**Codex gate**: standard (Class B); this phase directly targets a
confirmed data-integrity bug (duplicate action creation), so a focused
adversarial pass on the idempotency fix specifically is warranted (the
same rigor applied to the Market Intelligence 406 fix in Stability-08).

## Phase E — Commercial Shell

**Scope**:
- Support: FAQ, in-app Report a Problem / Send Feedback flows with a
  real confirmation step (even if the backend is still an email send —
  the UX needs an acknowledgment, not silent `mailto:`).
- About: real official-website URL (pending owner input — see Open
  Decisions), version already correct (no change needed there).
- Legal: Privacy Policy / Terms of Use pages or links (pending owner-
  approved copy — this mission defines integration points only, per
  Section 23).
- Marketing consent: opt-in mechanism, consent audit fields, unsubscribe
  path — net-new, no existing mechanism to migrate.
- Support email domain decision (see Open Decisions).

**Dependencies**: none technical; blocked on owner-supplied content
(legal copy, confirmed domain/mailboxes, real marketing site URL if one
exists separate from the app's own deploy URL).

**Data migrations**: new consent-tracking table (consent type,
timestamp, state, withdrawal) — genuinely new, no existing table to
extend.

**Security risk**: low, but consent data is personal data — apply the
same RLS-by-`auth.uid()` pattern already used everywhere else in this
schema (no new pattern needed).

**Quota risk**: none.

**Expected tests**: consent record created on opt-in, removed/flagged on
unsubscribe, never pre-checked by default.

**Physical test gate**: full Support flow (report a problem → see
confirmation), full consent opt-in/opt-out round trip.

**Codex gate**: standard (Class B); Class D for the new consent table's
RLS policies specifically (personal-data table, new surface).

## Phase F — Visual/I18N Closure

**Scope**:
- Typography scale applied first to `executive_decision_center_screen.dart`
  (the confirmed 9-12px hotspot), then audited elsewhere.
- Dialog/modal responsive standard applied where needed.
- Remaining i18n adoption gaps outside Market Intelligence (if any found
  during Phase C's audit) closed.
- Final Commercial UI Standard gate: a pass confirming no screen forces
  horizontal scrolling at 100% zoom, no dialog exceeds viewport.

**Dependencies**: ideally last, so it audits the cumulative result of
B/C/D/E rather than auditing screens that are about to change again.

**Data migrations**: none.

**Security risk**: none.

**Quota risk**: none.

**Expected tests**: golden/screenshot tests at 100% zoom for the
highest-traffic screens (Dashboard, Decision Center, Project Command
Center, Market Intelligence hub).

**Physical test gate**: the owner re-tests at 100% browser zoom
(explicitly not 150%) and confirms readability without zooming.

**Codex gate**: standard (Class B).

## Open Decisions (for Agente Martins / Paulo, not resolved here)

1. **Resource Allocation persistence** — does "saving" an allocation
   imply a new server-side write (new table/column), or does the
   product intend allocation to remain advisory/preview-only forever?
   This gates part of Phase B's scope and whether a migration is needed
   there.
2. **Support email domain** — `suporte@aisocialcopilot.com` is the only
   real, currently-configured address. Confirm whether
   `support@`/`feedback@insightvalues.com` mailboxes exist and are
   monitored before publishing anything under that domain. Until
   confirmed, Phase E should keep the existing working address rather
   than fabricate a new one.
3. **Official website URL** — `AppConstants.officialWebsiteUrl` today
   equals the app's own GitHub Pages deploy URL. If a separate marketing/
   institutional site exists or is planned, Phase E needs that URL from
   the owner; otherwise the "About → Website" link should be scoped
   down to something accurate (e.g. removed, or explicitly labeled as
   the app itself) rather than implying an external destination that
   doesn't exist.
4. **"Criar Estratégia" target** — Website Analyzer's duplicate action
   currently misroutes to `/knowledge/new`. A dedicated
   `strategy_screen.dart` already exists in the repo. Confirm this is
   the intended destination before Phase C repoints the button.

## MUST / SHOULD / POST-V1 (applying "is this necessary to sell the MVP
safely and coherently?")

**MUST for safe Commercial V1** (security, data integrity, quota
transparency, broken navigation/context, critical usability — not
demoted for speed):
- Phase A in full (Project Context Contract, quota confirmation, AI
  processing states) — without this, every "Ask IVE" interaction risks
  showing the wrong project's data, which is a trust/correctness issue,
  not a polish issue.
- Phase D's idempotency fix (duplicate Action creation) — confirmed
  data-integrity bug, same class as the Stability-08 Market Intelligence
  406.
- The `22P02` route-typing fix (Phase C) — confirmed crash on a common
  path (Website Analyzer → Create Campaign).
- Back-button standard on the 12 form/detail screens + Website Analyzer
  result screen (Phase A) — broken navigation is explicitly called out
  as non-demotable in the mission brief.
- Planos/Plano drawer duplicate fix (Phase A) — small, but a visibly
  broken/confusing commercial surface.

**SHOULD for Commercial V1** (meaningfully improves coherence/trust but
the product is not unsafe without it at launch):
- Project Command Center full page (Phase B) — currently a partial
  bottom-sheet experience; upgrading it is high-value but the app
  functions without it.
- Market Intelligence project/Knowledge wiring and i18n cleanup
  (Phase C).
- Opportunity Lab/Action Engine remaining UX fixes beyond the
  idempotency bug itself (project names on cards, interactive counters,
  pause/resume) (Phase D).
- Support flow confirmation UX (Phase E).

**POST-V1** (real, worth doing, not launch-blocking):
- Resource Allocation manual input + interactivity, pending the
  persistence decision (Phase B).
- Competitor comparison IVE feature, score explanations (Phase C).
- Multi-valued Content Library tags (Phase C.1).
- Marketing consent/newsletter mechanism (Phase E) — required before
  ever sending marketing email, not required to sell V1 itself.
- Typography/visual polish beyond the one confirmed hotspot (Phase F).
