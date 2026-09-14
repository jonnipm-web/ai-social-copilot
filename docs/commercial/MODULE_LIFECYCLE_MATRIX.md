# Module Lifecycle Matrix

Status: DOCUMENTS EXISTING ARCHITECTURE (mostly already implemented)
Owner gate: Agente Martins
Implements: mission brief Sections 24, 25

## 1. Headline finding

Mission Section 24 asks us to "define" a canonical module registry with
`moduleId`, `localizedName`, `commercialEnabled`, `minimumPlan`,
`adminVisible`, `internal`, `developmentStatus`, generated Admin
inventory, and no duplicated manual module list.

**This already exists and is mature.** `lib/core/modules/
module_definition.dart` defines `ModuleDefinition` with exactly these
fields (and more): `moduleId`, `namePt`/`nameEn`, `status`
(`ModuleStatus`: active / beta / inDevelopment / disabled / planned /
internal, each with PT/EN labels), `adminVisible`, `adminClickable`,
`commercialEnabled`, `minimumPlan` (`ModulePlan`: free / pro / admin),
`route`, `backendDependencies`, `edgeFunctions`, `databaseDependencies`,
`aiDependency`, `readinessPt`/`readinessEn`, `releaseClassification`
(`ModuleReleaseClass`: commercialV1 / postV1 / betaProgram /
internalTooling / externalPlanned), `notes`, and a `visibleFor({isAdmin,
isPro})` method implementing the actual visibility rule.

`lib/core/modules/module_registry.dart` (`kModuleRegistry`, 34 entries)
is a hand-curated inventory whose own header states it was built "by
repository audit, not assumption." It already distinguishes Commercial
V1 vs Post-V1 vs Beta vs Internal vs External-planned, with reasoning
recorded per entry (e.g. the `ive-quant` entry documents that it "DOES
NOT EXIST in this repository... confirmed by exhaustive grep...
classified NOT_IMPLEMENTED / SEPARATE_PRODUCT" rather than silently
omitting it).

`lib/features/admin/screens/admin_panel_screen.dart`'s `_ModulesAdminTab`
(around line 349) already reads `kModuleRegistry.where((m) =>
m.adminVisible)` directly and renders status badge, commercial/plan,
route, AI dependency, edge functions, DB tables, readiness text, and
notes per module, with a detail bottom-sheet, and `adminClickable`
already gates navigation into unsafe/incomplete modules.

**Conclusion: Section 24 is not a build task. It is a "verify and keep"
item**, except for one concrete defect below.

## 2. Route/policy enforcement (already mechanically checked)

`lib/core/modules/route_policy.dart`:
- `kRouteModuleOwnership`: explicit route → moduleId map, hand-listed for
  every `app.dart` route (not prefix-inferred).
- `kAlwaysAllowedRoutes` (`/upgrade`, `/account`, `/about`, `/support`)
  bypass module lookup.
- `kDeliberatelyUnclassifiedRoutes` (`/history`, `/history/:id`)
  documents intentionally-unmapped routes (fail-open, by design).
- `decideForModule()`: admin bypasses all; `!commercialEnabled` is
  checked **before** plan (specifically to prevent "PRO unlocks
  unreleased module" bugs); `profileResolved:false` fails closed to
  `redirectDenied`, never guesses PRO.
- `isModuleActionable()`: a separate, narrower check (commercialEnabled
  only, ignores plan) used for CTA/button-visibility — deliberately
  decoupled from the route guard.
- `test/core/modules/route_policy_test.dart` already asserts every
  `app.dart` GoRoute resolves through `kRouteModuleOwnership` or the
  always-allowed set — an unmapped future route already fails CI. This
  matrix inherits that guarantee; it does not need to re-derive it.

Registry entries with `route: null` (context-copilot, strategy-generation,
the 6 Market Intelligence sub-modules, file-import, google-drive-import,
usage-quota, decision-simulator, ive-quant, ive-avatar) are intentional —
each has an explicit comment recording why (global overlay, or a
sub-flow reached from a parent screen, not a top-level nav destination).

One orphaned module is flagged in the registry's own notes:
`advisor-onboarding` (`/advisor-onboarding`) — route exists, but no
in-app navigation entry point was found anywhere; reachable only by
direct URL. Left as a registry note, not fixed here (no evidence it is
commercial-blocking).

## 3. Confirmed defect: "Planos / Plano" duplicate

Exact mechanism (file:line, not guesswork):
- `module_registry.dart:363` — the `plans-upgrade` module entry:
  `namePt: 'Planos / Upgrade'`, `route: AppConstants.routeUpgrade`,
  `commercialEnabled: true`, `minimumPlan: free`. This entry legitimately
  passes `app_drawer.dart`'s registry-driven filter
  (`route != null && visibleFor(...) && commercialEnabled`) and renders
  once via the `for (final module in visibleModules)` loop
  (`app_drawer.dart:125-131`).
- Separately, `app_drawer.dart:133-138` **hardcodes a second** `_NavItem`
  immediately after a divider, labeled via l10n key `t.navUpgrade`
  (`app_pt.arb:40` = `"Plano / Upgrade"` — singular, different string
  from the registry entry's plural), pointing to the **same**
  `AppConstants.routeUpgrade`.

Net effect: the drawer renders two separate items that both navigate to
`/upgrade`, with inconsistent singular/plural labels. The fix is
mechanical (exclude `plans-upgrade` from the registry loop, since a
hardcoded item for the same route already exists right below it — or
remove the hardcoded item and let the registry loop be the single
source, whichever matches product intent for where "Upgrade" sits in
the drawer's visual hierarchy). This is flagged for Phase A/E
implementation, not fixed in this architecture-only mission.

## 4. Module inventory table

The authoritative table is `kModuleRegistry` itself (34 entries,
already fully structured and commented) — this document does not
duplicate it verbatim (that would create exactly the second
manually-maintained list Section 24 explicitly forbids). Instead:

- **Source of truth**: `lib/core/modules/module_registry.dart`.
- **Rendered view for humans**: Admin Panel → Módulos tab (already
  built, already generated from the registry — see §1).
- **Enforced consistency**: `route_policy_test.dart` (already CI-gated).

Any future module addition/status change is a single edit to
`module_registry.dart`; the Admin tab and route policy update
automatically, per the existing (not proposed) design.

## 5. What this mission adds (net-new, small)

1. Fix the Planos/Plano duplicate (§3) — one-line-scope change to
   `app_drawer.dart`.
2. No new fields are needed on `ModuleDefinition` — it already has
   everything Section 24 asks for.
