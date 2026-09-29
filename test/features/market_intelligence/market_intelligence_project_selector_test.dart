import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/features/market_intelligence/screens/market_intelligence_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (R14) — before this, a user starting an
// analysis directly from this screen (not via Project Command Center's
// `extra`) had no way to bind it to a real project; every analysis stayed
// project-less. This test proves the new dropdown lets the user pick a
// real, RLS-owned project and that the selection flows into the same
// `_projectId` state field the pre-existing `extra`-based path already
// used (verified indirectly: the "linked to project" banner, which was
// already gated on `_projectId != null` before this change, appears once
// a project is picked).
class _FakeProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => [
        Project(
          id: 'project-1',
          userId: 'user-1',
          name: 'Meu Projeto de Teste',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/market-intelligence',
    routes: [
      GoRoute(
        path: '/market-intelligence',
        builder: (_, __) => const MarketIntelligenceScreen(),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      projectsNotifierProvider.overrideWith(_FakeProjectsNotifier.new),
      marketAnalysesProvider.overrideWith((ref) async => const <MarketAnalysis>[]),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'MI-PROJECT-SELECTOR: dropdown lists the user\'s real projects and '
    'selecting one shows the "linked to project" banner',
    (tester) async {
      await _pump(tester);

      // The selector itself must be visible when no project arrived via
      // route `extra` (the only path that existed before this fix).
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
      expect(find.text('Nenhum'), findsOneWidget);

      // No project linked yet -- the pre-existing banner must not show.
      expect(find.byIcon(Icons.push_pin_rounded), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(find.text('Meu Projeto de Teste'), findsWidgets);

      await tester.tap(find.text('Meu Projeto de Teste').last);
      await tester.pumpAndSettle();

      // Selecting a real, owned project must flow into the same
      // `_projectId` state the pre-existing `extra`-based banner reads.
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    },
  );
}
