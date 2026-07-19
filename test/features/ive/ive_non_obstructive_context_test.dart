import 'dart:io';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';
import 'package:ai_social_copilot/providers/selected_project_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'user-ive-03';
const _projectAId = 'project-a';
const _projectBId = 'project-b';

final _projectA = Project(
  id: _projectAId,
  userId: _userId,
  name: 'Projeto A',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _projectB = Project(
  id: _projectBId,
  userId: _userId,
  name: 'Projeto B',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _ProjectServiceStub implements ProjectServiceInterface {
  @override
  Future<List<Project>> fetchAll() async => [_projectA, _projectB];

  @override
  Future<Project?> fetchById(String id) async =>
      [_projectA, _projectB].where((project) => project.id == id).firstOrNull;

  @override
  Future<Project> create(Map<String, dynamic> data) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<Project> update(String id, Map<String, dynamic> data) =>
      throw UnimplementedError();
}

class _SelectedProjectStub extends SelectedProjectNotifier {
  _SelectedProjectStub({Project? initial}) : super(_ProjectServiceStub()) {
    state = initial;
  }

  @override
  Future<void> select(Project project) async => state = project;

  @override
  Future<Project> selectById(String projectId) async {
    final project = [_projectA, _projectB]
        .firstWhere((candidate) => candidate.id == projectId);
    state = project;
    return project;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  setUp(resetIveChatGateForTesting);

  List<Override> overrides(_SelectedProjectStub selected) => [
        projectServiceProvider.overrideWithValue(_ProjectServiceStub()),
        selectedProjectProvider.overrideWith((_) => selected),
        iveContextDataProvider.overrideWith((ref) async {
          final project = ref.watch(selectedProjectProvider);
          return IveContextData(
            userId: _userId,
            activeProjectId: project?.id,
            activeProjectName: project?.name,
            activeProjectStatus: project?.status,
          );
        }),
      ];

  Future<void> pumpOverlay(
    WidgetTester tester, {
    _SelectedProjectStub? selected,
    Widget? content,
    List<NavigatorObserver> observers = const [],
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          selected ?? _SelectedProjectStub(initial: _projectA),
        ),
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          navigatorObservers: observers,
          home: Scaffold(
            body: Stack(
              children: [
                content ?? const SizedBox.expand(),
                const IveOverlay()
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> transition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('1. IVE fechada mantém apenas launcher visível', (tester) async {
    await pumpOverlay(tester);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsNothing);
  });

  testWidgets('2. IVE aberta oculta launcher externo', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
  });

  testWidgets('3. IVE aberta oculta balão proativo externo', (tester) async {
    await pumpOverlay(tester);
    final element = tester.element(find.byType(IveOverlay));
    final container = ProviderScope.containerOf(element);
    container.read(iveProvider.notifier).showMessage('Insight relevante');
    await tester.pump();
    expect(find.byKey(const ValueKey('ive-bubble-chat-cta')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    expect(find.byKey(const ValueKey('ive-bubble-chat-cta')), findsNothing);
  });

  testWidgets('4. fechar IVE faz launcher reaparecer', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    await tester.tap(find.byKey(const ValueKey('ive-chat-close')));
    await transition(tester);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsOneWidget);
  });

  testWidgets('5. modal crítico suspende overlay e não bloqueia confirmar',
      (tester) async {
    await pumpOverlay(
      tester,
      observers: [IveRouteObserver()],
      content: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            key: const ValueKey('open-critical-modal'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Confirme antes de executar'),
                actions: [
                  TextButton(
                    key: const ValueKey('critical-confirm'),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ),
            child: const Text('Abrir modal'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-critical-modal')));
    await transition(tester);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('critical-confirm')));
    await transition(tester);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsOneWidget);
  });

  testWidgets('6. balão proativo expira automaticamente', (tester) async {
    await pumpOverlay(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IveOverlay)),
    );
    container.read(iveProvider.notifier).showMessage('Insight temporário');
    await tester.pump();
    expect(container.read(iveProvider).bubbleVisible, isTrue);
    await tester.pump(const Duration(seconds: 8));
    expect(container.read(iveProvider).bubbleVisible, isFalse);
  });

  testWidgets('7. balão fechado não reaparece no mesmo contexto',
      (tester) async {
    await pumpOverlay(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IveOverlay)),
    );
    const context = IveContextData(
      userId: _userId,
      activeProjectId: _projectAId,
      activeProjectName: 'Projeto A',
      pendingOpportunitiesCount: 2,
    );
    final notifier = container.read(iveProvider.notifier);
    notifier.showContextAwareMessage(context, AppConstants.routeOpportunityLab);
    expect(container.read(iveProvider).bubbleVisible, isTrue);
    notifier.dismissBubble();
    notifier.showContextAwareMessage(context, AppConstants.routeOpportunityLab);
    expect(container.read(iveProvider).bubbleVisible, isFalse);
  });

  testWidgets('8. troca Project A para Project B preserva UI correta',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpOverlay(tester, selected: selected);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
    await transition(tester);
    await tester
        .tap(find.byKey(const ValueKey('ive-project-option-project-b')));
    await transition(tester);
    expect(selected.state?.id, _projectBId);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
  });

  test('9. consultas server-side combinam ownership e projeto ativo', () {
    final source = File(
      'supabase/functions/context-copilot/index.ts',
    ).readAsStringSync();
    expect(source, contains(".eq('user_id', uid)"));
    expect(source, contains("oppQuery.eq('project_id', projectId)"));
    expect(source, contains("actQuery.eq('project_id', projectId)"));
  });

  test('10. query de oportunidade não usa coluna inexistente nem outro projeto',
      () {
    final source = File(
      'supabase/functions/context-copilot/index.ts',
    ).readAsStringSync();
    final opportunitySelect = RegExp(
      r"from\('opportunity_lab'\)[\s\S]*?\.select\('([^']+)'\)",
    ).firstMatch(source)!.group(1)!;
    expect(opportunitySelect, isNot(contains('impact_score')));
    expect(opportunitySelect, contains('project_id'));
    expect(opportunitySelect, contains('strategic_fit'));
    expect(opportunitySelect, contains('synergy_score'));
  });

  test('11. projeto sem oportunidades recebe instrução semântica', () {
    final source = File(
      'supabase/functions/context-copilot/context_prompt.ts',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'Este projeto ainda não possui oportunidades registradas no Opportunity Lab.',
      ),
    );
    expect(source, contains('gerar/analisar oportunidades'));
  });

  test('12. projeto com oportunidades fornece critérios para comparação', () {
    const context = IveContextData(
      userId: _userId,
      activeProjectId: _projectBId,
      activeProjectName: 'Projeto B',
      healthScore: 78,
      opportunityScore: 91,
      marketScore: 88,
      strategicFit: 93,
      synergyScore: 84,
      roiScore: 86,
      momentumScore: 80,
      executionScore: 72,
      pendingOpportunitiesSummary: [
        {
          'id': 'opp-b',
          'project_id': _projectBId,
          'final_score': 91,
          'market_score': 88,
          'revenue_score': 86,
          'strategic_fit': 93,
          'synergy_score': 84,
          'risks': ['Dependência de parceiro'],
        },
      ],
    );
    final copilot = context.toCopilotContext(route: '/opportunity-lab');
    expect(copilot.scores?['opportunity'], 91);
    expect(copilot.scores?['market'], 88);
    expect(copilot.scores?['strategic_fit'], 93);
    expect(copilot.scores?['synergy'], 84);
    expect(copilot.scores?['roi'], 86);
    expect(copilot.scores?['momentum'], 80);
    expect(copilot.opportunities.single['project_id'], _projectBId);
  });

  testWidgets('13. composer permanece utilizável com teclado aberto',
      (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    await tester.tap(find.byKey(const ValueKey('ive-chat-input')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.byKey(const ValueKey('ive-chat-input')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
  });

  testWidgets('14. conteúdo rolável termina acima do composer', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await transition(tester);
    final inputTop = tester
        .getTopLeft(
          find.byKey(const ValueKey('ive-chat-input')),
        )
        .dy;
    final scrollables = find.byType(Scrollable);
    expect(scrollables, findsWidgets);
    final contentBottom = tester.getBottomLeft(scrollables.first).dy;
    expect(contentBottom, lessThanOrEqualTo(inputTop));
  });
}
