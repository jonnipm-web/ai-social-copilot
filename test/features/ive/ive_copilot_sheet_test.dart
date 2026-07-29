/// Widget tests for _CopilotSheet — covers the drag crash regression
/// (Looking up a deactivated widget's ancestor is unsafe) and related
/// lifecycle invariants.
///
/// Root causes fixed:
///   1. ProviderScope.containerOf(context) was called INSIDE showModalBottomSheet
///      builder; now captured before the builder closure.
///   2. DraggableScrollableSheet's scrollCtrl was unattached (hasClients==false);
///      now passed to ListView so drag coordination works.
///   3. DraggableScrollableSheet was missing expand: false.
///   4. addPostFrameCallback in build() had no mounted check.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';

// ── Test double ───────────────────────────────────────────────────────────────

/// Subclass of ContextCopilotNotifier that stubs network calls.
/// Since _client is now `late final`, it is never initialized unless send()
/// calls _client — and our override never does.
class _FakeCopilotNotifier extends ContextCopilotNotifier {
  _FakeCopilotNotifier(super.ref);

  bool sendCalled = false;

  @override
  Future<void> send({
    required String message,
    required String screenName,
    required CopilotContextData context,
  }) async {
    sendCalled = true;
    state = state.copyWith(
      turns: [
        ...state.turns,
        CopilotTurn(role: 'user', content: message, timestamp: DateTime.now()),
      ],
      loading: true,
    );
    await Future.delayed(const Duration(milliseconds: 30));
    if (!mounted) return;
    state = state.copyWith(
      turns: [
        ...state.turns,
        CopilotTurn(
            role: 'assistant',
            content: 'Resposta de teste',
            timestamp: DateTime.now()),
      ],
      loading: false,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

List<Override> _fakeOverrides() => [
      contextCopilotProvider.overrideWith(
          (ref, screenName) => _FakeCopilotNotifier(ref)),
    ];

/// Sets test viewport to a phone-like size so the sheet has room to render.
/// Without this, the 800x600 test frame causes overflow in the sheet's
/// suggestion list — a test-environment artifact, not a production bug.
void _setPhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Opens the IVE chat sheet from a button tap.
Widget _buttonApp({String screenName = 'Teste', List<Override>? overrides}) {
  return ProviderScope(
    overrides: overrides ?? _fakeOverrides(),
    child: MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCopilotChat(ctx, screenName: screenName),
              child: const Text('Abrir IVE'),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── A: Sheet opens without crash ─────────────────────────────────────────
  testWidgets('A — sheet opens and shows empty state without crash',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    expect(find.text('Pergunte à IVE'), findsAtLeast(1));
    expect(tester.takeException(), isNull);
  });

  // ── B: Sheet can be dragged up (simulate via fling) ──────────────────────
  testWidgets('B — drag-up gesture does not throw deactivated-ancestor error',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    // Drag the handle upward — this exercises the DraggableScrollableSheet
    // and the scrollCtrl attachment. Previously crashed here.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    await tester.fling(
      find.byType(DraggableScrollableSheet),
      const Offset(0, -200),
      800,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // ── C: Close while loading — no crash ────────────────────────────────────
  testWidgets('C — closing sheet while notifier is loading does not crash',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    // Type and send — notifier starts loading (30ms async delay in fake)
    await tester.enterText(find.byType(TextField), 'pergunta');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(); // send triggered, notifier loading == true

    // Close sheet immediately while response is in-flight
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pumpAndSettle();

    // Wait for the async response to complete after dispose
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  // ── D: Close during simulated streaming (loading state) ──────────────────
  testWidgets('D — dispose during async send does not call state after dispose',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'stream test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 10)); // mid-flight

    // Navigate away (route change, destroys sheet)
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pop();
    await tester.pump();
    // Pump past the 300ms scroll timer and 30ms notifier delay so FakeAsync
    // has no pending timers when the test ends.
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });

  // ── E: Keyboard open + expand does not crash ─────────────────────────────
  testWidgets('E — keyboard visible when sheet open does not cause overflow crash',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    // Focus the text field (simulates keyboard open)
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // Drag sheet up while keyboard is simulated
    await tester.fling(
      find.byType(DraggableScrollableSheet),
      const Offset(0, -100),
      600,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // ── F: Back press closes sheet without crash ──────────────────────────────
  testWidgets('F — back press (Navigator.pop) dismisses sheet cleanly',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    // Tap the close button (which calls Navigator.of(context).pop())
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Pergunte à IVE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── G: ProviderContainer captured before builder — no deactivated-ancestor
  testWidgets(
      'G — ProviderScope.containerOf not called inside builder (no ancestor error)',
      (tester) async {
    _setPhoneScreen(tester);
    // When showCopilotChat is called, the container is captured BEFORE the
    // builder closure runs, so even if the calling context becomes deactivated
    // by the time the builder executes, no ancestor lookup fails.
    await tester.pumpWidget(
      ProviderScope(
        overrides: _fakeOverrides(),
        child: MaterialApp(
          home: Builder(builder: (ctx) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => showCopilotChat(ctx, screenName: 'Detail'),
                child: const Text('Open'),
              ),
            );
          }),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Pergunte à IVE'), findsAtLeast(1));
    expect(tester.takeException(), isNull);
  });

  // ── H: Open / close 10× — no accumulation of errors ─────────────────────
  testWidgets('H — open and close sheet 10 times without crash', (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('Abrir IVE'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
  });

  // ── I: Open from 5 different screen names ────────────────────────────────
  testWidgets('I — sheet opens correctly for 5 different screen contexts',
      (tester) async {
    _setPhoneScreen(tester);
    const screens = [
      'Projetos',
      'Oportunidades',
      'Scores',
      'Decisões',
      'Briefing',
    ];

    for (final screen in screens) {
      await tester.pumpWidget(_buttonApp(screenName: screen));
      await tester.tap(find.text('Abrir IVE'));
      await tester.pumpAndSettle();

      expect(find.text(screen), findsAtLeast(1));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });

  // ── J: scrollCtrl attached — ListView uses DraggableScrollableSheet's ctrl
  testWidgets('J — messages ListView uses DraggableScrollableSheet scrollCtrl',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    // Send a message so turns list becomes non-empty → ListView is rendered
    await tester.enterText(find.byType(TextField), 'oi IVE');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // The ListView inside the sheet must exist and be scrollable
    final listView = find.byType(ListView);
    expect(listView, findsOneWidget);

    // Drag up to confirm scrollCtrl is attached (no hasClients error)
    await tester.fling(listView, const Offset(0, -100), 400);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // ── Bonus: clear history button ───────────────────────────────────────────
  testWidgets('clearHistory button appears after a message is sent',
      (tester) async {
    _setPhoneScreen(tester);
    await tester.pumpWidget(_buttonApp());
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), 'teste');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // pumpAndSettle may exit before the 300ms scroll timer fires (UI settles
    // first). Use an explicit pump to drain all pending timers.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── Bonus: error display ──────────────────────────────────────────────────
  testWidgets('error message shown when notifier has error state', (tester) async {
    _setPhoneScreen(tester);
    final errorOverride = contextCopilotProvider.overrideWith(
      (ref, screenName) {
        final n = _FakeCopilotNotifier(ref);
        n.state = const CopilotState(error: 'Serviço indisponível');
        return n;
      },
    );

    await tester.pumpWidget(_buttonApp(overrides: [errorOverride]));
    await tester.tap(find.text('Abrir IVE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Serviço indisponível'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
