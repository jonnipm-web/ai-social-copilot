import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_state_v2.dart';
import 'package:ai_social_copilot/shared/ive_avatar/providers/effective_avatar_version_provider.dart';
import 'package:ai_social_copilot/shared/ive_avatar/providers/ive_operational_state_provider.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_resolver.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart' show iveRouteNotifier;

// ── Helpers ───────────────────────────────────────────────────────────────────

class _FixedOverrideNotifier extends IveAvatarLocalOverrideNotifier {
  _FixedOverrideNotifier(IveAvatarLocalOverride fixed) : super.fixed(fixed);

  @override
  Future<void> set(IveAvatarLocalOverride o) async => state = o;
}

List<Override> _noSharedPrefs({
  IveAvatarVersion version = IveAvatarVersion.v2,
}) =>
    [
      effectiveIveAvatarVersionProvider.overrideWithValue(version),
      iveAvatarLocalOverrideProvider.overrideWith(
        (_) => _FixedOverrideNotifier(IveAvatarLocalOverride.automatic),
      ),
    ];

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    iveRouteNotifier.value = '';
  });

  // ── Operational-state sequencing (chat session model) ─────────────────────
  group('IveOperationalStateNotifier — chat session sequencing', () {
    test('32 — chat op starts analyzing, clears to idle', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.analyzing);
      n.clearOperation('chat-send');
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.idle);
    });

    test('33 — overlapping ops: error from context-fetch wins over chat analyzing', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      n.setOperationState('context-fetch', IveAvatarStateV2.error);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.error);
    });

    test('34 — clearOperation only resets to idle when all ops are cleared', () {
      // clearOperation does not recalculate from remaining active ops.
      // State stays at the last high-priority value until _active is empty.
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      n.setOperationState('context-fetch', IveAvatarStateV2.error);
      n.clearOperation('context-fetch');
      // State remains error because _active still has chat-send.
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.error);
      // Clearing the last op returns to idle.
      n.clearOperation('chat-send');
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.idle);
    });

    test('35 — chat close: all ops cleared returns to idle', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      n.setOperationState('context-fetch', IveAvatarStateV2.warning);
      n.clearOperation('chat-send');
      n.clearOperation('context-fetch');
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.idle);
    });

    test('36 — updating same op id to new state (retry on error)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.error);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.analyzing);
    });

    test('37 — no duplicates: same op updated idempotently', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.analyzing);
    });

    test('38 — dispose during active chat op is safe', () {
      final c = ProviderContainer();
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('chat-send', IveAvatarStateV2.analyzing);
      n.setOperationState('context-fetch', IveAvatarStateV2.warning);
      expect(() => c.dispose(), returnsNormally);
    });
  });

  // ── IveAvatarResolver lifecycle ───────────────────────────────────────────
  group('IveAvatarResolver widget — lifecycle', () {
    testWidgets('39 — v2 resolver mounts and disposes without error', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _noSharedPrefs(),
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [IveAvatarResolver()])),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);

      // dispose by replacing widget tree
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsNothing);
    });

    testWidgets('40 — route change to hidden route while mounted — no crash', (tester) async {
      iveRouteNotifier.value = '/dashboard';
      await tester.pumpWidget(
        ProviderScope(
          overrides: _noSharedPrefs(),
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [IveAvatarResolver()])),
          ),
        ),
      );
      await tester.pump();
      iveRouteNotifier.value = '/login';
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);
    });

    testWidgets('41 — operational state change while resolver is mounted — no crash', (tester) async {
      final container = ProviderContainer(overrides: _noSharedPrefs());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [IveAvatarResolver()])),
          ),
        ),
      );
      await tester.pump();

      container
          .read(iveOperationalStateProvider.notifier)
          .setOperationState('chat-send', IveAvatarStateV2.analyzing);
      await tester.pump();

      container
          .read(iveOperationalStateProvider.notifier)
          .clearOperation('chat-send');
      await tester.pump();

      expect(find.byType(IveAvatarResolver), findsOneWidget);
    });

    testWidgets('42 — resolver with legacy version mounts and disposes cleanly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _noSharedPrefs(version: IveAvatarVersion.legacy),
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [IveAvatarResolver()])),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsNothing);
    });
  });
}
