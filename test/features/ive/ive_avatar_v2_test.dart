import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_state_v2.dart';
import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_context.dart';
import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_configuration.dart';
import 'package:ai_social_copilot/shared/ive_avatar/models/ive_personality_profile.dart';
import 'package:ai_social_copilot/shared/ive_avatar/services/ive_avatar_visibility_service.dart';
import 'package:ai_social_copilot/shared/ive_avatar/animations/ive_avatar_motion_policy.dart';
import 'package:ai_social_copilot/shared/ive_avatar/providers/ive_avatar_provider_v2.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_v2.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_compact.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_card.dart';
import 'package:ai_social_copilot/shared/ive_avatar/widgets/ive_avatar_assistant_button.dart';
import 'package:ai_social_copilot/shared/ive_avatar/showcase/ive_avatar_showcase_page.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

const _authCtx = IveAvatarContext(
  isAuthenticated: true,
  routeName: '/dashboard',
);

const _unauthCtx = IveAvatarContext(
  isAuthenticated: false,
  routeName: '/dashboard',
);

const _loginCtx = IveAvatarContext(
  isAuthenticated: false,
  routeName: '/login',
);

const _service = IveAvatarVisibilityService();

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  // 1 — Avatar hidden on login route
  group('Visibility — login route', () {
    test('avatar is hidden on /login', () {
      final result = _service.evaluate(
        context: _loginCtx,
        isKeyboardOpen: false,
        availableHeight: 800,
        isCriticalDialog: false,
        isNavigatingAway: false,
      );
      expect(result.visible, isFalse);
      expect(result.placement, IveAvatarPlacement.hidden);
    });
  });

  // 2 — Avatar hidden before authentication
  group('Visibility — unauthenticated', () {
    test('avatar is hidden when not authenticated', () {
      final result = _service.evaluate(
        context: _unauthCtx,
        isKeyboardOpen: false,
        availableHeight: 800,
        isCriticalDialog: false,
        isNavigatingAway: false,
      );
      expect(result.visible, isFalse);
    });

    test('shouldShow returns false when unauthenticated', () {
      expect(
        _service.shouldShow(routeName: '/dashboard', isAuthenticated: false),
        isFalse,
      );
    });
  });

  // 3 — Avatar visible in authorised route
  group('Visibility — authorised', () {
    test('avatar is visible in authenticated authorised route', () {
      final result = _service.evaluate(
        context: _authCtx,
        isKeyboardOpen: false,
        availableHeight: 800,
        isCriticalDialog: false,
        isNavigatingAway: false,
      );
      expect(result.visible, isTrue);
    });

    test('shouldShow returns true when authenticated', () {
      expect(
        _service.shouldShow(routeName: '/dashboard', isAuthenticated: true),
        isTrue,
      );
    });
  });

  // 4 — Fallback when asset does not exist (widget test — checks no crash)
  testWidgets('4 — compact renders without throwing on missing asset',
      (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarCompact(state: IveAvatarStateV2.idle)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  // 5 — Compact mode
  testWidgets('5 — IveAvatarCompact renders', (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarCompact(state: IveAvatarStateV2.idle)),
    );
    await tester.pump();
    expect(find.byType(IveAvatarCompact), findsOneWidget);
  });

  // 6 — Card mode
  testWidgets('6 — IveAvatarCard renders', (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarCard(
        state: IveAvatarStateV2.thinking,
        context: _authCtx,
      )),
    );
    await tester.pump();
    expect(find.byType(IveAvatarCard), findsOneWidget);
  });

  // 7 — Full mode
  testWidgets('7 — IveAvatarV2 renders in full mode', (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarV2(
        overrideState: IveAvatarStateV2.idle,
        overrideContext: _authCtx,
        configuration: IveAvatarConfiguration.full,
      )),
    );
    await tester.pump();
    expect(find.byType(IveAvatarV2), findsOneWidget);
  });

  // 8 — Floating mode (assistant button)
  testWidgets('8 — IveAvatarAssistantButton renders', (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarAssistantButton(state: IveAvatarStateV2.idle)),
    );
    await tester.pump();
    expect(find.byType(IveAvatarAssistantButton), findsOneWidget);
  });

  // 9 — Keyboard open with insufficient space → hidden
  test('9 — keyboard open with small height hides avatar', () {
    final result = _service.evaluate(
      context: _authCtx,
      isKeyboardOpen: true,
      availableHeight: 100, // below threshold
      isCriticalDialog: false,
      isNavigatingAway: false,
    );
    expect(result.visible, isFalse);
  });

  // 10 — Small available height but keyboard closed → visible
  test('10 — keyboard closed, small screen still shows avatar', () {
    final result = _service.evaluate(
      context: _authCtx,
      isKeyboardOpen: false,
      availableHeight: 150,
      isCriticalDialog: false,
      isNavigatingAway: false,
    );
    expect(result.visible, isTrue);
  });

  // 11 — Landscape: visibility service agnostic to orientation → visible when auth
  test('11 — visibility service allows landscape (orientation-agnostic)', () {
    final result = _service.evaluate(
      context: _authCtx.copyWith(compactMode: true),
      isKeyboardOpen: false,
      availableHeight: 400,
      isCriticalDialog: false,
      isNavigatingAway: false,
    );
    expect(result.visible, isTrue);
  });

  // 12 — Text scale: widget does not overflow
  testWidgets('12 — compact does not overflow at 2x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _wrap(IveAvatarCompact(state: IveAvatarStateV2.idle)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // 13 — Reduced motion policy
  test('13 — reducedMotion scales duration to ≤ 800ms', () {
    const base = Duration(milliseconds: 2400);
    final scaled = IveMotionPolicyResolver.scaleDuration(
      base,
      IveMotionPolicy.reducedMotion,
    );
    expect(scaled.inMilliseconds, lessThanOrEqualTo(800));
    expect(scaled.inMilliseconds, greaterThan(0));
  });

  test('13b — staticOnly returns zero duration', () {
    const base = Duration(milliseconds: 2400);
    final scaled = IveMotionPolicyResolver.scaleDuration(
      base,
      IveMotionPolicy.staticOnly,
    );
    expect(scaled, Duration.zero);
  });

  // 14 — State change via provider
  testWidgets('14 — state change reflected in notifier', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(iveAvatarV2StateProvider),
      IveAvatarStateV2.idle,
    );

    container.read(iveAvatarV2Provider.notifier).updateAvatarState(
          IveAvatarStateV2.thinking,
        );

    await tester.pumpAndSettle();

    expect(
      container.read(iveAvatarV2StateProvider),
      IveAvatarStateV2.thinking,
    );
  });

  // 15 — showCopilotChat integration: assistant button tap triggers callback
  testWidgets('15 — assistant button triggers onTap callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(IveAvatarAssistantButton(
        state: IveAvatarStateV2.idle,
        onTap: () => tapped = true,
      )),
    );
    await tester.tap(find.byType(IveAvatarAssistantButton));
    await tester.pump();
    expect(tapped, isTrue);
  });

  // 16 — Closing during animation: no exception
  testWidgets('16 — compact disposes cleanly during animation', (tester) async {
    await tester
        .pumpWidget(_wrap(IveAvatarCompact(state: IveAvatarStateV2.listening)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(_wrap(const SizedBox()));
    expect(tester.takeException(), isNull);
  });

  // 17 — Navigation during update: no exception
  testWidgets('17 — V2 widget survives state change mid-frame', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: IveAvatarV2(
              overrideState: IveAvatarStateV2.idle,
              overrideContext: _authCtx,
              configuration: IveAvatarConfiguration.full,
            ),
          ),
        ),
      ),
    );
    container.read(iveAvatarV2Provider.notifier).updateAvatarState(
          IveAvatarStateV2.analyzing,
        );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // 18 — Provider disposed: notifier.dispose safe
  test('18 — provider container disposes without error', () {
    final container = ProviderContainer();
    container.read(iveAvatarV2Provider.notifier);
    expect(() => container.dispose(), returnsNormally);
  });

  // 19 — No setState after dispose: compact widget
  testWidgets('19 — no setState after dispose on compact', (tester) async {
    await tester
        .pumpWidget(_wrap(IveAvatarCompact(state: IveAvatarStateV2.listening)));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(_wrap(const Placeholder()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  // 20 — No overflow in compact
  testWidgets('20 — compact in tight 48×48 box does not overflow',
      (tester) async {
    await tester.pumpWidget(
      _wrap(SizedBox(
        width: 48,
        height: 48,
        child: IveAvatarCompact(state: IveAvatarStateV2.idle, size: 40),
      )),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // 21 — No asset build failure: IveAvatarFacePlaceholder uses errorBuilder
  testWidgets('21 — face placeholder does not crash on missing image',
      (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarV2(
        overrideState: IveAvatarStateV2.idle,
        overrideContext: _authCtx,
        configuration: IveAvatarConfiguration.full,
      )),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  // 22 — Feature flag false: provider returns false by default
  test('22 — iveAvatarV2EnabledProvider is false by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(iveAvatarV2EnabledProvider), isFalse);
  });

  // 23 — Feature flag true activates showcase: just verify override works
  test('23 — iveAvatarV2EnabledProvider can be overridden to true', () {
    final container = ProviderContainer(
      overrides: [
        iveAvatarV2EnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(iveAvatarV2EnabledProvider), isTrue);
  });

  // 24 — Semantics: compact has semantic label
  testWidgets('24 — IveAvatarCompact has semantic label', (tester) async {
    await tester.pumpWidget(
      _wrap(IveAvatarCompact(
        state: IveAvatarStateV2.idle,
        interactive: true,
        onTap: () {},
      )),
    );
    await tester.pump();

    final semantics = tester.getSemantics(find.byType(IveAvatarCompact));
    expect(semantics.label, isNotEmpty);
  });

  // 25 — Rebuild controlled: state selector does not rebuild on unrelated change
  test('25 — state selector is independent from context selector', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    var stateRebuildCount = 0;

    final sub = container.listen(
      iveAvatarV2StateProvider,
      (_, __) => stateRebuildCount++,
    );

    // Update context only — state selector must NOT fire
    container.read(iveAvatarV2Provider.notifier).updateContext(
          _authCtx.copyWith(title: 'New title'),
        );

    expect(stateRebuildCount, 0);
    sub.close();
  });

  // ── State enum coverage ───────────────────────────────────────────────────

  group('IveAvatarStateV2 — enum', () {
    test('has 14 distinct states', () {
      expect(IveAvatarStateV2.values.length, 14);
    });

    test('each state has a unique stateIndex', () {
      final indices = IveAvatarStateV2.values
          .map((s) => IveAvatarStateConfigV2.forState(s).stateIndex)
          .toSet();
      expect(indices.length, IveAvatarStateV2.values.length);
    });

    test('every state has a non-empty semanticLabel', () {
      for (final s in IveAvatarStateV2.values) {
        final label = IveAvatarStateConfigV2.forState(s).semanticLabel;
        expect(label, isNotEmpty, reason: 'Missing label for $s');
      }
    });

    test('every state has a non-empty fallbackLabel', () {
      for (final s in IveAvatarStateV2.values) {
        final label = IveAvatarStateConfigV2.forState(s).fallbackLabel;
        expect(label, isNotEmpty, reason: 'Missing fallbackLabel for $s');
      }
    });
  });

  // ── IveAvatarContext ──────────────────────────────────────────────────────

  group('IveAvatarContext', () {
    test('empty context is unauthenticated', () {
      expect(IveAvatarContext.empty.isAuthenticated, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final base = _authCtx.copyWith(title: 'Test');
      expect(base.isAuthenticated, isTrue);
      expect(base.title, 'Test');
    });

    test('equality is value-based', () {
      const a = IveAvatarContext(isAuthenticated: true, routeName: '/x');
      const b = IveAvatarContext(isAuthenticated: true, routeName: '/x');
      expect(a, equals(b));
    });
  });

  // ── IvePersonalityProfile ─────────────────────────────────────────────────

  group('IvePersonalityProfile', () {
    test('executive is the default profile', () {
      expect(IvePersonalityProfile.executive.defaultProfile, isTrue);
    });

    test('allProfiles contains 6 entries', () {
      expect(IvePersonalityProfile.allProfiles.length, 6);
    });

    test('no two profiles share the same id', () {
      final ids = IvePersonalityProfile.allProfiles.map((p) => p.id).toSet();
      expect(ids.length, IvePersonalityProfile.allProfiles.length);
    });
  });

  // ── Showcase page smoke test ──────────────────────────────────────────────

  testWidgets('Showcase page renders without exception', (tester) async {
    await tester.pumpWidget(
      _wrap(const IveAvatarShowcasePage()),
    );
    await tester.pump();
    expect(find.byType(IveAvatarShowcasePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
