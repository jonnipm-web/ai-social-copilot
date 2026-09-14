# Commercial Product Architecture

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Base SHA: e604f6b (production baseline; STABILITY-09 null-crash remains
OPEN/HYPOTHESIS as a parallel P1 stability track — not addressed here)

## 0. The one pattern behind almost every finding

Across six independent research passes (module registry, project/IVE/
quota, Opportunity Lab/Action Engine, Market Intelligence/Website
Analyzer/Knowledge, Dashboard/Ecosystem/Resources, Support/About/i18n),
the same shape recurs: **the data and service layer is usually already
more capable than the UI exposes.**

- `MarketAnalysis.projectId`, `fetchAll(projectId:)`,
  `marketAnalysesByProjectProvider`, and `MarketAnalysisService.delete()`
  all already exist — no Market Intelligence screen uses any of them.
- `ContentItem.knowledgeItemId` already exists as a FK — no Content
  Library screen uses it to link back to Knowledge Vault.
- `OpportunityLabItem`/`ActionQueueItem` already have separate `status`
  enums and a `projectId` field — the UI just never surfaces the
  project name on list cards, and never adds an idempotency check
  before creating a second Action from the same Opportunity.
- The module lifecycle registry Section 24 asks us to "design" already
  exists, fully built, already wired into the Admin panel.

This changes the shape of the roadmap: most of Phases B/C/D is **wiring
and consolidation**, not new schema or new services. The two genuine
net-new architectural pieces are the **Project Context Contract** (see
`PROJECT_CONTEXT_CONTRACT.md`) and the **quota confirmation/state-machine
layer** (see `IVE_INTERACTION_AND_QUOTA_CONTRACT.md`) — both are UI/
provider-layer work, neither requires a database migration.

## 1. Canonical project flow

```
PROJECT → KNOWLEDGE → ANALYSIS → IVE → OPPORTUNITY → DECISION → ACTION → RESULT
```

The project is the primary contextual object system-wide. See
`PROJECT_CONTEXT_CONTRACT.md` for the mechanism (today: no such
mechanism exists — every IVE interaction is grounded on "whichever
project has the top ecosystem score," not the project on screen).

## 2. Project Command Center

`lib/features/projects/screens/project_command_center_screen.dart`
**already exists** (1454 lines) but is **not** the canonical hub the
mission describes: it is a project **list** plus a `_ProjectDetailSheet`
**bottom sheet**, not a dedicated persistent page per project. Confirmed
present in the sheet: identity fields, ecosystem score, "view
knowledge"/"analyze knowledge" buttons (routing to Knowledge Vault), a
missing-knowledge-gaps list, one "Ask IVE" action. Confirmed **absent**:
a Resources section, a Briefing section, an "Analise sua ideia" input,
an embedded Knowledge Analysis component, an IVE Resource Analysis
section.

**Verdict: this is genuinely mostly net-new work**, not a refactor —
correctly scoped as its own Phase B effort, reusing the identity/
knowledge-link/score fragments that already work, replacing the
bottom-sheet container with a full route-addressable page (so it can be
deep-linked, back-navigated to, and hold the tabbed sections Section 03
describes: Identity, Configuration, Knowledge, IVE, Resources, IVE
Resource Analysis, Briefing, Ecosystem, Idea Analysis, Knowledge
Analysis).

Every section on this page constructs its `ProjectContext` from the
page's own `projectId` (never re-derives it) — this page is the
reference implementation for the Project Context Contract.

## 3. Opportunity Lab vs Action Engine model

### 3.1 Data layer (already correctly separated — keep as-is)

`OpportunityLabItem.statusValues = ['pending', 'analyzing', 'approved',
'rejected', 'executing']` and `ActionQueueItem.statusValues = ['pending',
'approved', 'executing', 'completed', 'cancelled']` are already distinct
tables/models with independent status fields and their own `projectId`.
The mission's requested separation of responsibility already exists at
the data layer; the problem is entirely in the UI/orchestration layer.

### 3.2 Confirmed defect: unguarded duplicate Action creation

`addFromOpportunity` (`action_queue_provider.dart:133-190`) performs an
**unconditional insert** (`_svc.create(item)`, line 177) — no check for
an existing `ActionQueueItem` with the same `opportunityLabId`.
`approve()` (`opportunity_lab_provider.dart:54-57`) only ever sets status
to `'approved'` — **never** to `'executing'` — so after approval the
opportunity stays `'approved'` indefinitely, and the UI's "→ Ação"
button remains visible and clickable forever. This method is reachable
from **4 separate UI call sites** (`opportunity_lab_screen.dart:196-233`
and `:236-265`, `opportunity_detail_screen.dart:95-128` and `:844-909`),
each capable of creating a duplicate `ActionQueueItem` for the same
opportunity with no guard.

**Fix target (Phase D)**: `addFromOpportunity` gains an idempotency
check (does an `ActionQueueItem` already exist for this
`opportunityLabId`? if so, return/navigate to it instead of inserting),
and `approve()` transitions status to `'executing'` once an Action is
actually created, so the "create action" affordance disappears once one
exists. This closes the double-click/duplicate-transition risk at its
actual source, not just by disabling buttons during a request (though
the Section 07 processing-state work helps here too).

### 3.3 Confirmed defect: "Pausar" does not pause

`action_engine_screen.dart:461-462`'s "Pausar" button (visible when
status is `'executing'`) calls `notifier.approve(item.id, ...)` — reusing
the `approve()` transition to *simulate* pause, because
`ActionQueueItem.statusValues` has **no `'paused'` value at all**. After
"pausing," an item is indistinguishable from a freshly-approved,
never-started action.

**Fix target (Phase D)**: add `'paused'` to `ActionQueueItem.
statusValues` and give it its own transition method
(`pause()`/`resume()`), matching the state machine the mission specifies:

```
OPPORTUNITY LAB:  DISCOVERED → ANALYZED → QUALIFIED → APPROVED → ACTION_CREATED
ACTION ENGINE:    PENDING → ACTIVE → PAUSED → COMPLETED (or CANCELLED)
```

(Mapping the current 5-value opportunity enum and 5-value — soon
6-value — action enum onto these two named sequences is a labeling/
UI-state-machine exercise on top of the existing DB columns; it does
not require a schema rename, since the current string values already
partition into the two sequences functionally.)

### 3.4 Confirmed defect: static counters, no filtering

`_ActionSummaryRow`/`_SummaryChip` (`action_engine_screen.dart:201-254`)
are plain `Container`s with no `GestureDetector`/`onTap`. Tapping a
Pendentes/Em Execução/Concluídas count does nothing today; the list
below is a single unfiltered stack (Concluídas truncated to `.take(5)`),
forcing the manual scrolling the owner reported.

**Fix target (Phase D)**: wire each summary chip to a local filter state
that scopes the list below it — mechanical, no new data needed (status
is already on the model).

### 3.5 Confirmed defect: project identity gaps

- Opportunity **detail** screen already resolves and shows the project
  name (`opportunity_detail_screen.dart:184-188, 471-476`).
- Opportunity **list card** (`_LabItemCard`,
  `opportunity_lab_screen.dart:277-417`) never renders it.
- Action Engine's card and detail screen (lines 296-480 reviewed) do not
  render project name either.

**Fix target (Phase D)**: add project name to both list-card renderers,
sourced from the same `projectId`/`projectByIdProvider` lookup already
used correctly in the opportunity detail screen — no new data plumbing.

### 3.6 "Ask IVE" wiring

Neither module opens a contextual dialog today — both buttons
(`opportunity_detail_screen.dart:925-929`,
`action_detail_screen.dart:876`) just `context.go()` back to their own
list screen. See `IVE_INTERACTION_AND_QUOTA_CONTRACT.md` §1.1 for the
fix (both become direct `showCopilotChat` calls with the current item's
`ProjectContext`).

### 3.7 Raw ID exposure

`opportunity_detail_screen.dart:477-482` shows a truncated raw UUID as a
"source" label — see `COMMERCIAL_UI_STANDARD.md` §5 for the fix.

## 4. Market Intelligence target model

Owner assessment (taken as a hard constraint): **already generally
good — refine, do not redesign.** The hub screen
(`market_intelligence_hub_screen.dart`) is confirmed well-structured
(score card, revenue, gaps, competitors, opportunities, module nav
grid, ROI integration) and should be the pattern other refinements
match, not replace.

Confirmed: the **service/provider layer is already project-scoped-
capable** — `MarketAnalysis.projectId`, `MarketAnalysisService.
fetchAll({projectId})`/`.analyze(..., projectId)`, `marketAnalysesByProjectProvider`
(a `.family` already keyed by project), and `MarketAnalysisService.
delete(String id)` all exist today. **No screen uses any of them.**
`market_intelligence_screen.dart` calls `notifier.analyze(input,
inputType, language)` without `projectId`; its "Tipo de entrada"
selector's "Projeto" option is a free-text description hint, not a real
project picker bound to a `project_id`; the screen watches the unscoped
`marketAnalysesProvider`, not the project-scoped family.

**This is a wire-the-UI-to-existing-plumbing task, not new schema or
service work.** Concretely:
- Add a real project picker (the canonical `ProjectSelector` from
  `COMMERCIAL_UI_STANDARD.md` §3) bound to `project_id`, alongside the
  existing manual-description path (Section 17 explicitly asks for
  "existing project OR Knowledge Vault sources OR manual description" —
  all three, not a replacement).
- Switch screens to `marketAnalysesByProjectProvider` when a project is
  selected.
- Add a delete action to `_AnalysisCard` (`market_intelligence_screen.dart:289-354`)
  calling the already-existing `MarketAnalysisService.delete()`, with
  confirmation, per `PROJECT_ANALYSIS_RESULT_PERSISTENCE` rules (§7).

I18N: 4 of 8 screens have English AppBar titles/labels mixed with
Portuguese content (full table in `COMMERCIAL_UI_STANDARD.md` §4) —
fast-tracked as the specific "refine" the owner asked for.

Compact module cards (Section 17's "current buttons/cards are
oversized... redesign as compact miniatures") is the one visual change
explicitly authorized for this module — scoped to the hub screen's
module-nav grid, not the whole module.

## 5. Competitor Intelligence target model

Confirmed gaps, all additive (no data model change needed beyond
possibly exposing `weaknesses`, which the model likely already has but
the screen never renders): no "Open Website" action on
`competitor.url` (currently plain `Text`, no `onTap`/`launchUrl`), no
"Compare with IVE" action at all, opaque un-explained scores. See
`COMMERCIAL_UI_STANDARD.md` §6 and mission Section 18 for the target
comparison layout (user/project vs competitor, strengths/weaknesses/
score/advantages/gaps on both sides, criteria explained).

## 6. Website Analyzer target model

Two confirmed, root-caused bugs (not vague reports):

1. **`22P02: invalid input syntax for UUID`** — `/campaigns/new`'s
   `extra` route parameter is overloaded: one caller passes a raw
   website URL, the route builder casts it straight to `itemId`, and
   `CampaignBuilderScreen` uses it as a Knowledge-item UUID in a
   Postgres `.eq('id', ...)` lookup. Fix is a typed route-args object,
   not a data fix — see `COMMERCIAL_NAVIGATION_STANDARD.md` §5.
2. **Duplicate "Criar Estratégia" + misroute to `/knowledge/new`** —
   both AppBar and bottom-bar buttons in
   `website_analysis_result_screen.dart` do this identically. See
   `COMMERCIAL_NAVIGATION_STANDARD.md` §6.

Also confirmed: "Plano SEO"/"Plano AdSense" are **deliberately stubbed**
(`SnackBar` "disponível na Fase 9") — not broken, just inactive by
design; scope decision for a later phase, not a bug to silently
"finish" here. No delete/rerun action exists anywhere in this feature.
No Back button — root-caused to every entry point using `context.go()`
(replaces history stack) with no `leading:` override; fixed by
`COMMERCIAL_NAVIGATION_STANDARD.md` §2-3's standard back pattern.

## 7. Knowledge Vault / Content Library model

`ContentItem.type` is confirmed **single-valued**, drawn from a fixed
mutually-exclusive PT-labeled list (livro, ebook, artigo, post, ideia,
texto, campanha, produto, marca, projeto) — exactly the restrictive
taxonomy the owner flagged. Target: multi-valued classification (a
`List<String>` of tags rather than one `type` string), migrated
additively (existing single `type` value becomes the first tag; no data
loss).

`ContentItem.knowledgeItemId` **already exists as a field** but is
**completely unused** in both `content_library_screen.dart` and
`content_form_screen.dart` — no "Open Original Source" action, and new
Content Library items are created with zero reference to Knowledge
Vault (`content_form_screen.dart` has no Knowledge-related code at all).
Target: wire `knowledgeItemId` into both the display (an "Abrir Fonte
Original" action linking back to the Knowledge Vault item) and the
creation flow (creating a Content Library item from/linked to a
Knowledge Vault source, rather than a disconnected duplicate entry
form). Both changes reuse an existing FK — no migration needed for the
link; the tags change is the only schema-adjacent piece, and it is
additive.

## 8. Resource Allocation model

`resource_allocation_screen.dart`: Back button already correct. Manual
numeric input is confirmed **absent** — only fixed preset arrays
(`_hourOptions = [10,20,40,80]`, `_moneyOptions = [100,500,1000,5000]`).
Allocation items are confirmed **non-interactive** (`_AllocationItem` is
a plain `Container`, no tap handler, no IVE-explain entry point at all —
contrast with the Decision Center's `_ProjectCard`, which does have
one). Project name is already shown correctly here.

Important scope note discovered during research: **this screen has no
save/commit action at all today** — it is a pure client-side simulation
view; nothing here is ever persisted. Section 12's "distinguish PREVIEW
vs SAVED ALLOCATION" therefore requires deciding, as an architecture
question for Agente Martins before Phase B/C implementation: does
"saving" an allocation mean writing a real row somewhere (implying a new
table/column), or does the product intend resource allocation to remain
advisory-only (no save, PREVIEW is the only state that ever exists)? This
document does not presume an answer — flagged as an open architectural
decision, not silently resolved.

## 9. Support / About / Legal model

**Support**: `support_screen.dart` has no FAQ and no in-app form — all
three actions (Contato, Reportar Problema, Enviar Feedback) are
`mailto:` links via `url_launcher`, with no "request received"
confirmation/protocol. No custom Back `leading:`.

**Email domain — a different risk than the mission brief assumed.** The
real configured support address is `AppConstants.supportEmail =
'suporte@aisocialcopilot.com'` (`app_constants.dart:158`) — the
repository's **old** pre-rebrand domain (`ai-social-copilot`), not
`insightvalues.com` and not the misspelled `insigthvalues.com` the
owner worried about verbally. A prior mission
(`IVE-COMMERCIAL-RELEASE-CONTROL-PLANE-01`) deliberately used this real,
working address rather than fabricating an `insightvalues.com` one that
might not exist. **This is an owner decision, not a code fix**: confirm
whether `suporte@`/`feedback@insightvalues.com` mailboxes actually exist
and are monitored before changing anything — do not publish an address
until ownership is confirmed, per mission Section 21's own rule.

**About**: version is already correctly single-sourced via
`PackageInfo.fromPlatform()` reading `pubspec.yaml` — no divergent
hardcoded version string was found anywhere in `lib/`. The "Website"
link already uses `launchUrl` (a real external navigation call) — but
`AppConstants.officialWebsiteUrl` is literally the app's own GitHub
Pages deploy URL, so the link technically leaves the app and lands right
back on it. This is the precise, root-caused explanation for the
owner's "About → website routes back to the dashboard" complaint: fix
target is providing a real separate marketing/official site URL (an
owner-provided input, not something to invent), not a code defect in
the link mechanism itself. Privacy/Terms URLs are deliberately `null`
today, correctly fail safe to an "unavailable" state, and are commented
"OWNER CONTENT REQUIRED" — already the correct placeholder behavior,
just needs real content.

**Legal/consent**: `accountPrivacy`/`accountTerms` strings exist in the
`.arb` files but are unused by any screen (dead strings). No consent/
newsletter/opt-in/unsubscribe mechanism exists anywhere in the app —
confirmed via exhaustive grep. This is genuinely net-new (Phase E), and
per mission Section 23, this architecture mission defines integration
requirements only — it does not draft legal copy.

## 10. Admin module inventory

Already implemented — see `MODULE_LIFECYCLE_MATRIX.md`. One confirmed
defect (Planos/Plano duplicate in the drawer) is the only fix item.

## 11. Analysis result persistence

For every costly analysis (Market Intelligence's gap/cluster/revenue/
competitor/opportunity/niche outputs, Website Analyzer results, Content
Library "Knowledge Analysis" items): opening an existing result never
re-runs the model or touches quota (already true today — nothing in the
audited code re-runs on open). Only an explicit "new analysis" or
"reanalyze" action goes through the quota confirmation contract (see
`IVE_INTERACTION_AND_QUOTA_CONTRACT.md`). Delete removes only the
specific analysis/result row, never the parent project or source —
`MarketAnalysisService.delete(id)` already operates at the correct
granularity (single analysis row); this principle should be followed by
the equivalent delete methods added elsewhere (Website Analyzer,
Content Library) rather than re-derived per module.

## 12. Non-goals for this mission

No Stripe/billing change. No quota architecture change (the confirm/
audit layer sits in front of the existing, correct server-authoritative
reservation flow — it does not modify `reserveQuota`/`refundQuota`
themselves). No RLS/security-boundary change. No production deploy,
merge, or migration. No broad UI redesign implementation — this document
and its companions are the architecture; implementation is a separate,
future, phase-gated mission.
