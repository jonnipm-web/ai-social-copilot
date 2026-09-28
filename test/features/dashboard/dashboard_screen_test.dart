import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/data/models/quota_info.dart';
import 'package:ai_social_copilot/features/dashboard/screens/dashboard_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/providers/quota_provider.dart';

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 5,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: AppConstants.routeDashboard,
    routes: [
      GoRoute(
        path: AppConstants.routeDashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppConstants.routeGenerate,
        builder: (_, __) => const Scaffold(body: Text('CONTENT_GENERATION_SCREEN_MARKER')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith((ref) => Future.value(_fakeProfile())),
        currentQuotaProvider.overrideWith(
          (ref) => Future.value(const QuotaInfo(role: 'free', limit: 5, used: 0)),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'DASH-01 (regression) "Melhorar Post com IA" navigates to routeGenerate, '
    'not back to the current dashboard route',
    (tester) async {
      await _pump(tester);

      expect(find.text('Melhorar Post com IA'), findsOneWidget);
      expect(find.text('CONTENT_GENERATION_SCREEN_MARKER'), findsNothing);

      await tester.tap(find.text('Melhorar Post com IA'));
      await tester.pumpAndSettle();

      expect(find.text('CONTENT_GENERATION_SCREEN_MARKER'), findsOneWidget);
    },
  );
}
