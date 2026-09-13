import 'module_definition.dart';
import 'module_registry.dart';
import '../constants/app_constants.dart';

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06R — route-level commercial/plan
/// entitlement policy.
///
/// Context: kModuleRegistry + app_drawer.dart already correctly decide what
/// a user *sees* in the drawer. They decide nothing about what a user can
/// *reach* by direct navigation — every screen in lib/app.dart's GoRouter
/// table is wired up regardless of plan, and several live V1 screens
/// (dashboard_screen.dart's "Personas"/"Biblioteca"/"Calendário" shortcuts,
/// for one) already ship a purely cosmetic `locked` flag that dims an icon
/// but calls the same `onTap` regardless — the navigation itself was never
/// blocked. A FREE user tapping one of those, or simply typing the URL,
/// reached the real screen. That is the monetization bypass this file
/// closes.
///
/// This file is pure policy — no GoRouter, no Riverpod, no Supabase import
/// — so it can be unit-tested with plain booleans/strings. See
/// lib/app.dart for how it's wired into the actual redirect.
enum RouteDecision {
  /// Navigation proceeds to the requested route.
  allow,

  /// Route requires a plan the user doesn't have (but the module IS
  /// commercially released) — send them to the canonical Upgrade surface.
  redirectUpgrade,

  /// Route is admin-only, or the owning module isn't commercially released
  /// at all (regardless of plan — see the CRITICAL RULE comment on
  /// [decideForModule] below) — send them somewhere always-safe, never
  /// "upgrade" (paying wouldn't unlock it).
  redirectDenied,
}

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06R — explicit route → owning-module
/// map. Deliberately NOT inferred from string prefixes (mission
/// instruction): '/ecosystem/resources' and '/ecosystem/briefing' are their
/// OWN modules (resource-allocation, weekly-briefing), not sub-paths of the
/// '/ecosystem' module (decision-center) — a naive longest-prefix-wins
/// scheme happens to get that one right, but "happens to" is not the same
/// as "robust", so every route actually used in lib/app.dart is listed here
/// by hand instead. test/core/modules/route_policy_test.dart asserts every
/// GoRoute path in app.dart resolves through either this map or
/// kAlwaysAllowedRoutes, so a future route added to app.dart without a
/// corresponding entry here fails CI instead of silently falling through.
///
/// A route mapped here to a module with `route: null` (the sub-flow modules
/// fixed in Remediation 06, e.g. 'strategy-generation',
/// 'competitor-discovery') is expected and correct — that field only
/// controls whether app_drawer.dart renders a *top-level nav item* for the
/// module; it says nothing about which concrete GoRoute paths belong to it
/// for entitlement purposes, which is exactly what this map is for.
const Map<String, String> kRouteModuleOwnership = {
  AppConstants.routeDashboard: 'business-dashboard',
  AppConstants.routeHome: 'command-center',
  AppConstants.routeGenerate: 'improve-post',
  AppConstants.routeResult: 'improve-post',
  AppConstants.routePersonas: 'personas',
  AppConstants.routePersonaNew: 'personas',
  AppConstants.routePersonaEdit: 'personas',
  AppConstants.routePersonaTraining: 'personas',
  AppConstants.routeContent: 'content-library',
  AppConstants.routeContentNew: 'content-library',
  AppConstants.routeContentEdit: 'content-library',
  AppConstants.routeCalendar: 'calendar',
  AppConstants.routeAdmin: 'admin-panel',
  AppConstants.routeKnowledge: 'knowledge-vault',
  AppConstants.routeKnowledgeNew: 'knowledge-vault',
  AppConstants.routeKnowledgeEdit: 'knowledge-vault',
  AppConstants.routeKnowledgeAnalysis: 'knowledge-vault',
  AppConstants.routeKnowledgeStrategy: 'strategy-generation',
  AppConstants.routeCampaigns: 'campaigns',
  AppConstants.routeCampaignNew: 'campaigns',
  AppConstants.routeCampaignDetail: 'campaigns',
  AppConstants.routeWebsiteAnalyzer: 'website-analyzer',
  AppConstants.routeWebsiteAnalysisResult: 'website-analyzer',
  AppConstants.routePerformance: 'performance',
  AppConstants.routeMarketIntelligence: 'market-intelligence',
  AppConstants.routeMarketIntelligenceHub: 'market-intelligence',
  AppConstants.routeMarketIntelligenceCompetitors: 'competitor-discovery',
  AppConstants.routeMarketIntelligenceGaps: 'gap-analysis',
  AppConstants.routeMarketIntelligenceOpportunities: 'opportunity-discovery',
  AppConstants.routeMarketIntelligenceNiches: 'niche-discovery',
  AppConstants.routeMarketIntelligenceCluster: 'content-cluster',
  AppConstants.routeMarketIntelligenceRevenue: 'revenue-planner',
  AppConstants.routeProjects: 'projects',
  AppConstants.routeRoiTracker: 'roi-tracker',
  AppConstants.routeEcosystem: 'decision-center',
  AppConstants.routeEcosystemResources: 'resource-allocation',
  AppConstants.routeEcosystemBriefing: 'weekly-briefing',
  AppConstants.routeAdvisorOnboarding: 'advisor-onboarding',
  AppConstants.routeOpportunityLab: 'opportunity-lab',
  AppConstants.routeOpportunityDetail: 'opportunity-lab',
  AppConstants.routeActionEngine: 'action-engine',
  AppConstants.routeActionDetail: 'action-engine',
  AppConstants.routeExecutiveDashboard: 'executive-dashboard',
  AppConstants.routeIntelligenceDebug: 'intelligence-debug',
};

/// Routes that must always remain reachable by any authenticated user,
/// regardless of plan — never looked up against the module registry.
/// routeSplash/routeLogin are NOT here: they're resolved earlier in
/// app.dart's redirect, before this policy is ever consulted.
///
/// - routeUpgrade: mission section 07 — "The Upgrade route itself must
///   remain reachable by FREE users", and it's the redirect target for
///   redirectUpgrade below, so it must never itself redirect (loop safety).
/// - routeAccount/routeAbout/routeSupport: account settings and static
///   info pages have no commercial-plan concept; gating them would itself
///   be a regression (this exact trio was the subject of Remediation 06's
///   route-restoration fix — reusing it for a different kind of denial here
///   would be a step backward).
const Set<String> kAlwaysAllowedRoutes = {
  AppConstants.routeUpgrade,
  AppConstants.routeAccount,
  AppConstants.routeAbout,
  AppConstants.routeSupport,
};

/// Routes deliberately left unclassified (neither owned by a module nor in
/// kAlwaysAllowedRoutes): dashboard_screen.dart links to "Histórico" with
/// no `locked` flag (unlike Personas/Biblioteca/Calendário right next to
/// it), and it is not modeled as its own module in kModuleRegistry.
/// Resolves to `allow` per mission section 09's explicit "unknown/
/// unclassified route → fail safely ... without breaking legitimate
/// application navigation". Listed explicitly (rather than just falling
/// through silently) so the completeness invariant in
/// route_policy_test.dart can still catch a genuinely-forgotten future
/// route instead of every unmapped route being indistinguishable from one
/// that was deliberately left alone.
const Set<String> kDeliberatelyUnclassifiedRoutes = {
  AppConstants.routeHistory,
  AppConstants.routeHistoryDetail,
};

ModuleDefinition? _moduleForRoute(String path) {
  final moduleId = kRouteModuleOwnership[path];
  if (moduleId == null) return null;
  for (final m in kModuleRegistry) {
    if (m.moduleId == moduleId) return m;
  }
  return null; // unreachable if kRouteModuleOwnership only ever references real ids (test-covered)
}

/// Cheap, profile-free pre-check for the caller (see app.dart): true only
/// when the route's owning module could possibly restrict access (not
/// commercially enabled, or requires more than the free plan) — i.e. only
/// when knowing the real isAdmin/isPro actually changes the outcome. Every
/// other route resolves to `allow` regardless of who's asking, so the
/// caller can skip fetching the user's profile entirely for the large
/// majority of navigation (every free, already-released V1 screen), rather
/// than paying an async profile read on every single in-app navigation.
bool routeMayBeRestricted(String path) {
  if (kAlwaysAllowedRoutes.contains(path)) return false;
  final module = _moduleForRoute(path);
  if (module == null) return false;
  return !module.commercialEnabled || module.minimumPlan != ModulePlan.free;
}

/// Pure entitlement decision, given an EXPLICIT (possibly synthetic) owning
/// module. This is the actual policy core — [evaluateRouteAccess] below is
/// just this plus the real-data path→module lookup. Split out so tests can
/// exercise every branch (including "commercially released AND PRO-gated",
/// mission section 09's required FREE/PRO-commercial-route cases) with a
/// constructed [ModuleDefinition], independent of whatever combination of
/// commercialEnabled/minimumPlan happens to exist in kModuleRegistry today
/// (currently, every minimumPlan:pro entry also has commercialEnabled:false
/// — real, but not exhaustive of what the policy itself must handle
/// correctly).
///
/// [isAdmin]/[isPro] reflect the CURRENT PROFILE STATE — pass `false` for
/// both when the profile hasn't resolved yet (see [profileResolved]); never
/// synthesize a guess.
///
/// [profileResolved] — mission section 08: "Do NOT treat 'profile not
/// loaded yet' as PRO... fail safely." When false (still loading, or the
/// fetch failed/timed out), a route that turns out to need a resolved
/// profile to grant PRO access fails closed to [RouteDecision.redirectDenied]
/// rather than either guessing "yes" (unsafe) or guessing "no, go to
/// Upgrade" (actively wrong — telling a possibly-already-PRO user to pay
/// again is worse than a neutral bounce). It has no effect on decisions
/// that don't need profile data at all (unclassified routes, free+released
/// modules, and outright-unavailable-to-everyone modules all resolve the
/// same way whether or not the profile has loaded).
RouteDecision decideForModule({
  required ModuleDefinition? module,
  required bool isAlwaysAllowed,
  required bool isAdmin,
  required bool isPro,
  required bool profileResolved,
}) {
  // Preserve existing admin behavior (mission section 04): admins reach
  // everything through this gate. Individual admin-only screens
  // (admin_panel_screen.dart, intelligence_debug_hub_screen.dart) already
  // have their own real, previously-verified admin checks and are
  // unaffected by this always-allow.
  if (isAdmin) return RouteDecision.allow;

  if (isAlwaysAllowed) return RouteDecision.allow;

  // Unclassified route: fail safe = don't break existing navigation.
  if (module == null) return RouteDecision.allow;

  // CRITICAL RULE (mission section 05): commercial availability and plan
  // entitlement are separate gates, checked in this order. A module that
  // isn't released yet stays unreachable no matter how high the user's
  // plan is — PRO does not unlock unreleased modules, and this check must
  // come BEFORE the plan check or exactly that bug is reintroduced.
  if (!module.commercialEnabled) return RouteDecision.redirectDenied;

  switch (module.minimumPlan) {
    case ModulePlan.admin:
      // Not admin (checked above) — admin-only/internal, never "upgrade".
      return RouteDecision.redirectDenied;
    case ModulePlan.pro:
      if (!profileResolved) return RouteDecision.redirectDenied;
      return isPro ? RouteDecision.allow : RouteDecision.redirectUpgrade;
    case ModulePlan.free:
      return RouteDecision.allow;
  }
}

/// IVE-COMMERCIAL-TARGETED-REMEDIATION-06S — commercial CTA consistency.
///
/// The route guard (decideForModule/evaluateRouteAccess above) decides what
/// happens when a navigation is ATTEMPTED. It says nothing about whether a
/// button that leads to a commercialEnabled:false module should look
/// clickable in the first place — dashboard_screen.dart's Personas/
/// Biblioteca/Calendário shortcuts already had a `locked` badge wired to
/// `!isPro && !isAdmin` (the wrong question — those three, like Campanhas,
/// Performance and Improve Post, are commercialEnabled:false, i.e. not
/// released to ANYONE yet, not "PRO-exclusive"), and Home's "Melhorar Post"
/// AppBar icon and several Executive Command Center quick actions had no
/// treatment at all. A user tapping any of these got real navigation that
/// the route guard would then immediately bounce — which reads as "this is
/// broken", not "this isn't available yet".
///
/// [isModuleActionable] answers exactly the "should this look like an
/// available operational feature" question, deliberately narrower than
/// [decideForModule]: it only cares about `commercialEnabled` (mission
/// section 07 — "must not look like an available operational feature" is
/// specifically about released-vs-not, not about plan tiers). A released
/// PRO-only module SHOULD still look actionable with an upgrade prompt on
/// tap — that's a legitimate, different "pay to unlock" UX, not a bug — so
/// this function does not consult minimumPlan at all. Same admin bypass as
/// the route guard, for the same reason: an admin actually can reach it.
///
/// An unclassified moduleId (a typo, or a module removed from the
/// registry) fails open (returns true) rather than silently hiding a real
/// button over what would then be a code bug elsewhere — exactly mirroring
/// decideForModule's own fail-open for unclassified routes.
bool isModuleActionable(String moduleId, {required bool isAdmin}) {
  if (isAdmin) return true;
  for (final m in kModuleRegistry) {
    if (m.moduleId == moduleId) return m.commercialEnabled;
  }
  return true;
}

/// Real-data wrapper around [decideForModule]: resolves [path] against the
/// actual kRouteModuleOwnership map and kModuleRegistry. This is what
/// lib/app.dart's redirect actually calls.
RouteDecision evaluateRouteAccess({
  required String path,
  required bool isAdmin,
  required bool isPro,
  required bool profileResolved,
}) {
  return decideForModule(
    module: _moduleForRoute(path),
    isAlwaysAllowed: kAlwaysAllowedRoutes.contains(path),
    isAdmin: isAdmin,
    isPro: isPro,
    profileResolved: profileResolved,
  );
}
