import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' show Rive;

import 'package:ai_social_copilot/data/models/ive_issue.dart';
import 'package:ai_social_copilot/data/models/ive_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_controller.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_status_ring.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_visual_config.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_visual_fallback.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';

void main() {
  // ── IveVisualState ────────────────────────────────────────────────────────
  group('IveVisualState', () {
    test('has 10 distinct values', () {
      expect(IveVisualState.values.length, 10);
    });

    test('stateIndex is unique per state', () {
      final indices = IveVisualState.values
          .map((s) => IveVisualStateConfig.forState(s).stateIndex)
          .toSet();
      expect(indices.length, IveVisualState.values.length);
    });
  });

  // ── IveVisualStateMapper ──────────────────────────────────────────────────
  group('IveVisualStateMapper', () {
    IveState makeState({
      IveExpression expression = IveExpression.happy,
      bool bubbleVisible       = false,
    }) =>
        IveState(expression: expression, bubbleVisible: bubbleVisible);

    test('happy → idle', () {
      expect(
        IveVisualStateMapper.fromIveState(makeState(expression: IveExpression.happy)),
        IveVisualState.idle,
      );
    });

    test('thinking → thinking', () {
      expect(
        IveVisualStateMapper.fromIveState(makeState(expression: IveExpression.thinking)),
        IveVisualState.thinking,
      );
    });

    test('excited → success', () {
      expect(
        IveVisualStateMapper.fromIveState(makeState(expression: IveExpression.excited)),
        IveVisualState.success,
      );
    });

    test('neutral → attentive', () {
      expect(
        IveVisualStateMapper.fromIveState(makeState(expression: IveExpression.neutral)),
        IveVisualState.attentive,
      );
    });

    test('winking → opportunity', () {
      expect(
        IveVisualStateMapper.fromIveState(makeState(expression: IveExpression.winking)),
        IveVisualState.opportunity,
      );
    });
  });

  // ── IveVisualStateMapper — interaction overlay (IVE-AVATAR-STATE-MACHINE-02) ─
  group('IveVisualStateMapper — interaction overlay', () {
    test('thinking interaction overrides expression', () {
      final state = IveState(
        expression:  IveExpression.winking,
        interaction: IveInteractionState.thinking,
      );
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.thinking);
    });

    test('speaking interaction overrides an active issue', () {
      final issue = IveIssue(
        errorCode:        'x',
        stage:            IveIssueStage.network,
        severity:         IveIssueSeverity.error,
        recoverable:      true,
        userMessage:      'msg',
        technicalMessage: 'tech',
        occurredAt:       DateTime.now(),
      );
      final state = IveState(
        activeIssue:   issue,
        bubbleVisible: true,
        interaction:   IveInteractionState.speaking,
      );
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.speaking);
    });

    test('null interaction falls back to the live business state (opportunity preserved)', () {
      final state = IveState(expression: IveExpression.winking);
      expect(IveVisualStateMapper.fromIveState(state), IveVisualState.opportunity);
    });
  });

  // ── IveAvatarController ───────────────────────────────────────────────────
  group('IveAvatarController', () {
    late IveAvatarController ctrl;

    setUp(() => ctrl = IveAvatarController());
    tearDown(() => ctrl.dispose());

    test('starts in idle state', () {
      expect(ctrl.currentState, IveVisualState.idle);
    });

    test('applyVisualState updates currentState', () {
      ctrl.applyVisualState(IveVisualState.thinking);
      expect(ctrl.currentState, IveVisualState.thinking);
    });

    test('applyVisualState is a no-op for same state', () {
      var notified = 0;
      ctrl.addListener(() => notified++);
      ctrl.applyVisualState(IveVisualState.idle);
      ctrl.applyVisualState(IveVisualState.idle);
      expect(notified, 0); // no notification for same state
    });

    test('applyVisualState notifies listeners on change', () {
      var notified = 0;
      ctrl.addListener(() => notified++);
      ctrl.applyVisualState(IveVisualState.error);
      expect(notified, 1);
    });

    test('isRiveReady is false before initialization', () {
      expect(ctrl.isRiveReady, isFalse);
    });

    // IVE-AVATAR-RIVE-RUNTIME-03B6C/D — a verified canary .riv now ships at
    // IveAssetPaths.riveAsset (temporary, isolated-branch pointer; see
    // ive_visual_config.dart), and ive_rive_runtime.dart now calls
    // RiveFile.asset() instead of the uninitialized RiveFile.import()
    // (03B6D fix, see rive-app/rive-flutter#389). Real-runtime evidence
    // (03B6D: a live Chrome session running the actual widget tree, plus the
    // 4 widget tests below, all passing) proves the asset genuinely loads
    // and initializes correctly in a real runtime. There is deliberately NO
    // dedicated non-widget unit test calling ctrl.initializeRive() directly
    // here: doing so hangs indefinitely (confirmed past a 35s explicit
    // timeout) because flutter_tester's plain `test()` zone — unlike its
    // `testWidgets()` zone, which the tests below run under and which do
    // NOT hang — never resolves the rejected Future from rive_common's
    // native FFI plugin failing to load (a flutter_tester/native-plugin
    // platform gap, not a defect in IveRiveRuntime). The widget tests below
    // are the correct, safe way to exercise this path in this suite.

    test('controller is safe after dispose', () {
      ctrl.dispose();
      // Should not throw
      expect(() => ctrl.applyVisualState(IveVisualState.success), returnsNormally);
    });

    // IVE-AVATAR-COMMERCIAL-FALLBACK-04 — Rive is frozen by configuration.
    // This is safe to call from a plain test() (unlike the FFI-backed path
    // described above) because the gate returns BEFORE any IveRiveRuntime or
    // rive package object is constructed — which is exactly the property
    // the commercial release depends on.
    test('initializeRive is gated off deterministically while Rive is frozen',
        () async {
      expect(IveRiveFeatureGate.enabled, isFalse,
          reason: 'commercial build must not enable Rive');
      final result = await ctrl.initializeRive();
      expect(result, isFalse);
      expect(ctrl.isRiveReady, isFalse);
      expect(ctrl.riveRuntime, isNull);
    });

    test('applyVisualState still tracks state with Rive gated off', () async {
      await ctrl.initializeRive();
      ctrl.applyVisualState(IveVisualState.speaking);
      expect(ctrl.currentState, IveVisualState.speaking);
      expect(ctrl.isRiveReady, isFalse);
    });
  });

  // ── IveStatusRingPainter ──────────────────────────────────────────────────
  group('IveStatusRingPainter', () {
    test('shouldRepaint true on state change', () {
      const p1 = IveStatusRingPainter(state: IveVisualState.idle,    glowPulse: 0);
      const p2 = IveStatusRingPainter(state: IveVisualState.error,   glowPulse: 0);
      expect(p1.shouldRepaint(p2), isTrue);
    });

    test('shouldRepaint false on identical params', () {
      const p1 = IveStatusRingPainter(state: IveVisualState.warning, glowPulse: 0.5);
      const p2 = IveStatusRingPainter(state: IveVisualState.warning, glowPulse: 0.5);
      expect(p1.shouldRepaint(p2), isFalse);
    });
  });

  // ── IveVisualStateConfig ──────────────────────────────────────────────────
  group('IveVisualStateConfig', () {
    test('error state has red ring', () {
      final cfg = IveVisualStateConfig.forState(IveVisualState.error);
      expect(cfg.ringColor.red, greaterThan(200));
      expect(cfg.ringColor.green, lessThan(100));
    });

    test('success state has green ring', () {
      final cfg = IveVisualStateConfig.forState(IveVisualState.success);
      expect(cfg.ringColor.green, greaterThan(200));
    });

    test('all states have valid glowIntensity', () {
      for (final state in IveVisualState.values) {
        final cfg = IveVisualStateConfig.forState(state);
        expect(cfg.glowIntensity, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  // ── IveVisualFallback widget ──────────────────────────────────────────────
  group('IveVisualFallback', () {
    testWidgets('renders without error when asset is missing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IveVisualFallback(
              state: IveVisualState.idle,
              size:  72,
            ),
          ),
        ),
      );
      // Should render fallback placeholder (no crash)
      expect(find.byType(IveVisualFallback), findsOneWidget);
    });
  });

  // ── IveAvatar widget ──────────────────────────────────────────────────────
  group('IveAvatar', () {
    testWidgets('renders without crash (Rive asset absent)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IveAvatar(
                size:           IveAvatarSize.compact,
                showStatusRing: true,
                interactive:    false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatar), findsOneWidget);
    });

    // IVE-AVATAR-COMMERCIAL-FALLBACK-04 — blank-avatar protection: with the
    // gate off, the widget must render IveVisualFallback (never a Rive
    // surface, never an empty slot) regardless of asset-load timing.
    testWidgets('always renders IveVisualFallback while Rive is frozen',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IveAvatar(
                size:        IveAvatarSize.compact,
                interactive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(IveVisualFallback), findsOneWidget);
      expect(find.byType(Rive), findsNothing);
      expect(find.byType(IveVisualFallback).evaluate().single.size,
          const Size(56, 56));
    });

    testWidgets('onTap callback fires when interactive', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IveAvatar(
                size:        IveAvatarSize.compact,
                interactive: true,
                onTap:       () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(IveAvatar));
      expect(tapped, isTrue);
    });

    testWidgets('has semantics label for screen readers', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IveAvatar(
                size:        IveAvatarSize.standard,
                interactive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(IveAvatar)),
        matchesSemantics(
          label:  'IVE, assistente executiva',
          isButton: true,
        ),
      );
    });

    // IVE-AVATAR-STATE-MACHINE-02 (Codex review F4): the mapper is tested in
    // isolation above; this proves the wiring actually reaches the rendered
    // widget when iveProvider's real interaction bridge drives it.
    //
    // IVE-AVATAR-RIVE-RUNTIME-03B6C: asserts via IveStatusRingPainter.state
    // instead of IveVisualFallback directly, because a verified canary .riv
    // now ships (see ive_visual_config.dart) and IveAvatar may render either
    // the Rive path or the fallback path depending on asset-load timing in
    // this test environment — both paths wrap their content in the same
    // IveStatusRingPainter with the same `state`, so this stays a correct,
    // path-agnostic proof of the wiring regardless of which one is active.
    //
    // IVE-AVATAR-COMMERCIAL-FALLBACK-04: the Rive track is now FROZEN by
    // IveRiveFeatureGate (always off), so in practice only the fallback path
    // is ever active; the path-agnostic assertion is kept unchanged on
    // purpose so it stays valid if Rive is ever re-entered.
    testWidgets('reflects thinking/speaking interaction through to the rendered avatar',
        (tester) async {
      // Disposed explicitly at the end of the test body (not via addTearDown):
      // testWidgets runs inside a FakeAsync zone whose pending-timer check
      // runs before addTearDown callbacks fire, so a still-pending
      // _speakingTimer (from completeInteraction below) would otherwise trip
      // flutter_test's "A Timer is still pending" assertion.
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: IveAvatar(size: IveAvatarSize.compact, interactive: false),
            ),
          ),
        ),
      );
      await tester.pump();

      IveVisualState ringState() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<IveStatusRingPainter>()
          .single
          .state;

      final notifier = container.read(iveProvider.notifier);

      final token = notifier.beginThinking();
      await tester.pump();
      expect(ringState(), IveVisualState.thinking);

      notifier.completeInteraction(token, success: true);
      await tester.pump();
      expect(ringState(), IveVisualState.speaking);

      // Cancels the pending speaking-clear timer before the test body
      // returns — see comment above.
      container.dispose();
    });
  });
}
