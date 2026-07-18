import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/models/ive_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_controller.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_avatar_state.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_status_ring.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_visual_config.dart';
import 'package:ai_social_copilot/features/ive/visual/ive_visual_fallback.dart';

void main() {
  setUpAll(() async {
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

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

    test('initializeRive returns false when .riv asset is absent', () async {
      final result = await ctrl.initializeRive();
      expect(result, isFalse);
      expect(ctrl.isRiveReady, isFalse);
    });

    test('controller is safe after dispose', () {
      ctrl.dispose();
      // Should not throw
      expect(() => ctrl.applyVisualState(IveVisualState.success), returnsNormally);
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
  });
}
