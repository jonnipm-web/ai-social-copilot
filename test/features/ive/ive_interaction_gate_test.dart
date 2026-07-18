import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/data/services/project_service.dart';
import 'package:ai_social_copilot/features/action_engine/screens/action_detail_screen.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';
import 'package:ai_social_copilot/providers/selected_project_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _userId = 'user-test';
const _projectId = 'project-test';

final _project = Project(
  id: _projectId,
  userId: _userId,
  name: 'Projeto Build Week',
  status: 'active',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _action = ActionQueueItem(
  id: 'action-42',
  userId: _userId,
  projectId: _projectId,
  opportunityLabId: 'opportunity-7',
  title: 'Publicar campanha executiva',
  status: 'approved',
  priority: 90,
  impactScore: 88,
  effortScore: 34,
  roiScore: 91,
  createdAt: DateTime(2026),
);

class _ProjectServiceStub implements ProjectServiceInterface {
  @override
  Future<Project> create(Map<String, dynamic> data) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<List<Project>> fetchAll() async => [_project];
  @override
  Future<Project?> fetchById(String id) async => _project;
  @override
  Future<Project> update(String id, Map<String, dynamic> data) =>
      throw UnimplementedError();
}

class _SelectedProjectStub extends SelectedProjectNotifier {
  _SelectedProjectStub() : super(_ProjectServiceStub()) {
    state = _project;
  }
}

final _overrides = <Override>[
  selectedProjectProvider.overrideWith((ref) => _SelectedProjectStub()),
  iveContextDataProvider.overrideWith(
    (ref) async => const IveContextData(
      userId: _userId,
      activeProjectId: _projectId,
      activeProjectName: 'Projeto Build Week',
      activeProjectStatus: 'active',
    ),
  ),
];

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

  setUp(() {
    resetIveChatGateForTesting();
  });

  void configureS25Surface(WidgetTester tester) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.reset);
  }

  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pumpOverlay(WidgetTester tester) async {
    configureS25Surface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: const Scaffold(
            body: Stack(
              children: [SizedBox.expand(), IveOverlay()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(IveOverlay)));

  Future<void> showBubble(WidgetTester tester) async {
    container(tester)
        .read(iveProvider.notifier)
        .showMessage('Mensagem de teste');
    await tester.pump();
    expect(find.byKey(const ValueKey('ive-bubble-chat-cta')), findsOneWidget);
  }

  Future<void> closeChat(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('ive-chat-close')));
    await pumpTransition(tester);
  }

  testWidgets('1. tap real no avatar abre a IVE', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('2. tap real em Conversar com a IVE abre o mesmo chat',
      (tester) async {
    await pumpOverlay(tester);
    await showBubble(tester);
    await tester.tap(find.byKey(const ValueKey('ive-bubble-chat-cta')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('3. tap real no CTA da ação abre a IVE', (tester) async {
    configureS25Surface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: Scaffold(body: IveActionAskButton(item: _action)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('4. contexto completo da ação chega ao chat', (tester) async {
    configureS25Surface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          navigatorKey: iveRootNavigatorKey,
          home: Scaffold(body: IveActionAskButton(item: _action)),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ive-action-ask-cta')));
    await pumpTransition(tester);
    expect(find.text('Contexto: Ação — ${_action.title}'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('ive-chat-input')),
    );
    expect(field.decoration?.hintText, 'Pergunte algo sobre esta ação...');
    await closeChat(tester);
  });

  testWidgets('5. projeto ativo é preservado na abertura', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.text('Projeto ativo: ${_project.name}'), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('6. dois taps não abrem duas instâncias', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await tester.tap(
      find.byKey(const ValueKey('ive-overlay-avatar')),
      warnIfMissed: false,
    );
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('7. balão visível não intercepta o alvo do avatar',
      (tester) async {
    await pumpOverlay(tester);
    await showBubble(tester);
    expect(
      tester.getRect(find.byKey(const ValueKey('ive-overlay-avatar'))).size,
      const Size(56, 56),
    );
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('8. avatar abre no primeiro tap com balão visível',
      (tester) async {
    await pumpOverlay(tester);
    await showBubble(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ive-bubble-chat-cta')).hitTestable(),
      findsNothing,
    );
    await closeChat(tester);
  });

  testWidgets('9. fechar e reabrir funciona', (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    await closeChat(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('10. troca de rota mantém abertura pelo avatar', (tester) async {
    await pumpOverlay(tester);
    container(tester)
        .read(iveProvider.notifier)
        .setRoute(AppConstants.routeActionEngine);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    expect(find.byKey(const ValueKey('ive-chat-sheet')), findsOneWidget);
    await closeChat(tester);
  });

  testWidgets('11. tap real no campo abre o teclado e recebe foco',
      (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    await tester.tap(find.byKey(const ValueKey('ive-chat-input')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
    await closeChat(tester);
  });

  testWidgets('12. botão enviar aceita tap real após digitação',
      (tester) async {
    await pumpOverlay(tester);
    await tester.tap(find.byKey(const ValueKey('ive-overlay-avatar')));
    await pumpTransition(tester);
    await tester.tap(find.byKey(const ValueKey('ive-chat-input')));
    await tester.enterText(
      find.byKey(const ValueKey('ive-chat-input')),
      'Qual é a prioridade?',
    );
    final send = tester.widget<IconButton>(
      find.byKey(const ValueKey('ive-chat-send')),
    );
    expect(send.onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('ive-chat-send')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await closeChat(tester);
  });
}
