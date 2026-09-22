// IVE-COMMERCIAL-TARGETED-REMEDIATION-06R — regression coverage for the
// route-level commercial/plan entitlement gate (mission section 09's
// required case list, plus the invariant it explicitly asks for).
//
// Scope note: "anonymous → protected route → login" is NOT covered here —
// that's the pre-existing, unchanged three-line session check at the top of
// lib/app.dart's redirect (session == null && !goingToAuth → routeLogin),
// which this mission did not touch and which requires a live Supabase
// session / widget test to exercise meaningfully. Everything this file's
// functions actually decide (decideForModule/evaluateRouteAccess) assumes
// the caller already established the user is authenticated — exactly the
// "pure policy logic... tested without requiring full Supabase integration"
// split the mission asked for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/modules/module_definition.dart';
import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/core/constants/app_constants.dart';

ModuleDefinition _module({
  required bool commercialEnabled,
  required ModulePlan minimumPlan,
  String moduleId = 'synthetic',
}) =>
    ModuleDefinition(
      moduleId: moduleId,
      namePt: 'Sintético',
      nameEn: 'Synthetic',
      status: ModuleStatus.active,
      adminVisible: true,
      adminClickable: true,
      commercialEnabled: commercialEnabled,
      minimumPlan: minimumPlan,
      readinessPt: 'test',
      readinessEn: 'test',
      releaseClassification: ModuleReleaseClass.commercialV1,
    );

void main() {
  group('decideForModule — mission section 09 required cases', () {
    test('FREE -> FREE commercial route -> allow', () {
      final module = _module(commercialEnabled: true, minimumPlan: ModulePlan.free);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.allow,
      );
    });

    test('FREE -> PRO commercial route -> redirectUpgrade', () {
      final module = _module(commercialEnabled: true, minimumPlan: ModulePlan.pro);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.redirectUpgrade,
      );
    });

    test('PRO -> PRO commercial route -> allow', () {
      final module = _module(commercialEnabled: true, minimumPlan: ModulePlan.pro);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: true, profileResolved: true),
        RouteDecision.allow,
      );
    });

    test('FREE -> commercialEnabled=false route -> redirectDenied', () {
      final module = _module(commercialEnabled: false, minimumPlan: ModulePlan.free);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.redirectDenied,
      );
    });

    test(
      'PRO -> commercialEnabled=false route -> redirectDenied '
      '(the exact trap mission section 05 names: PRO must NOT unlock an unreleased module)',
      () {
        final module = _module(commercialEnabled: false, minimumPlan: ModulePlan.pro);
        expect(
          decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: true, profileResolved: true),
          RouteDecision.redirectDenied,
        );
      },
    );

    test('FREE -> admin/internal route -> redirectDenied', () {
      final module = _module(commercialEnabled: false, minimumPlan: ModulePlan.free, moduleId: 'internal-admin-only');
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.redirectDenied,
      );
    });

    test('PRO -> admin/internal route -> redirectDenied (PRO plan does not imply admin)', () {
      final module = _module(commercialEnabled: false, minimumPlan: ModulePlan.free, moduleId: 'internal-admin-only');
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: true, profileResolved: true),
        RouteDecision.redirectDenied,
      );
    });

    test('ADMIN -> preserve authorized admin behavior (reaches everything, even unreleased/admin-only)', () {
      for (final module in [
        _module(commercialEnabled: false, minimumPlan: ModulePlan.free),
        _module(commercialEnabled: false, minimumPlan: ModulePlan.pro),
        _module(commercialEnabled: false, minimumPlan: ModulePlan.free, moduleId: 'internal-admin-only'),
      ]) {
        expect(
          decideForModule(module: module, isAlwaysAllowed: false, isAdmin: true, isPro: false, profileResolved: true),
          RouteDecision.allow,
          reason: 'admin denied for module ${module.moduleId} (commercialEnabled=${module.commercialEnabled}, minimumPlan=${module.minimumPlan})',
        );
      }
    });

    test('FREE -> upgrade/account/about/support (isAlwaysAllowed) -> allow regardless of module', () {
      // isAlwaysAllowed=true short-circuits before the module is even
      // consulted, matching how evaluateRouteAccess never looks the module
      // up for these paths (routeMayBeRestricted returns false for them).
      final wouldOtherwiseBeDenied = _module(commercialEnabled: false, minimumPlan: ModulePlan.pro);
      expect(
        decideForModule(module: wouldOtherwiseBeDenied, isAlwaysAllowed: true, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.allow,
      );
    });

    test('unknown/unclassified route (module == null) -> allow (fail safe, do not break navigation)', () {
      expect(
        decideForModule(module: null, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.allow,
      );
    });

    test('profile not yet resolved on a PRO route -> redirectDenied, never allow, never treated as PRO', () {
      final module = _module(commercialEnabled: true, minimumPlan: ModulePlan.pro);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: false),
        RouteDecision.redirectDenied,
      );
    });

    test('profile not resolved has no effect on a FREE route (no profile needed to decide)', () {
      final module = _module(commercialEnabled: true, minimumPlan: ModulePlan.free);
      expect(
        decideForModule(module: module, isAlwaysAllowed: false, isAdmin: false, isPro: false, profileResolved: false),
        RouteDecision.allow,
      );
    });
  });

  group('evaluateRouteAccess — real registry wiring', () {
    test('nested/contextual V1 route inherits its owning hub\'s entitlement (free, allowed)', () {
      // gap-analysis (route:null after Remediation 06) is reached via
      // /market-intelligence/gaps/:id, not its own drawer item — must still
      // resolve to the same free-and-released entitlement as the hub.
      expect(
        evaluateRouteAccess(
          path: AppConstants.routeMarketIntelligenceGaps,
          isAdmin: false,
          isPro: false,
          profileResolved: true,
        ),
        RouteDecision.allow,
      );
      expect(
        evaluateRouteAccess(
          path: AppConstants.routeKnowledgeStrategy,
          isAdmin: false,
          isPro: false,
          profileResolved: true,
        ),
        RouteDecision.allow,
      );
    });

    test('real PRO-gated-but-unreleased routes deny even a PRO user (personas/content/calendar)', () {
      for (final path in [
        AppConstants.routePersonas,
        AppConstants.routeContent,
        AppConstants.routeCalendar,
      ]) {
        expect(
          evaluateRouteAccess(path: path, isAdmin: false, isPro: true, profileResolved: true),
          RouteDecision.redirectDenied,
          reason: '$path should deny even a PRO user (commercialEnabled:false)',
        );
      }
    });

    test('real unreleased free-plan routes deny non-admin users (campaigns/performance/ecosystem/etc.)', () {
      for (final path in [
        AppConstants.routeCampaigns,
        AppConstants.routePerformance,
        AppConstants.routeRoiTracker,
        AppConstants.routeEcosystem,
        AppConstants.routeEcosystemResources,
        AppConstants.routeEcosystemBriefing,
        AppConstants.routeExecutiveDashboard,
        AppConstants.routeAdvisorOnboarding,
        AppConstants.routeGenerate,
        AppConstants.routeResult,
      ]) {
        expect(
          evaluateRouteAccess(path: path, isAdmin: false, isPro: false, profileResolved: true),
          RouteDecision.redirectDenied,
          reason: '$path should be denied (commercialEnabled:false in the real registry)',
        );
      }
    });

    test(
      'IVE-COMMERCIAL-OBSERVABILITY-07B — real /admin route denies non-admin '
      '(PRO and FREE) direct navigation, allows an admin',
      () {
        for (final isPro in [true, false]) {
          expect(
            evaluateRouteAccess(path: AppConstants.routeAdmin, isAdmin: false, isPro: isPro, profileResolved: true),
            RouteDecision.redirectDenied,
            reason: 'non-admin (isPro=$isPro) must be denied direct /admin navigation',
          );
        }
        expect(
          evaluateRouteAccess(path: AppConstants.routeAdmin, isAdmin: true, isPro: false, profileResolved: true),
          RouteDecision.allow,
        );
      },
    );

    test('admin-only real route (intelligence-debug) denies a non-admin PRO user', () {
      expect(
        evaluateRouteAccess(
          path: AppConstants.routeIntelligenceDebug,
          isAdmin: false,
          isPro: true,
          profileResolved: true,
        ),
        RouteDecision.redirectDenied,
      );
    });

    test('unclassified real route (history) allows unconditionally', () {
      expect(
        evaluateRouteAccess(path: AppConstants.routeHistory, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.allow,
      );
      expect(
        evaluateRouteAccess(path: AppConstants.routeHistoryDetail, isAdmin: false, isPro: false, profileResolved: true),
        RouteDecision.allow,
      );
    });
  });

  group('redirect-loop safety', () {
    test('the redirectUpgrade target (routeUpgrade) always resolves to allow, for any user', () {
      for (final isAdmin in [true, false]) {
        for (final isPro in [true, false]) {
          for (final profileResolved in [true, false]) {
            expect(
              evaluateRouteAccess(path: AppConstants.routeUpgrade, isAdmin: isAdmin, isPro: isPro, profileResolved: profileResolved),
              RouteDecision.allow,
              reason: 'routeUpgrade must never itself redirect (isAdmin=$isAdmin isPro=$isPro profileResolved=$profileResolved)',
            );
          }
        }
      }
    });

    test('the redirectDenied target (routeDashboard) always resolves to allow, for any user', () {
      for (final isAdmin in [true, false]) {
        for (final isPro in [true, false]) {
          for (final profileResolved in [true, false]) {
            expect(
              evaluateRouteAccess(path: AppConstants.routeDashboard, isAdmin: isAdmin, isPro: isPro, profileResolved: profileResolved),
              RouteDecision.allow,
              reason: 'routeDashboard must never itself redirect (isAdmin=$isAdmin isPro=$isPro profileResolved=$profileResolved)',
            );
          }
        }
      }
    });

    test('account/about/support (preserved Remediation 06 routes) always resolve to allow', () {
      for (final path in [AppConstants.routeAccount, AppConstants.routeAbout, AppConstants.routeSupport]) {
        expect(
          evaluateRouteAccess(path: path, isAdmin: false, isPro: false, profileResolved: true),
          RouteDecision.allow,
        );
      }
    });
  });

  group('invariants', () {
    test(
      'no commercially-enabled=false module in the real registry is ever reachable by a non-admin, '
      'regardless of plan (mission section 05\'s CRITICAL RULE, generalized across the whole registry)',
      () {
        final offenders = <String>[];
        for (final module in kModuleRegistry) {
          if (module.commercialEnabled) continue;
          for (final isPro in [true, false]) {
            final decision = decideForModule(
              module: module,
              isAlwaysAllowed: false,
              isAdmin: false,
              isPro: isPro,
              profileResolved: true,
            );
            if (decision == RouteDecision.allow) {
              offenders.add('${module.moduleId} (isPro=$isPro)');
            }
          }
        }
        expect(offenders, isEmpty, reason: 'Offending module/plan combos: $offenders');
      },
    );

    test(
      'every GoRoute path actually registered in lib/app.dart resolves through either '
      'kRouteModuleOwnership or kAlwaysAllowedRoutes (splash/login excluded — resolved earlier '
      'in app.dart, before this policy is ever consulted)',
      () {
        // Mirrors lib/app.dart's GoRoute list exactly. If a route is added
        // there without being classified here, this test fails instead of
        // the new route silently falling through to "unclassified -> allow"
        // unnoticed.
        const allAppRoutes = [
          AppConstants.routeDashboard,
          AppConstants.routeHome,
          AppConstants.routeGenerate,
          AppConstants.routeResult,
          AppConstants.routeHistory,
          AppConstants.routeHistoryDetail,
          AppConstants.routeUpgrade,
          AppConstants.routePersonas,
          AppConstants.routePersonaNew,
          AppConstants.routePersonaEdit,
          AppConstants.routeContent,
          AppConstants.routeContentNew,
          AppConstants.routeContentEdit,
          AppConstants.routeCalendar,
          AppConstants.routeAdmin,
          AppConstants.routeAccount,
          AppConstants.routeAbout,
          AppConstants.routeSupport,
          AppConstants.routeKnowledge,
          AppConstants.routeKnowledgeNew,
          AppConstants.routeKnowledgeEdit,
          AppConstants.routeKnowledgeAnalysis,
          AppConstants.routeKnowledgeStrategy,
          AppConstants.routeCampaigns,
          AppConstants.routeCampaignNew,
          AppConstants.routeCampaignDetail,
          AppConstants.routeWebsiteAnalyzer,
          AppConstants.routeWebsiteAnalysisResult,
          AppConstants.routePerformance,
          AppConstants.routePersonaTraining,
          AppConstants.routeMarketIntelligence,
          AppConstants.routeMarketIntelligenceCompetitors,
          AppConstants.routeMarketIntelligenceGaps,
          AppConstants.routeMarketIntelligenceOpportunities,
          AppConstants.routeMarketIntelligenceNiches,
          AppConstants.routeMarketIntelligenceCluster,
          AppConstants.routeMarketIntelligenceRevenue,
          AppConstants.routeMarketIntelligenceHub,
          AppConstants.routeProjects,
          AppConstants.routeRoiTracker,
          AppConstants.routeEcosystem,
          AppConstants.routeEcosystemResources,
          AppConstants.routeEcosystemBriefing,
          AppConstants.routeAdvisorOnboarding,
          AppConstants.routeOpportunityLab,
          AppConstants.routeOpportunityDetail,
          AppConstants.routeActionEngine,
          AppConstants.routeActionDetail,
          AppConstants.routeExecutiveDashboard,
          AppConstants.routeIntelligenceDebug,
        ];

        final unresolved = allAppRoutes
            .where((r) =>
                !kRouteModuleOwnership.containsKey(r) &&
                !kAlwaysAllowedRoutes.contains(r) &&
                !kDeliberatelyUnclassifiedRoutes.contains(r))
            .toList();
        expect(unresolved, isEmpty, reason: 'Unclassified app.dart routes (would silently fail-open): $unresolved');
      },
    );

    test(
      'every GoRoute path in lib/app.dart SOURCE is classified -- derived from the '
      'source file, not a hand-maintained mirror',
      () {
        // MODULE-PORTFOLIO-ARCHITECTURE-01 (Codex CX-02): the test above
        // mirrors app.dart's route list by hand, so a route added to
        // app.dart but not to that list would still fall through to
        // "unclassified -> allow" with CI green. Module Lab ships modules
        // dark (commercialEnabled:false, route-denied), which only holds if
        // every real route is classified. This test reads the routes from
        // the source itself.
        final appSource = File('lib/app.dart').readAsStringSync();
        final constantsSource =
            File('lib/core/constants/app_constants.dart').readAsStringSync();

        final routeValues = <String, String>{
          for (final m in RegExp(r"static const (route\w+)\s*=\s*'([^']*)'")
              .allMatches(constantsSource))
            m.group(1)!: m.group(2)!,
        };
        final routeNames = RegExp(r'path:\s*AppConstants\.(route\w+)')
            .allMatches(appSource)
            .map((m) => m.group(1)!)
            .toList();

        // A GoRoute declared with a literal path (not an AppConstants
        // constant) would escape the extraction above -- fail loudly instead.
        expect(routeNames.length, RegExp(r'GoRoute\(').allMatches(appSource).length,
            reason: 'Every GoRoute in app.dart must use `path: AppConstants.routeX`');
        expect(routeNames, isNotEmpty);

        const resolvedEarlier = {AppConstants.routeSplash, AppConstants.routeLogin};
        final unresolved = <String>[];
        for (final name in routeNames) {
          final path = routeValues[name];
          expect(path, isNotNull, reason: 'AppConstants.$name not found in app_constants.dart');
          if (resolvedEarlier.contains(path)) continue;
          if (!kRouteModuleOwnership.containsKey(path) &&
              !kAlwaysAllowedRoutes.contains(path) &&
              !kDeliberatelyUnclassifiedRoutes.contains(path)) {
            unresolved.add('$name ($path)');
          }
        }
        expect(unresolved, isEmpty,
            reason: 'Unclassified app.dart routes (would silently fail-open): $unresolved');
      },
    );

    test('every moduleId referenced in kRouteModuleOwnership exists in kModuleRegistry', () {
      final knownIds = kModuleRegistry.map((m) => m.moduleId).toSet();
      final danglingRefs = kRouteModuleOwnership.entries
          .where((e) => !knownIds.contains(e.value))
          .map((e) => '${e.key} -> ${e.value}')
          .toList();
      expect(danglingRefs, isEmpty, reason: 'Dangling module references: $danglingRefs');
    });
  });

  group('isModuleActionable — mission section 07 commercial CTA consistency (06S)', () {
    test('a commercialEnabled:false module is not actionable for a non-admin', () {
      expect(isModuleActionable('improve-post', isAdmin: false), isFalse);
    });

    test('the same commercialEnabled:false module IS actionable for an admin (preserve admin behavior)', () {
      expect(isModuleActionable('improve-post', isAdmin: true), isTrue);
    });

    test('a commercialEnabled:true, released module remains actionable for a non-admin (no regression)', () {
      for (final moduleId in ['command-center', 'knowledge-vault', 'market-intelligence', 'opportunity-lab']) {
        expect(
          isModuleActionable(moduleId, isAdmin: false),
          isTrue,
          reason: '$moduleId is commercialEnabled:true and must remain actionable',
        );
      }
    });

    test('PRO-gated-but-unreleased modules (personas/content-library/calendar) are not actionable for a non-admin', () {
      // Mirrors the route guard's own CRITICAL RULE: commercialEnabled
      // gates the CTA regardless of minimumPlan -- these are "not released
      // to anyone", not "PRO-exclusive".
      for (final moduleId in ['personas', 'content-library', 'calendar', 'campaigns', 'performance']) {
        expect(
          isModuleActionable(moduleId, isAdmin: false),
          isFalse,
          reason: '$moduleId is commercialEnabled:false and must not look actionable',
        );
      }
    });

    test('an unclassified moduleId fails open (true) rather than silently hiding a real button', () {
      expect(isModuleActionable('this-module-does-not-exist', isAdmin: false), isTrue);
    });
  });
}
