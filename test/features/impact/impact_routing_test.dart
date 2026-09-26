import 'dart:io';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/modules/module_definition.dart';
import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/core/modules/route_policy.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_dossier_screen.dart';
import 'package:ai_social_copilot/features/impact/screens/impact_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ai_social_copilot/features/impact/providers/impact_providers.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';

import 'impact_test_support.dart';

/// IV-IMPACT-I5 — entry points: route policy (admin-only) and deep links.
void main() {
  group('UI-RT route policy', () {
    for (final path in [AppConstants.routeImpact, AppConstants.routeImpactDossier]) {
      test('UI-RT-01 $path: non-admin (even PRO/premium/beta) is denied', () {
        expect(routeMayBeRestricted(path), isTrue);
        expect(
          evaluateRouteAccess(path: path, isAdmin: false, isPro: true, isPremium: true, isBetaTester: true, profileResolved: true),
          RouteDecision.redirectDenied,
        );
        expect(evaluateRouteAccess(path: path, isAdmin: false, isPro: false, profileResolved: false), RouteDecision.redirectDenied);
      });

      test('UI-RT-02 $path: admin is allowed', () {
        expect(evaluateRouteAccess(path: path, isAdmin: true, isPro: false, profileResolved: true), RouteDecision.allow);
      });
    }

    test('UI-RT-03 module stays EXPERIMENTAL, not commercial, admin entry only', () {
      final m = kModuleRegistry.firstWhere((m) => m.moduleId == 'impact');
      expect(m.lifecycle, ModuleLifecycle.experimental);
      expect(m.commercialEnabled, isFalse);
      expect(m.route, AppConstants.routeImpact);
      expect(m.adminClickable, isTrue);
    });

    test('UI-RT-04 both routes are registered in app.dart with the policy map', () {
      final app = File('lib/app.dart').readAsStringSync();
      expect(app, contains('path: AppConstants.routeImpact,'));
      expect(app, contains('path: AppConstants.routeImpactDossier,'));
      expect(kRouteModuleOwnership[AppConstants.routeImpact], 'impact');
      expect(kRouteModuleOwnership[AppConstants.routeImpactDossier], 'impact');
    });
  });

  testWidgets('UI-RT-05 deep link /impact/<id> opens that dossier', (tester) async {
    final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'));
    final router = GoRouter(
      initialLocation: '/impact/$kInvestigationId',
      routes: [
        GoRoute(
          path: AppConstants.routeImpactDossier,
          builder: (_, s) => ImpactDossierScreen(investigationId: s.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        impactTransportProvider.overrideWithValue(tr),
        currentProfileProvider.overrideWith((ref) => Future.value(profile())),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Live view'), findsOneWidget);
    expect(tr.calls.single['investigation_id'], kInvestigationId);
  });

  testWidgets('UI-RT-06 (PF-03) list → dossier keeps history: back arrow shown, Back returns to the list (never leaves the module)', (tester) async {
    final tr = FakeImpactTransport(dossier: fixture('dossier_confirmed_en'), list: fixture('list_investigations'));
    final router = GoRouter(
      initialLocation: AppConstants.routeImpact,
      routes: [
        GoRoute(path: AppConstants.routeImpact, builder: (_, __) => const ImpactHomeScreen()),
        GoRoute(path: AppConstants.routeImpactDossier, builder: (_, s) => ImpactDossierScreen(investigationId: s.pathParameters['id']!)),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        impactTransportProvider.overrideWithValue(tr),
        currentProfileProvider.overrideWith((ref) => Future.value(profile())),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('«org-hopebridge»'));
    await tester.pumpAndSettle();
    expect(find.byType(ImpactDossierScreen), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget, reason: 'the dossier offers a way back');
    expect(router.canPop(), isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ImpactHomeScreen), findsOneWidget);
  });
}
