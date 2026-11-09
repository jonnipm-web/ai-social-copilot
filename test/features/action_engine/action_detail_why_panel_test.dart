import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/features/action_engine/screens/action_detail_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';
import 'package:ai_social_copilot/providers/opportunity_lab_provider.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';

// HANDOFF action-detail §1–3 — an action created by the bootstrap carries
// no description/reason of its own. The page must explain it through the
// opportunity that produced it, show priority as a rank (not a score bar)
// and explain what each score measures.
class _FakeProjects extends ProjectsNotifier {
  @override
  Future<List<Project>> build() async => [];
}

final _action = ActionQueueItem(
  id: 'act-1',
  userId: 'u1',
  opportunityLabId: 'opp-12345678',
  actionType: 'produto',
  title: 'Criar curso de inteligência financeira infantil',
  priority: 1,
  impactScore: 90,
  effortScore: 80,
  roiScore: 85,
  createdAt: DateTime(2026, 7, 15),
);

final _opp = OpportunityLabItem(
  id: 'opp-12345678',
  userId: 'u1',
  title: 'Educação financeira para crianças',
  description: 'Pais buscam conteúdo de finanças para os filhos.',
  rationale: 'Demanda crescente e pouca concorrência em PT-BR.',
  createdAt: DateTime(2026, 7, 15),
);

Future<void> _pump(WidgetTester tester, {OpportunityLabItem? opp}) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/action-engine/act-1',
    routes: [
      GoRoute(
        path: '/action-engine/:id',
        builder: (_, s) => ActionDetailScreen(itemId: s.pathParameters['id']!),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      projectsNotifierProvider.overrideWith(_FakeProjects.new),
      actionQueueItemByIdProvider.overrideWith((ref, id) async => _action),
      opportunityLabItemByIdProvider.overrideWith((ref, id) async => opp),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('shows why the action exists, from its opportunity',
      (tester) async {
    await _pump(tester, opp: _opp);

    expect(find.text('Por que esta ação existe'), findsOneWidget);
    expect(find.text('Educação financeira para crianças'), findsOneWidget);
    expect(find.text('Demanda crescente e pouca concorrência em PT-BR.'),
        findsOneWidget);
    expect(find.text('Ver oportunidade'), findsOneWidget);
  });

  testWidgets('origin no longer claims the action was added manually',
      (tester) async {
    await _pump(tester, opp: _opp);

    expect(find.text('Adicionado manualmente'), findsNothing);
    expect(find.text('Criada automaticamente (análise inicial do projeto)'),
        findsOneWidget);
  });

  testWidgets('priority is a rank badge and each score is explained',
      (tester) async {
    await _pump(tester, opp: _opp);

    expect(find.textContaining('#1'), findsWidgets);
    expect(find.text('Posição na fila — 1 é a mais importante'),
        findsOneWidget);
    expect(find.text('Trabalho necessário — quanto maior, mais difícil'),
        findsOneWidget);
    expect(find.text('Potencial de faturamento'), findsOneWidget);
  });

  testWidgets('without an opportunity it says no reason was recorded',
      (tester) async {
    await _pump(tester, opp: null);

    expect(find.text('Por que esta ação existe'), findsOneWidget);
    expect(find.text('Nenhum motivo foi registrado para esta ação.'),
        findsOneWidget);
  });
}
