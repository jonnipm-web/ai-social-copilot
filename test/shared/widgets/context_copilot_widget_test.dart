import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/data/models/ive_interaction_request.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';

// COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Sections 09/10/12) — proves:
// (1) desktop gets a centered Dialog, materially larger than the mobile
//     bottom sheet, not the same cramped bottom-anchored presentation;
// (2) the empty state shows the real IveAvatar (03B2 portrait path) and
//     no duplicate chat-bubble emoji anywhere in the sheet/dialog;
// (3) the action suggestion chip is now tappable and actually navigates.
//
// diagnosticLoggerProvider is overridden with a mock -- same pattern as
// ive_intro_sheet_test.dart / ive_overlay_auth_gate_test.dart: its real
// definition eagerly reads Supabase.instance.client, which throws in a
// plain test process. This suite never calls _send()/_ensureConfirmed(),
// so quota/AiExecutionController's Supabase access is never reached.
class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

class _FakeCopilotNotifier extends ContextCopilotNotifier {
  _FakeCopilotNotifier(Ref ref, CopilotState seed) : super(ref) {
    state = seed;
  }
}

void main() {
  // iveChatOpenNotifier is a top-level singleton (state persists across
  // testWidgets calls within this file/isolate); several tests here open
  // a sheet/dialog without popping it before the test ends. Reset before
  // each test so ordering never matters (mirrors ive_overlay_auth_gate_test.dart).
  setUp(() => iveChatOpenNotifier.value = false);

  // Size is controlled via tester.view.physicalSize in each test (same
  // pattern already established by ive_overlay_auth_gate_test.dart's tests
  // E/F/G) -- MaterialApp derives its own MediaQuery from the real test
  // View, so a manually-wrapped ancestor MediaQuery here would be ignored.
  Widget harness({
    CopilotState? seedState,
    CopilotConversationKey? seedKey,
    List<GoRoute> extraRoutes = const [],
  }) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCopilotChat(
                  context,
                  screenName: 'Projetos',
                  request: IveInteractionRequest(
                    sourceModule:  'test',
                    operationType: IveOperationType.ask,
                  ),
                  contextData: const CopilotContextData(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(path: AppConstants.routeActionEngine, builder: (_, __) => const Scaffold(body: Text('Action Engine screen'))),
        GoRoute(path: AppConstants.routeOpportunityLab, builder: (_, __) => const Scaffold(body: Text('Opportunity Lab screen'))),
        GoRoute(path: AppConstants.routeProjects, builder: (_, __) => const Scaffold(body: Text('Projects screen'))),
        ...extraRoutes,
      ],
    );

    return ProviderScope(
      overrides: [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
        if (seedState != null && seedKey != null)
          contextCopilotProvider(seedKey).overrideWith((ref) => _FakeCopilotNotifier(ref, seedState)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('mobile width opens a draggable bottom sheet', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // Not pumpAndSettle: IveAvatar's ring-pulse animation never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('desktop width opens a centered dialog, materially larger than the mobile sheet', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    final size = tester.getSize(find.byType(IveAvatar));
    // hero avatar (220dp) must actually be laid out at its real size, not
    // clipped/shrunk by an undersized dialog.
    expect(size.width, closeTo(220, 1));
  });

  testWidgets('empty state shows the real IveAvatar and no duplicate chat-bubble emoji', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(IveAvatar), findsOneWidget);
    expect(find.textContaining('💬'), findsNothing);
    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.text(l10n.iveChatAskCta), findsOneWidget);
    // Header no longer pairs a redundant emoji with the "IVE" title.
    expect(find.text('IVE'), findsOneWidget);
  });

  testWidgets('screen name is localized (EN) in the empty state', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, __) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showCopilotChat(
                  context,
                  screenName: 'Projetos',
                  request: IveInteractionRequest(sourceModule: 'test', operationType: IveOperationType.ask),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService())],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10nEn = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10nEn.iveScreenProjects), findsOneWidget); // "Projects"
    expect(find.text('Projetos'), findsNothing);
  });

  testWidgets('action suggestion chip is tappable and navigates to the mapped route', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = ('Projetos', null);
    final seed = CopilotState(turns: [
      CopilotTurn(
        role:    'assistant',
        content: 'Você deveria criar uma ação para isso.',
        actionSuggestion: const CopilotActionSuggestion(
          type:  'create_action',
          label: 'Criar ação: revisar contrato',
          data:  {'title': 'revisar contrato'},
        ),
        timestamp: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(harness(seedState: seed, seedKey: key));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Criar ação: revisar contrato'), findsOneWidget);
    await tester.tap(find.text('Criar ação: revisar contrato'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    expect(find.text('Action Engine screen'), findsOneWidget);
    // The dialog/sheet actually closed as part of handling the tap.
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('action suggestion with no mapped destination shows an honest message instead of navigating', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const key = ('Projetos', null);
    final seed = CopilotState(turns: [
      CopilotTurn(
        role:    'assistant',
        content: 'Aqui está um roadmap sugerido.',
        actionSuggestion: const CopilotActionSuggestion(
          type:  'generate_roadmap',
          label: 'Gerar roadmap',
          data:  {},
        ),
        timestamp: DateTime(2026, 1, 1),
      ),
    ]);

    await tester.pumpWidget(harness(seedState: seed, seedKey: key));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Gerar roadmap'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.text(l10n.iveActionNoDestination), findsOneWidget);
    // Stays open -- there is nowhere honest to navigate to.
    expect(find.byType(Dialog), findsOneWidget);
  });
}
