import 'dart:io';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/features/action_engine/screens/action_detail_screen.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/features/opportunity_lab/screens/opportunity_detail_screen.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:ai_social_copilot/providers/ive_memory_provider.dart';
import 'package:ai_social_copilot/providers/project_provider.dart';
import 'package:ai_social_copilot/providers/selected_project_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'user-hotfix-02';
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

final _opportunityB = OpportunityLabItem(
  id: 'opportunity-b',
  userId: _userId,
  projectId: _projectBId,
  title: 'Oportunidade B',
  finalScore: 91,
  createdAt: DateTime(2026),
);

final _actionB = ActionQueueItem(
  id: 'action-b',
  userId: _userId,
  projectId: _projectBId,
  title: 'Ação B',
  status: 'approved',
  priority: 90,
  impactScore: 88,
  effortScore: 35,
  roiScore: 92,
  createdAt: DateTime(2026),
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
  _SelectedProjectStub({Project? initial, this.delay = Duration.zero})
      : super(_ProjectServiceStub()) {
    state = initial;
  }

  final Duration delay;
  final selectedIds = <String>[];

  Project _byId(String id) =>
      [_projectA, _projectB].firstWhere((project) => project.id == id);

  @override
  Future<void> select(Project project) async {
    selectedIds.add(project.id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    state = project;
  }

  @override
  Future<Project> selectById(String projectId) async {
    final project = _byId(projectId);
    await select(project);
    return project;
  }

  @override
  Future<void> clear() async => state = null;
}

class _MemoryStub extends IveMemoryNotifier {
  bool cleared = false;

  @override
  Future<void> clearProjectContext() async {
    cleared = true;
    await super.clearProjectContext();
  }
}

class _MockRef extends Mock implements Ref {}

class _FailingGateway implements IveCopilotGateway {
  _FailingGateway(this.error);

  final Object error;

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) =>
      Future<Map<String, dynamic>>.error(error);
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

  List<Override> overrides(
    _SelectedProjectStub selected, {
    _MemoryStub? memory,
  }) =>
      [
        projectServiceProvider.overrideWithValue(_ProjectServiceStub()),
        selectedProjectProvider.overrideWith((_) => selected),
        if (memory != null)
          iveMemoryProvider.overrideWith((_) => memory)
        else
          iveMemoryProvider.overrideWith((_) => _MemoryStub()),
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

  Future<void> pumpSurface(
    WidgetTester tester,
    Widget child,
    _SelectedProjectStub selected, {
    _MemoryStub? memory,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(selected, memory: memory),
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tap(
      find.byKey(const ValueKey('ive-chat-close')),
      warnIfMissed: false,
    );
    await settleSheet(tester);
  }

  testWidgets('1. Opportunity Detail abre IVE com projeto correto',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(
      tester,
      IveOpportunityAskButton(item: _opportunityB),
      selected,
    );
    await tester.tap(find.byKey(const ValueKey('ive-opportunity-ask-cta')));
    await settleSheet(tester);
    expect(selected.state?.id, _projectBId);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('2. Opportunity ID é propagado', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(
      tester,
      IveOpportunityAskButton(item: _opportunityB),
      selected,
    );
    await tester.tap(find.byKey(const ValueKey('ive-opportunity-ask-cta')));
    await settleSheet(tester);
    expect(
        find.text('Contexto: Oportunidade — Oportunidade B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('3. Action Detail abre IVE com projeto correto', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(tester, IveActionAskButton(item: _actionB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await settleSheet(tester);
    expect(selected.state?.id, _projectBId);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('4. Action ID é propagado', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(tester, IveActionAskButton(item: _actionB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await settleSheet(tester);
    expect(find.text('Contexto: Ação — Ação B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('5. projeto explícito substitui selectedProject antigo',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(
            context,
            screenName: 'Contextual',
            projectId: _projectBId,
          ),
          child: const Text('Abrir'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Abrir'));
    await settleSheet(tester);
    expect(selected.state?.id, _projectBId);
    expect(selected.selectedIds, [_projectBId]);
    await closeSheet(tester);
  });

  testWidgets('6. avatar global usa selectedProject válido', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(
            context,
            screenName: 'Global',
          ),
          child: const Text('Avatar'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Avatar'));
    await settleSheet(tester);
    expect(find.text('Projeto ativo: Projeto A'), findsOneWidget);
    expect(selected.selectedIds, isEmpty);
    await closeSheet(tester);
  });

  testWidgets('7. sem projeto abre seletor funcional', (tester) async {
    final selected = _SelectedProjectStub();
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(context, screenName: 'Global'),
          child: const Text('Avatar'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Avatar'));
    await settleSheet(tester);
    expect(find.byKey(const ValueKey('ive-project-selector')), findsOneWidget);
    expect(find.text('Projeto A'), findsOneWidget);
    expect(find.text('Projeto B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('8. selecionar projeto atualiza provider', (tester) async {
    final selected = _SelectedProjectStub();
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(context, screenName: 'Global'),
          child: const Text('Avatar'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Avatar'));
    await settleSheet(tester);
    await tester
        .tap(find.byKey(const ValueKey('ive-project-option-project-b')));
    await settleSheet(tester);
    expect(selected.state?.id, _projectBId);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    await closeSheet(tester);
  });

  testWidgets('9. seleção habilita campo de mensagem', (tester) async {
    final selected = _SelectedProjectStub();
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(context, screenName: 'Global'),
          child: const Text('Avatar'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Avatar'));
    await settleSheet(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ive-chat-input')))
          .enabled,
      isFalse,
    );
    await tester
        .tap(find.byKey(const ValueKey('ive-project-option-project-b')));
    await settleSheet(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('ive-chat-input')))
          .enabled,
      isTrue,
    );
    await closeSheet(tester);
  });

  test('10. Request V2 recebe project_id correto e contrato completo', () {
    final request = IveCopilotRequest.fromConversation(
      message: 'Analise esta oportunidade.',
      projectId: _projectBId,
      route: '/opportunity-lab/${_opportunityB.id}',
      screenName: 'Detalhe da Oportunidade',
      context: CopilotContextData(
        userId: _userId,
        projectId: _projectBId,
        route: '/opportunity-lab/${_opportunityB.id}',
      ),
      turns: const [],
      recentQuestions: const ['Pergunta anterior'],
      selectedEntityType: 'opportunity',
      selectedEntityId: _opportunityB.id,
    ).toMap();
    expect(request['project_id'], _projectBId);
    expect(
        request.keys,
        containsAll(<String>[
          'message',
          'project_id',
          'route',
          'screen_name',
          'selected_entity_type',
          'selected_entity_id',
          'context_version',
          'recent_questions',
          'client_correlation_id',
        ]));
    expect(request, isNot(contains('user_id')));
    expect(request, isNot(contains('tokens')));
    expect(request, isNot(contains('secrets')));
  });

  testWidgets('11. troca de projeto limpa contexto sensível anterior',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    final memory = _MemoryStub();
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(
            context,
            screenName: 'Contextual',
            projectId: _projectBId,
          ),
          child: const Text('Abrir'),
        ),
      ),
      selected,
      memory: memory,
    );
    await tester.tap(find.text('Abrir'));
    await settleSheet(tester);
    expect(memory.cleared, isTrue);
    await closeSheet(tester);
  });

  test('12. resposta 404 continua limpando selectedProjectProvider', () async {
    var cleared = false;
    final notifier = ContextCopilotNotifier(
      _MockRef(),
      const CopilotScope(
        userId: _userId,
        projectId: _projectBId,
        screenName: 'Teste',
      ),
      gateway: _FailingGateway(
        const IveCopilotHttpException(
          status: 404,
          code: 'NOT_FOUND',
          message: 'Projeto não autorizado.',
        ),
      ),
      currentUserId: () => _userId,
      authChanges: const Stream<AuthState>.empty(),
      rememberQuestion: (_) {},
      recentQuestions: () => const [],
      clearSelectedProject: () async => cleared = true,
      clearSensitiveMemory: () {},
    );
    await notifier.send(
      message: 'Pergunta',
      context: const CopilotContextData(
        userId: _userId,
        projectId: _projectBId,
        route: '/teste',
      ),
    );
    expect(cleared, isTrue);
    notifier.dispose();
  });

  test('13. resposta 401 continua limpando memória sensível', () async {
    var cleared = false;
    final notifier = ContextCopilotNotifier(
      _MockRef(),
      const CopilotScope(
        userId: _userId,
        projectId: _projectBId,
        screenName: 'Teste',
      ),
      gateway: _FailingGateway(
        const IveCopilotHttpException(
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Sessão expirada.',
        ),
      ),
      currentUserId: () => _userId,
      authChanges: const Stream<AuthState>.empty(),
      rememberQuestion: (_) {},
      recentQuestions: () => const [],
      clearSelectedProject: () async {},
      clearSensitiveMemory: () => cleared = true,
    );
    await notifier.send(
      message: 'Pergunta',
      context: const CopilotContextData(
        userId: _userId,
        projectId: _projectBId,
        route: '/teste',
      ),
    );
    expect(cleared, isTrue);
    notifier.dispose();
  });

  test('14. Lab e Action Engine não mantêm projectId local concorrente', () {
    final lab = File(
      'lib/features/opportunity_lab/screens/opportunity_lab_screen.dart',
    ).readAsStringSync();
    final action = File(
      'lib/features/action_engine/screens/action_engine_screen.dart',
    ).readAsStringSync();
    expect(lab, isNot(contains('String? _projectId')));
    expect(action, isNot(contains('String? _projectId')));
    expect(lab, contains('ref.watch(selectedProjectProvider)'));
    expect(action, contains('ref.watch(selectedProjectProvider)'));
  });

  testWidgets('15. abertura contextual aguarda propagação sem race condition',
      (tester) async {
    final selected = _SelectedProjectStub(
      initial: _projectA,
      delay: const Duration(milliseconds: 250),
    );
    await pumpSurface(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openIveWithContext(
            context,
            screenName: 'Contextual',
            projectId: _projectBId,
          ),
          child: const Text('Abrir'),
        ),
      ),
      selected,
    );
    await tester.tap(find.text('Abrir'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsNothing);
    await settleSheet(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    await closeSheet(tester);
  });

  test('16. pergunta contextual preserva entity_type e entity_id', () {
    final request = IveCopilotRequest.fromConversation(
      message: 'Analise esta oportunidade.',
      projectId: _projectBId,
      route: '/opportunity-lab/${_opportunityB.id}',
      screenName: 'Detalhe da Oportunidade',
      context: CopilotContextData(
        userId: _userId,
        projectId: _projectBId,
        route: '/opportunity-lab/${_opportunityB.id}',
      ),
      turns: const [],
      recentQuestions: const [],
      selectedEntityType: 'opportunity',
      selectedEntityId: _opportunityB.id,
    ).toMap();
    expect(request['selected_entity_type'], 'opportunity');
    expect(request['selected_entity_id'], _opportunityB.id);
    expect(request['project_id'], isNot(_projectAId));
  });
}
