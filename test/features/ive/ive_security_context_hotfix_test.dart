import 'dart:async';
import 'dart:io';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/features/action_engine/screens/action_detail_screen.dart';
import 'package:ai_social_copilot/features/auth/screens/login_screen.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_presentation_state.dart';
import 'package:ai_social_copilot/features/opportunity_lab/screens/opportunity_detail_screen.dart';
import 'package:ai_social_copilot/features/projects/screens/project_command_center_screen.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
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

const _userId = 'user-ive-04';

final _projectA = Project(
  id: 'project-a',
  userId: _userId,
  name: 'Projeto A',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _projectB = Project(
  id: 'project-b',
  userId: _userId,
  name: 'Projeto B',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _actionB = ActionQueueItem(
  id: 'action-b',
  userId: _userId,
  projectId: _projectB.id,
  title: 'Ação B',
  createdAt: DateTime(2026),
);

final _opportunityB = OpportunityLabItem(
  id: 'opportunity-b',
  userId: _userId,
  projectId: _projectB.id,
  title: 'Oportunidade B',
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

  @override
  Future<void> clear() async => state = null;
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

  Future<void> pumpGate(
    WidgetTester tester,
    StreamController<String?> auth, {
    Widget child = const LoginScreen(),
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authenticatedUserIdProvider.overrideWith((_) => auth.stream),
          ...overrides,
        ],
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: Scaffold(
            body: Stack(children: [child, const AuthenticatedIveOverlay()]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<Override> projectOverrides(_SelectedProjectStub selected) => [
        projectServiceProvider.overrideWithValue(_ProjectServiceStub()),
        selectedProjectProvider.overrideWith((_) => selected),
        iveContextDataProvider.overrideWith((ref) async {
          final project = ref.watch(selectedProjectProvider);
          return IveContextData(
            userId: _userId,
            activeProjectId: project?.id,
            activeProjectName: project?.name,
          );
        }),
      ];

  Future<void> pumpCta(
    WidgetTester tester,
    Widget cta,
    _SelectedProjectStub selected,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: projectOverrides(selected),
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: Scaffold(body: Center(child: cta)),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('1. login sem sessão não renderiza IVE', (tester) async {
    final auth = StreamController<String?>();
    addTearDown(auth.close);
    await pumpGate(tester, auth);
    auth.add(null);
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(IveOverlay), findsNothing);
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
    expect(find.textContaining('Projeto ativo:'), findsNothing);
  });

  testWidgets('2. sem sessão não carrega contexto de negócio', (tester) async {
    var contextLoads = 0;
    final auth = StreamController<String?>();
    addTearDown(auth.close);
    await pumpGate(
      tester,
      auth,
      child: const SizedBox.expand(),
      overrides: [
        iveContextDataProvider.overrideWith((_) async {
          contextLoads++;
          return const IveContextData();
        }),
      ],
    );
    auth.add(null);
    await tester.pump();
    expect(contextLoads, 0);
    expect(find.byType(IveOverlay), findsNothing);
  });

  testWidgets('3. logout remove IVE e limpa estado imediatamente',
      (tester) async {
    final auth = StreamController<String?>();
    final selected = _SelectedProjectStub(initial: _projectA);
    addTearDown(auth.close);
    await pumpGate(
      tester,
      auth,
      child: const SizedBox.expand(),
      overrides: projectOverrides(selected),
    );
    auth.add(_userId);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuthenticatedIveOverlay)),
    );
    container.read(iveProvider.notifier).showMessage('Projeto confidencial');
    await tester.pump();
    expect(find.byType(IveOverlay), findsOneWidget);

    auth.add(null);
    await tester.pump();
    expect(find.byType(IveOverlay), findsNothing);
    expect(container.read(iveProvider).message, isEmpty);
    expect(container.read(selectedProjectProvider), isNull);
  });

  testWidgets('4. CTAs contextuais permanecem visíveis', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                IveProjectAskButton(project: _projectA),
                IveActionAskButton(item: _actionB),
                IveOpportunityAskButton(item: _opportunityB),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ive-project-ask-cta')), findsOneWidget);
    expect(find.byKey(const ValueKey('ive-action-ask-cta')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ive-opportunity-ask-cta')), findsOneWidget);
  });

  testWidgets('5. CTA action abre entidade e projeto corretos', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpCta(tester, IveActionAskButton(item: _actionB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await settleSheet(tester);
    expect(selected.state?.id, _projectB.id);
    expect(find.text('Contexto: Ação — Ação B'), findsOneWidget);
  });

  testWidgets('6. CTA opportunity abre entidade e projeto corretos',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpCta(
        tester, IveOpportunityAskButton(item: _opportunityB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-opportunity-ask-cta')));
    await settleSheet(tester);
    expect(selected.state?.id, _projectB.id);
    expect(
        find.text('Contexto: Oportunidade — Oportunidade B'), findsOneWidget);
  });

  test('7. composer possui SafeArea e padding animado de navegação', () {
    final source = File('lib/shared/widgets/context_copilot_widget.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('ive-composer-animated-padding')"));
    expect(source, contains('viewPadding.bottom'));
    expect(source, contains('SafeArea('));
    expect(source, contains('bottom: true'));
  });

  testWidgets('8. teclado não cobre nem desabilita o composer', (tester) async {
    final selected = _SelectedProjectStub(initial: _projectB);
    await pumpCta(tester, IveActionAskButton(item: _actionB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await settleSheet(tester);
    await tester.tap(find.byKey(const ValueKey('ive-chat-input')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.byKey(const ValueKey('ive-chat-input')).hitTestable(),
        findsOneWidget);
    expect(find.byKey(const ValueKey('ive-chat-send')).hitTestable(),
        findsOneWidget);
  });

  test('9. insert de action_queue não envia confidence ausente', () {
    expect(_actionB.toInsertMap(), isNot(contains('confidence')));
  });

  test('10. indicadores usam nome amigável sem expor id', () {
    final source = File(
      'supabase/functions/context-copilot/context_prompt.ts',
    ).readAsStringSync();
    expect(source, contains('## PROJECT (validado pelo servidor)'));
    expect(source, contains('## INDICADORES ESTRATÉGICOS'));
    expect(source, contains(r'${name} — Ecosystem Score'));
    expect(source, isNot(contains(r'Project ${name} (${id})')));
  });

  test('11. prompt proíbe tratar score do projeto como global', () {
    final source = File(
      'supabase/functions/context-copilot/index.ts',
    ).readAsStringSync();
    expect(source, isNot(contains('## SCORES DO ECOSSISTEMA')));
    expect(source, contains('Nunca descreva esses scores como globais'));
    expect(
        source, contains('preciso abrir/carregar também os dados autorizados'));
  });

  testWidgets('12. troca de projeto reconstrói contexto correto',
      (tester) async {
    final selected = _SelectedProjectStub(initial: _projectA);
    await pumpCta(tester, IveActionAskButton(item: _actionB), selected);
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await settleSheet(tester);
    expect(find.text('Projeto ativo: Projeto B'), findsOneWidget);
    expect(find.textContaining('Projeto ativo: Projeto A'), findsNothing);
  });

  testWidgets('13. launcher externo fica oculto com chat aberto',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: Stack(children: [IveOverlay()])),
        ),
      ),
    );
    ivePresentationController.setChatOpen(true);
    await tester.pump();
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
  });

  testWidgets('14. CTA interno funciona com launcher externo oculto',
      (tester) async {
    ivePresentationController.setChatOpen(true);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                IveActionAskButton(item: _actionB),
                const IveOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('ive-overlay-avatar')), findsNothing);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('ive-action-ask-cta')),
    );
    expect(button.onPressed, isNotNull);
  });
}
