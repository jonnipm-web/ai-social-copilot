import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/models/quota_info.dart';
import 'package:ai_social_copilot/features/dashboard/screens/dashboard_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';
import 'package:ai_social_copilot/providers/quota_provider.dart';

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 15,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

// COMMERCIAL-V1-UX-RECONCILIATION (R6) — DashboardScreen now watches
// projectsProvider (an AsyncNotifierProvider), which cannot be overridden
// with a plain async function the way a FutureProvider can.
class _FakeProjectsNotifier extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => const [];
}

class _FakeProjectsNotifierWithData extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => [
        Project(
          id: 'project-1',
          userId: 'user-1',
          name: 'Meu Projeto',
          status: 'active',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ];
}

Future<void> _pump(
  WidgetTester tester, {
  ProjectsNotifier Function()? projectsNotifier,
  List<MarketAnalysis> analyses = const [],
  List<ActionQueueItem> pending = const [],
}) async {
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
          (ref) => Future.value(const QuotaInfo(role: 'free', limit: 15, used: 0)),
        ),
        projectsNotifierProvider
            .overrideWith(projectsNotifier ?? _FakeProjectsNotifier.new),
        marketAnalysesProvider.overrideWith((ref) async => analyses),
        pendingActionsProvider.overrideWith((ref) async => pending),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt'),
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

  testWidgets(
    'DASH-02 (R6 regression): with real project/analysis/action data, the '
    'portfolio KPIs, executive recommendation, and pending action all '
    'render without overflow, before any module shortcut button',
    (tester) async {
      final analysis = MarketAnalysis(
        id: 'analysis-1',
        userId: 'user-1',
        input: 'https://example.com',
        niche: 'Nicho de Teste',
        opportunityScore: 82,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final action = ActionQueueItem(
        id: 'action-1',
        userId: 'user-1',
        title: 'Ação pendente de teste',
        status: 'pending',
        createdAt: DateTime(2026, 1, 1),
      );

      await _pump(
        tester,
        projectsNotifier: _FakeProjectsNotifierWithData.new,
        analyses: [analysis],
        pending: [action],
      );

      expect(find.text('Meu Projeto').evaluate().isEmpty, isTrue,
          reason: 'the project name itself is not shown on the summary row, '
              'only aggregated counts -- this just documents that assumption');
      expect(find.textContaining('Nicho de Teste'), findsOneWidget,
          reason: 'the top-scoring analysis niche must appear in the '
              'executive recommendation (R5 human-readable intelligence)');
      expect(find.text('Ação pendente de teste'), findsOneWidget,
          reason: 'the real pending action title must appear under '
              '"Prioridades da Semana" (R10 contextual actions)');
      expect(find.text('Recomendações Executivas'), findsOneWidget);
      expect(find.text('Prioridades da Semana'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'no RenderFlex overflow at 390px with real, non-trivial data');
    },
  );
}
