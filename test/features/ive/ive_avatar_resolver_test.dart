import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_state_v2.dart';
import 'package:ai_social_copilot/shared/ive_avatar/providers/effective_avatar_version_provider.dart';
import 'package:ai_social_copilot/shared/ive_avatar/providers/ive_operational_state_provider.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_resolver.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart'
    show iveRouteNotifier;

// ── Helpers ───────────────────────────────────────────────────────────────────

ProviderContainer _container({
  IveAvatarVersion? version,
  IveAvatarLocalOverride? localOverride,
  bool v2FlagEnabled = false,
  IveAvatarStateV2? opState,
}) {
  return ProviderContainer(
    overrides: [
      if (version != null)
        effectiveIveAvatarVersionProvider.overrideWithValue(version),
      // Always override to prevent SharedPreferences platform channel in tests.
      iveAvatarLocalOverrideProvider.overrideWith(
        (_) => _FixedOverrideNotifier(
          localOverride ?? IveAvatarLocalOverride.automatic,
        ),
      ),
      iveAvatarV2FlagProvider.overrideWithValue(v2FlagEnabled),
      if (opState != null)
        iveOperationalStateProvider.overrideWith((_) => _FixedOpState(opState)),
    ],
  );
}

class _FixedOverrideNotifier extends IveAvatarLocalOverrideNotifier {
  _FixedOverrideNotifier(IveAvatarLocalOverride fixed) : super.fixed(fixed);

  @override
  Future<void> set(IveAvatarLocalOverride o) async => state = o;
}

class _FixedOpState extends IveOperationalStateNotifier {
  _FixedOpState(IveAvatarStateV2 fixed) {
    state = fixed;
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    // Reset route notifier before each test
    iveRouteNotifier.value = '';
  });

  // ── effectiveIveAvatarVersionProvider ─────────────────────────────────────
  group('effectiveIveAvatarVersionProvider', () {
    test('1 — flag false + override automatic → legacy', () {
      final c = _container(v2FlagEnabled: false);
      addTearDown(c.dispose);
      expect(
          c.read(effectiveIveAvatarVersionProvider), IveAvatarVersion.legacy);
    });

    test('2 — flag true + override automatic → v2', () {
      final c = _container(v2FlagEnabled: true);
      addTearDown(c.dispose);
      expect(c.read(effectiveIveAvatarVersionProvider), IveAvatarVersion.v2);
    });

    test('3 — override legacy → legacy regardless of flag', () {
      final c = _container(
        v2FlagEnabled: true,
        localOverride: IveAvatarLocalOverride.legacy,
      );
      addTearDown(c.dispose);
      expect(
          c.read(effectiveIveAvatarVersionProvider), IveAvatarVersion.legacy);
    });

    test('4 — override v2 → v2 regardless of flag', () {
      final c = _container(
        v2FlagEnabled: false,
        localOverride: IveAvatarLocalOverride.v2,
      );
      addTearDown(c.dispose);
      expect(c.read(effectiveIveAvatarVersionProvider), IveAvatarVersion.v2);
    });

    test('5 — override hidden → hidden', () {
      final c = _container(localOverride: IveAvatarLocalOverride.hidden);
      addTearDown(c.dispose);
      expect(
          c.read(effectiveIveAvatarVersionProvider), IveAvatarVersion.hidden);
    });
  });

  // ── iveIsHiddenRoute ──────────────────────────────────────────────────────
  group('iveIsHiddenRoute', () {
    test('6 — empty route is hidden', () {
      expect(iveIsHiddenRoute(''), isTrue);
    });

    test('7 — /login is hidden', () {
      expect(iveIsHiddenRoute('/login'), isTrue);
    });

    test('8 — /signup is hidden', () {
      expect(iveIsHiddenRoute('/signup'), isTrue);
    });

    test('9 — /advisor-onboarding is hidden', () {
      expect(iveIsHiddenRoute('/advisor-onboarding'), isTrue);
    });

    test('10 — /forgot-password is hidden', () {
      expect(iveIsHiddenRoute('/forgot-password'), isTrue);
    });

    test('11 — /reset-password is hidden', () {
      expect(iveIsHiddenRoute('/reset-password'), isTrue);
    });

    test('12 — /debug/ive-avatar-v2 is hidden', () {
      expect(iveIsHiddenRoute('/debug/ive-avatar-v2'), isTrue);
    });

    test('13 — / (splash) is hidden', () {
      expect(iveIsHiddenRoute('/'), isTrue);
    });

    test('14 — /dashboard is not hidden', () {
      expect(iveIsHiddenRoute('/dashboard'), isFalse);
    });

    test('15 — /projects is not hidden', () {
      expect(iveIsHiddenRoute('/projects'), isFalse);
    });

    test('16 — /ecosystem is not hidden', () {
      expect(iveIsHiddenRoute('/ecosystem'), isFalse);
    });

    test('17 — /ecosystem/briefing is not hidden', () {
      expect(iveIsHiddenRoute('/ecosystem/briefing'), isFalse);
    });
  });

  // ── IveOperationalStateNotifier ───────────────────────────────────────────
  group('IveOperationalStateNotifier', () {
    test('18 — starts at idle', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.idle);
    });

    test('19 — setOperationState analyzing updates state', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c
          .read(iveOperationalStateProvider.notifier)
          .setOperationState('op-1', IveAvatarStateV2.analyzing);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.analyzing);
    });

    test('20 — clearOperation returns to idle', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c
          .read(iveOperationalStateProvider.notifier)
          .setOperationState('op-1', IveAvatarStateV2.analyzing);
      c.read(iveOperationalStateProvider.notifier).clearOperation('op-1');
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.idle);
    });

    test('21 — error has higher priority than analyzing', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('op-1', IveAvatarStateV2.analyzing);
      n.setOperationState('op-2', IveAvatarStateV2.error);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.error);
    });

    test('22 — warning has higher priority than attention', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(iveOperationalStateProvider.notifier);
      n.setOperationState('op-1', IveAvatarStateV2.attention);
      n.setOperationState('op-2', IveAvatarStateV2.warning);
      expect(c.read(iveOperationalStateProvider), IveAvatarStateV2.warning);
    });

    test('23 — dispose is safe', () {
      final c = ProviderContainer();
      c
          .read(iveOperationalStateProvider.notifier)
          .setOperationState('op-1', IveAvatarStateV2.analyzing);
      expect(() => c.dispose(), returnsNormally);
    });
  });

  // ── IveAvatarResolver widget ──────────────────────────────────────────────
  group('IveAvatarResolver widget', () {
    testWidgets('24 — renders without crash with version=legacy',
        (tester) async {
      // Route notifier empty → resolver hides (no auth in test)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIveAvatarVersionProvider.overrideWithValue(
              IveAvatarVersion.legacy,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(children: [IveAvatarResolver()]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);
    });

    testWidgets('25 — renders without crash with version=hidden',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIveAvatarVersionProvider.overrideWithValue(
              IveAvatarVersion.hidden,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(children: [IveAvatarResolver()]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);
    });

    testWidgets('26 — renders without crash with version=v2', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveIveAvatarVersionProvider.overrideWithValue(
              IveAvatarVersion.v2,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Stack(children: [IveAvatarResolver()]),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(IveAvatarResolver), findsOneWidget);
    });
  });

  // ── IveAvatarLocalOverride enum ───────────────────────────────────────────
  group('IveAvatarLocalOverride', () {
    test('27 — fromString automatic', () {
      expect(
        IveAvatarLocalOverride.fromString(null),
        IveAvatarLocalOverride.automatic,
      );
    });

    test('28 — fromString legacy', () {
      expect(
        IveAvatarLocalOverride.fromString('legacy'),
        IveAvatarLocalOverride.legacy,
      );
    });

    test('29 — fromString v2', () {
      expect(
        IveAvatarLocalOverride.fromString('v2'),
        IveAvatarLocalOverride.v2,
      );
    });

    test('30 — fromString hidden', () {
      expect(
        IveAvatarLocalOverride.fromString('hidden'),
        IveAvatarLocalOverride.hidden,
      );
    });

    test('31 — fromString unknown → automatic', () {
      expect(
        IveAvatarLocalOverride.fromString('garbage'),
        IveAvatarLocalOverride.automatic,
      );
    });
  });
}
