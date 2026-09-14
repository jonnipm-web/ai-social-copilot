# Commercial Navigation Standard

Status: PROPOSED (architecture mission COMMERCIAL-PRODUCT-ARCHITECTURE-10)
Owner gate: Agente Martins
Implements: mission brief Section 26 (and Back-button parts of 11/16)

## 1. Canonical flow

```
hub → module page → item/detail page → contextual IVE
```

This pattern is already the dominant shape of the app (Dashboard →
Market Intelligence hub → Gap Analysis → Ask IVE, etc.) — this document
formalizes it, it does not introduce a new navigation paradigm.

## 2. Back-button audit (verified, not assumed)

Grepped `AppBar(` usage across 48 feature screens.

**Already correct** (explicit `leading:` with a deterministic fallback,
typically `context.canPop() ? context.pop() : context.go(<hub route>)`):
`resource_allocation_screen.dart`, `executive_decision_center_screen.dart`,
`ecosystem_view_screen.dart`, `content_library_screen.dart`,
`opportunity_lab_screen.dart`, `opportunity_detail_screen.dart`,
`knowledge_vault_screen.dart`, `project_command_center_screen.dart`,
`revenue_planner_screen.dart`, `gap_analysis_screen.dart`, most Market
Intelligence screens, `roi_tracker_screen.dart`, `campaigns_screen.dart`,
`calendar_screen.dart`, `history_screen.dart`, `action_engine_screen.dart`,
`action_detail_screen.dart`, `website_analyzer_screen.dart`,
`weekly_briefing_screen.dart`.

**Missing** (bare `AppBar(` relying on Flutter's default pop-only back
arrow, which is silently absent whenever there's nothing to pop):
`content_form_screen.dart`, `home_screen.dart`, `strategy_screen.dart`,
`knowledge_analysis_screen.dart`, `drive_picker_screen.dart`,
`persona_training_screen.dart`, `persona_form_screen.dart`,
`history_detail_screen.dart`, `knowledge_item_form_screen.dart`,
`result_screen.dart`, `campaign_detail_screen.dart`,
`campaign_builder_screen.dart`.

**Pattern**: the gap is concentrated in **form/edit/detail screens**,
not universal. `website_analysis_result_screen.dart` is a confirmed,
root-caused special case: it has no `leading:` override, and every
entry point reaches it via `context.go(...)` (not `.push`), which
replaces GoRouter's history stack, so there is nothing to pop even if a
default back arrow were present.

## 3. Rule

Every secondary/detail/form screen gets an explicit `leading:` with a
deterministic fallback:

```dart
leading: IconButton(
  icon: const Icon(Icons.arrow_back),
  onPressed: () => context.canPop()
      ? context.pop()
      : context.go(<canonical parent route for this screen>),
)
```

This is the exact pattern already used by the 18+ screens in §2's first
list — Phase A/F work is to apply it to the 12 named screens plus
`website_analysis_result_screen.dart`, not invent a new mechanism.

## 4. Confirmed misroute (not a broad navigation redesign — one bug)

`executive_decision_center_screen.dart`'s `_BootstrapBanner` ("N
projeto(s) sem inteligência operacional") has `onTap: () =>
context.push(AppConstants.routeIntelligenceDebug)` — a project-scoped
warning sends the user to the admin Debug Center instead of the
affected project(s). Debug Center remains admin/diagnostic-only per
mission Section 11; this banner's `onTap` should route to the
project(s) it is actually warning about (e.g. Project Command Center
for the first/only affected project, or a project picker if several).
Fix target for Phase D, not fixed in this architecture-only mission.

## 5. Confirmed route-parameter type confusion (root cause of a real bug)

`/campaigns/new`'s `extra` parameter is overloaded with two incompatible
meanings depending on caller:
- `website_analysis_result_screen.dart:957-960` passes a **raw website
  URL string**: `context.go('/campaigns/new', extra: analysis.url)`.
- The route builder in `app.dart` casts it directly:
  `final itemId = state.extra as String? ?? ''; return
  CampaignBuilderScreen(itemId: itemId);`
- `campaign_builder_screen.dart` then uses `itemId` as a **Knowledge
  item UUID** in `.eq('id', ...)` lookups
  (`knowledgeItemByIdProvider`/`knowledgeAnalysisProvider`), which is
  the confirmed, root-caused source of the `PostgrestException 22P02:
  invalid input syntax for UUID` the owner captured.

**Standard**: a route's `extra`/parameter slot must have exactly one
documented type per route. Where a screen genuinely needs to accept
either "an existing entity ID" or "a raw seed value" (as
`CampaignBuilderScreen` does — new-from-URL vs edit-existing), the
route must carry an explicit discriminator, not an untyped `String?`
overloaded by convention:

```dart
// Instead of a bare String? extra with two silent meanings:
class CampaignBuilderArgs {
  final String? existingItemId;   // Knowledge item UUID, for edit
  final String? seedUrl;          // raw URL, for a fresh draft
}
```

This is the concrete fix target for the Website Analyzer / Campaign
flow in Phase C, cited here because it is fundamentally a navigation/
route-contract defect, not a data or service-layer bug — no migration
is implied.

## 6. Duplicate action confirmed (also a navigation-standard issue)

`website_analysis_result_screen.dart` has the identical "Criar
Estratégia" action twice — once in AppBar actions (line ~60-72), once in
the bottom action bar (line ~940-950) — both navigating identically to
`/knowledge/new` (confirmed misrouting to Knowledge creation instead of
a dedicated Strategy flow, exactly as the owner reported). Fix target:
Phase C, consolidate to one action, and point it at whatever the
product decides "Criar Estratégia" should actually open (a dedicated
Strategy screen already exists at `strategy_screen.dart` — this
architecture mission does not decide whether that is the intended
target; it records the current misroute as a fact for Agente Martins to
resolve).

## 7. Non-goals

This standard does not require replacing GoRouter, does not change the
hash-based URL strategy, and does not touch `route_policy.dart`'s
enforcement mechanism (already correct, per
`MODULE_LIFECYCLE_MATRIX.md` §2).
