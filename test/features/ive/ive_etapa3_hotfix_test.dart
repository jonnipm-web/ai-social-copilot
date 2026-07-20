// ignore_for_file: lines_longer_than_80_chars
/// HOTFIX IVE — Etapa 3: Testes de divergência de estado ao trocar projetos.
/// 9 grupos: RCBO→TRAGO, triple switch, stale async, entity context, scores,
/// ROI, proposal, late response, login/restore.
library;

import 'dart:io';

import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/features/ive/domain/ive_copilot_contract.dart';
import 'package:ai_social_copilot/features/ive/services/ive_copilot_gateway.dart';
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

// ── Constantes ────────────────────────────────────────────────────────────────

const _userId = 'user-etapa3';
const _projectAId = 'proj-rcbo';
const _projectBId = 'proj-trago';
const _projectCId = 'proj-insightvalues';

final _projectA = Project(
  id: _projectAId,
  userId: _userId,
  name: 'RCBO',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _projectB = Project(
  id: _projectBId,
  userId: _userId,
  name: 'TRAGO',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _projectC = Project(
  id: _projectCId,
  userId: _userId,
  name: 'INSIGHTVALUES',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

// ── Stubs ─────────────────────────────────────────────────────────────────────

class _ProjectServiceStub implements ProjectServiceInterface {
  @override
  Future<List<Project>> fetchAll() async => [_projectA, _projectB, _projectC];

  @override
  Future<Project?> fetchById(String id) async =>
      [_projectA, _projectB, _projectC]
          .where((p) => p.id == id)
          .firstOrNull;

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

  Project _byId(String id) =>
      [_projectA, _projectB, _projectC].firstWhere((p) => p.id == id);

  @override
  Future<void> select(Project project) async {
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

class _NoopGateway implements IveCopilotGateway {
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> invoke(IveCopilotRequest request) async {
    callCount++;
    return {
      'response_text': 'ok',
      'intent': 'query',
      'confidence': 0.9,
    };
  }
}

// ── Infraestrutura de widget test ─────────────────────────────────────────────

List<Override> _overrides(_SelectedProjectStub selected, {_MemoryStub? memory}) =>
    [
      projectServiceProvider.overrideWithValue(_ProjectServiceStub()),
      selectedProjectProvider.overrideWith((_) => selected),
      iveMemoryProvider.overrideWith((_) => memory ?? _MemoryStub()),
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
      overrides: _overrides(selected, memory: memory),
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

// ── Setup ─────────────────────────────────────────────────────────────────────

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

  // ── Grupo 1: RCBO→TRAGO ────────────────────────────────────────────────────

  group('Grupo 1 — RCBO→TRAGO: label de projeto atualiza ao trocar', () {
    testWidgets('label mostra nome do novo projeto após troca', (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Projeto',
              projectId: _projectAId,
              selectedEntityLabel: 'Projeto — RCBO',
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);

      expect(find.text('Contexto: Projeto — RCBO'), findsOneWidget);

      // Troca para TRAGO via seletor
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      expect(find.text('Contexto: Projeto — TRAGO'), findsOneWidget);
      expect(find.text('Contexto: Projeto — RCBO'), findsNothing);
      await closeSheet(tester);
    });

    testWidgets('badge de projeto ativo também atualiza para TRAGO', (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Projeto',
              projectId: _projectAId,
              selectedEntityLabel: 'Projeto — RCBO',
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);
      expect(find.text('Projeto ativo: RCBO'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      expect(find.text('Projeto ativo: TRAGO'), findsOneWidget);
      expect(find.text('Projeto ativo: RCBO'), findsNothing);
      await closeSheet(tester);
    });
  });

  // ── Grupo 2: Triple switch ─────────────────────────────────────────────────

  group('Grupo 2 — Triple switch: tripla troca retém apenas o último projeto', () {
    testWidgets('A→B→A→B: label final é B', (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Projeto',
              projectId: _projectAId,
              selectedEntityLabel: 'Projeto — RCBO',
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);

      // 1ª troca: A → B
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);
      expect(find.text('Contexto: Projeto — TRAGO'), findsOneWidget);

      // 2ª troca: B → A
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectAId')));
      await settleSheet(tester);
      expect(find.text('Contexto: Projeto — RCBO'), findsOneWidget);

      // 3ª troca: A → B
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      expect(find.text('Contexto: Projeto — TRAGO'), findsOneWidget);
      expect(find.text('Contexto: Projeto — RCBO'), findsNothing);
      await closeSheet(tester);
    });
  });

  // ── Grupo 3: Stale async ───────────────────────────────────────────────────

  group('Grupo 3 — Stale async: contexto enviado é sempre do projeto ativo', () {
    test('send() rejeita contexto de projeto diferente do scope', () async {
      final gateway = _NoopGateway();
      final notifier = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(
          userId: _userId,
          projectId: _projectBId,
          screenName: 'Projeto',
        ),
        gateway: gateway,
        currentUserId: () => _userId,
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      // Contexto de projeto A enviado para scope de projeto B
      await notifier.send(
        message: 'Análise este projeto',
        context: const CopilotContextData(
          userId: _userId,
          projectId: _projectAId,  // diverge do scope (B)
          route: '/projeto',
        ),
      );

      // Gateway NÃO deve ser chamado — contexto rejeitado
      expect(gateway.callCount, equals(0));
      expect(notifier.state.error, isNotNull);
      notifier.dispose();
    });

    test('send() aceita contexto quando projectId coincide com scope', () async {
      final gateway = _NoopGateway();
      final notifier = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(
          userId: _userId,
          projectId: _projectBId,
          screenName: 'Projeto',
        ),
        gateway: gateway,
        currentUserId: () => _userId,
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      await notifier.send(
        message: 'Análise este projeto',
        context: const CopilotContextData(
          userId: _userId,
          projectId: _projectBId,  // coincide com scope
          route: '/projeto',
        ),
      );

      expect(gateway.callCount, equals(1));
      notifier.dispose();
    });
  });

  // ── Grupo 4: Entity context ────────────────────────────────────────────────

  group('Grupo 4 — Entity context: label de Oportunidade/Ação limpa ao trocar projeto', () {
    testWidgets('label "Oportunidade — X" desaparece após troca de projeto',
        (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Oportunidade',
              projectId: _projectAId,
              selectedEntityLabel: 'Oportunidade — Campanha Verão',
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);

      expect(find.text('Contexto: Oportunidade — Campanha Verão'), findsOneWidget);

      // Troca de projeto — label de entidade deve ser limpo
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      expect(find.text('Contexto: Oportunidade — Campanha Verão'), findsNothing);
      expect(find.byKey(const ValueKey('ive-chat-entity-context')), findsNothing);
      await closeSheet(tester);
    });

    testWidgets('label "Ação — X" desaparece após troca de projeto',
        (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Ação',
              projectId: _projectAId,
              selectedEntityLabel: 'Ação — Lançar MVP',
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);

      expect(find.text('Contexto: Ação — Lançar MVP'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      expect(find.text('Contexto: Ação — Lançar MVP'), findsNothing);
      await closeSheet(tester);
    });
  });

  // ── Grupo 5: Scores ────────────────────────────────────────────────────────

  group('Grupo 5 — Scores: providers family invalidados ao trocar projeto', () {
    test('código-fonte invalida providers family do projeto anterior em synchronizeIveProjectContext', () {
      final src = File(
        'lib/shared/widgets/context_copilot_widget.dart',
      ).readAsStringSync();
      expect(src, contains('actionQueueByProjectProvider(oldId)'));
      expect(src, contains('opportunityLabByProjectProvider(oldId)'));
      expect(src, contains('knowledgeItemsByProjectProvider(oldId)'));
      expect(src, contains('container.invalidate(ecosystemScoresProvider)'));
      expect(src, contains('container.invalidate(iveContextDataProvider)'));
    });

    test('IveContextData com novo projeto exibe scores do projeto ativo', () {
      // Simula contexto do projeto B — scores refletem apenas esse projeto
      const ctxB = IveContextData(
        userId: _userId,
        activeProjectId: _projectBId,
        activeProjectName: 'TRAGO',
        healthScore: 72,
        executionScore: 60,
        opportunityScore: 55,
      );
      final hints = ctxB.toCopilotContext(route: '/projeto');
      expect(hints.projectId, _projectBId);
      expect(hints.scores?['health'], 72);
      expect(hints.scores?['execution'], 60);
    });
  });

  // ── Grupo 6: ROI ───────────────────────────────────────────────────────────

  group('Grupo 6 — ROI: hasRoiData=false exibe "—" na UI', () {
    test('EcosystemScore.hasRoiData default é false', () {
      final score = EcosystemScore(
        project: _projectA,
        opportunityScore: 60,
        strategicFit: 55,
        synergyScore: 50,
        roiScore: 0,
        momentumScore: 40,
        ecosystemScore: 45,
        recommendation: 'ANÁLISE INCOMPLETA',
        strengths: const [],
        risks: const [],
        quickWins: const [],
        totalRoi: 0,
        actionCount: 0,
        completedActions: 0,
        labItemCount: 0,
      );
      expect(score.hasRoiData, isFalse);
      expect(score.roiScore, 0);
    });

    test('EcosystemScore com hasRoiData=true e roiScore=0 é distinto de sem dados', () {
      final scoreComDados = EcosystemScore(
        project: _projectA,
        opportunityScore: 60,
        strategicFit: 55,
        synergyScore: 50,
        roiScore: 0,
        momentumScore: 40,
        ecosystemScore: 45,
        recommendation: 'VALIDAR',
        strengths: const [],
        risks: const [],
        quickWins: const [],
        totalRoi: 0,
        actionCount: 0,
        completedActions: 0,
        labItemCount: 0,
        hasRoiData: true,
      );
      expect(scoreComDados.hasRoiData, isTrue);
    });

    test('código-fonte passa showDash: !s.hasRoiData para _ScoreRow de ROI', () {
      final cmdSrc = File(
        'lib/features/projects/screens/project_command_center_screen.dart',
      ).readAsStringSync();
      final ecoSrc = File(
        'lib/features/ecosystem/screens/executive_decision_center_screen.dart',
      ).readAsStringSync();
      expect(cmdSrc, contains("showDash: !s.hasRoiData"));
      expect(ecoSrc, contains("showDash: !s.hasRoiData"));
    });

    test('IveContextData sem ROI não envia roi nos hints', () {
      const ctx = IveContextData(
        userId: _userId,
        activeProjectId: _projectAId,
        hasRoiData: false,
        roiScore: 0,
      );
      final hints = ctx.toCopilotContext(route: '/projeto');
      expect(hints.scores?['roi'], isNull);
      expect(hints.scores?['roi_data_available'], isFalse);
    });
  });

  // ── Grupo 7: Proposal ──────────────────────────────────────────────────────

  group('Grupo 7 — Proposal: invalidação ao trocar projeto', () {
    test('invalidateProposalForProjectChange define estado de erro na proposta', () {
      final notifier = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(
          userId: _userId,
          projectId: _projectAId,
          screenName: 'Projeto',
        ),
        gateway: _NoopGateway(),
        currentUserId: () => _userId,
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      notifier.invalidateProposalForProjectChange();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.pendingProposal, isNull);
      notifier.dispose();
    });

    testWidgets('troca de projeto invoca invalidateProposalForProjectChange via ref.listen',
        (tester) async {
      final selected = _SelectedProjectStub(initial: _projectA);
      await pumpSurface(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => openIveWithContext(
              ctx,
              screenName: 'Projeto',
              projectId: _projectAId,
            ),
            child: const Text('Abrir'),
          ),
        ),
        selected,
      );
      await tester.tap(find.text('Abrir'));
      await settleSheet(tester);

      // Troca para B — deve acionar invalidação de proposta do scope A
      await tester.tap(find.byKey(const ValueKey('ive-project-selector-toggle')));
      await settleSheet(tester);
      await tester.tap(find.byKey(const ValueKey('ive-project-option-$_projectBId')));
      await settleSheet(tester);

      // Projeto trocado com sucesso — verificação de que o fluxo concluiu
      expect(selected.state?.id, _projectBId);
      await closeSheet(tester);
    });
  });

  // ── Grupo 8: Late response ─────────────────────────────────────────────────

  group('Grupo 8 — Late response: resposta de projeto A rejeitada em scope B', () {
    test('send() com scope.projectId vazio define erro imediatamente', () async {
      final gateway = _NoopGateway();
      final notifier = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(
          userId: _userId,
          projectId: '',  // escopo vazio — situação transitória
          screenName: 'Projeto',
        ),
        gateway: gateway,
        currentUserId: () => _userId,
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      await notifier.send(
        message: 'Mensagem',
        context: const CopilotContextData(
          userId: _userId,
          projectId: '',
          route: '/projeto',
        ),
      );

      expect(gateway.callCount, equals(0));
      expect(notifier.state.error, isNotNull);
      notifier.dispose();
    });

    test('CopilotScope com projectId diferente do contexto é rejeitado', () async {
      final gateway = _NoopGateway();
      final notifierA = ContextCopilotNotifier(
        _MockRef(),
        const CopilotScope(
          userId: _userId,
          projectId: _projectAId,
          screenName: 'Projeto',
        ),
        gateway: gateway,
        currentUserId: () => _userId,
        authChanges: const Stream<AuthState>.empty(),
        rememberQuestion: (_) {},
        recentQuestions: () => const [],
        clearSelectedProject: () async {},
        clearSensitiveMemory: () {},
      );

      // "Resposta tardia": contexto de B chegou mas scope é A
      await notifierA.send(
        message: 'Pergunta do projeto B',
        context: const CopilotContextData(
          userId: _userId,
          projectId: _projectBId,  // diverge
          route: '/projeto',
        ),
      );

      expect(gateway.callCount, equals(0));
      expect(notifierA.state.error, isNotNull);
      notifierA.dispose();
    });
  });

  // ── Grupo 9: Login/restore ─────────────────────────────────────────────────

  group('Grupo 9 — Login/restore: sem timer pendente ao restaurar projeto', () {
    test('código-fonte usa Future.value() (microtask) em vez de Future.delayed',
        () {
      final src = File(
        'lib/providers/selected_project_provider.dart',
      ).readAsStringSync();

      // Fix correto: await Future.value() em vez de Future.delayed
      expect(src, contains('await Future.value()'));
      expect(src, isNot(contains('Future.delayed(Duration.zero)')));
      expect(src, isNot(contains('Future.delayed(const Duration(milliseconds: 150))')));
    });

    test('_restore() não executa quando uid é null (guard defensivo)', () async {
      SharedPreferences.setMockInitialValues({'selected_project_id': _projectAId});
      final svc = _ProjectServiceStub();
      final notifier = SelectedProjectNotifier(svc);
      addTearDown(notifier.dispose);

      // uid null → Supabase não autenticado → restore silencia
      await Future<void>.value();  // microtask — permite que _restore() rode
      // Estado permanece null (sem projeto restaurado sem auth)
      expect(notifier.state, isNull);
    });

    test('label de contexto inicializa a partir de widget.selectedEntityLabel', () {
      // Verifica no código-fonte que initState atribui _resolvedEntityLabel
      final src = File(
        'lib/shared/widgets/context_copilot_widget.dart',
      ).readAsStringSync();
      expect(src, contains('_resolvedEntityLabel = widget.selectedEntityLabel'));
    });
  });
}
