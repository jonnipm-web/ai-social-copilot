# Project Context Contract

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Implements: mission brief Section 04

## 1. Why this document exists

This is the single most important gap found in this audit. Every other
contract in this mission (IVE interaction, quota confirmation, resource
allocation explanations, briefing item drill-down) assumes IVE and the UI
know *which project* the user is looking at. Today, they don't.

## 2. Current state (verified in repo, not assumed)

- There is no "current/selected project" provider anywhere in
  `lib/providers/`. `project_provider.dart` only exposes the full list
  (`projectsNotifierProvider`) and a by-ID lookup
  (`projectByIdProvider.family`) — both fine primitives, neither used as
  "the active project."
- `lib/providers/ive_context_provider.dart`'s `iveContextDataProvider` is
  a plain `FutureProvider.autoDispose` — **not** a `.family` keyed by
  project. It computes "the project" as whichever project has the
  **highest ecosystem score system-wide**:
  ```dart
  final sorted = [...scores]..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  final top = sorted.isNotEmpty ? sorted.first : null;
  final projectId = top?.project.id;
  ```
  This is ambient, global inference — exactly what this contract forbids.
- `lib/data/models/copilot_context_data.dart` (`CopilotContextData`) has
  **no identity fields at all**: no `project_id`, `source_module`,
  `source_entity_type`, `source_entity_id`, or `correlation_id`. Its
  `project` field is a Map snapshot of the **top 3** projects by score,
  not "the one on screen."
- All 6 `showCopilotChat(` call sites in the app (`ive_overlay.dart`,
  `ive_explain_button.dart`, `ive_detail_sheet.dart`,
  `executive_dashboard_screen.dart`, `executive_decision_center_screen.dart`
  ×3, `project_command_center_screen.dart`) build their `contextData` from
  this same global provider. Several pass a project-specific
  `initialMessage` string (naming the project by name in the chat
  opener), but the **structured grounding data IVE actually reasons
  over is not guaranteed to be about that same project** — only the
  greeting text is contextual. This is the direct, evidenced cause of the
  owner's "stale IVE questions" / "IVE doesn't respond meaningfully"
  reports.
- The one piece that IS already correct:
  `selectKnowledgeForGrounding(knowledgeRaw, projectId)` — a pure,
  already-tested function that correctly scopes knowledge to a given
  `projectId` when one is supplied. The isolation logic itself does not
  need to be rewritten; only what feeds it does.

## 3. Canonical contract

### 3.1 `ProjectContext` value object (new)

```dart
class ProjectContext {
  final String projectId;          // canonical, never a display name
  final String sourceModule;       // e.g. 'opportunity_lab', 'market_intelligence'
  final String? sourceEntityType;  // e.g. 'opportunity', 'competitor', 'gap'
  final String? sourceEntityId;    // canonical ID of the item in view, if any
  final String? analysisId;        // when the interaction is about a stored analysis
  final String correlationId;      // one per user-initiated interaction, for audit tracing
}
```

`ProjectContext` remains the right shape for constructing an
`IveInteractionRequest` (§3.2 below) and for audit events — the
correction in §3.2 only changes what part of it is used as *provider
cache identity* (just `projectId`), not the object's fields themselves.

Rules:
- `projectId` is **required** wherever the user is unambiguously inside a
  project-scoped screen (Project Command Center, any Market Intelligence
  screen reached from a project, Opportunity Lab item tied to a project,
  Action Engine item tied to a project). It is **optional** only for
  genuinely project-agnostic surfaces (global Dashboard shortcuts,
  Admin, Support/About).
- Identity is **always by ID**. Never pass `project.name` where an
  identifier is expected — this repo already has at least one FK
  (`ContentItem.knowledgeItemId`) that exists in the model but is unused
  in the UI; the risk here is the same class of bug in reverse (a name
  used where an ID belongs), not hypothetical.
- `ProjectContext` is constructed **at the call site that knows the
  context** (the screen/widget the user is actually looking at), never
  reconstructed downstream from "whatever the global top-score project
  currently is."

### 3.2 `iveContextDataProvider` becomes project-scoped — keyed by `projectId` alone

**Revised after Codex adversarial review, round 1 (P1, ACCEPTED):** the
first draft of this contract proposed keying the `.family` provider by
the entire `ProjectContext` object (including `sourceModule`,
`sourceEntityId`, `analysisId`, and especially `correlationId`). Codex
correctly identified that this makes every field part of the provider's
*cache identity* — two interactions about the exact same project, from
two different screens, or even two calls with two different
(one-per-interaction) `correlationId`s, would each mint a **separate**
provider instance and refetch the same aggregate grounding data. This
doesn't just waste a fetch; it defeats the whole point of scoping
correctly, by fragmenting the cache far more than the "ambient global
singleton" bug it replaces.

**Corrected design**: the provider family key is `projectId` (nullable)
**only**:

```dart
FutureProvider.family<IveContextData, String?>
```

`sourceModule`, `sourceEntityType`, `sourceEntityId`, `analysisId`, and
`correlationId` are **not** part of provider identity — they travel as
plain parameters on the `IveInteractionRequest` (see
`IVE_INTERACTION_AND_QUOTA_CONTRACT.md` §2) and on the audit event, not
as cache keys. A `null` `projectId` is the explicit, deliberate "no
project in scope" case (global overlay chat opened from a
project-agnostic screen) — it must not silently fall back to
"top-scored project," which is today's bug. `selectKnowledgeForGrounding`
keeps its existing signature; it is already correct and needs no change
under either the original or corrected design.

### 3.3 Switch semantics

Project A → IVE, then Project B → IVE must never reuse Project A's
question or grounding data. Because the provider becomes a `.family`
keyed by `ProjectContext`, this is structural: a different `projectId`
is a different provider instance, with its own state, not a mutation of
shared state. No explicit "reset" method is needed if this is done
correctly — the old ambient-singleton behavior is what required implicit
resets in the first place.

### 3.4 `CopilotContextData` gains identity fields

Add `projectId`, `sourceModule`, `sourceEntityType`, `sourceEntityId`,
`correlationId` (all nullable except when the call site is inside a
known project scope, per 3.1). `CopilotContextData.fromIveContext(...)`
takes an additional `ProjectContext?` parameter and copies these through
unchanged — no reinterpretation, no re-derivation.

## 4. What does NOT change

- `selectKnowledgeForGrounding`'s isolation logic (already correct,
  already tested).
- The underlying `IveContextData` aggregation content (scores,
  opportunities, actions, documents) — only *which project* it is
  computed for changes, not what it contains once scoped.
- `projectByIdProvider` / `projectsNotifierProvider` — already ID-based,
  reused as-is by any screen constructing a `ProjectContext`.

## 5. Migration note

This is a Dart/provider-layer change, not a database migration. No
schema change is implied by this contract on its own (diagnostic
event correlation IDs already exist as a precedent pattern — see
`docs/ive/AI_QUOTA_AUDITABILITY_DESIGN.md`).

## 6. Acceptance criteria for Phase A implementation

- Every one of the 6 existing `showCopilotChat(` call sites is updated to
  construct and pass an explicit `ProjectContext` (or explicit `null` with
  a comment explaining why none applies).
- A regression test proves: opening IVE from Project A's Command Center,
  then from Project B's, produces two independent `iveContextDataProvider`
  reads scoped to their respective `projectId`s (not the same cached
  value).
- No call site is left inferring project identity from "whichever
  project currently has the top ecosystem score."
