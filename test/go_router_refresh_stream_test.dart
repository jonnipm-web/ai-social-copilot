import 'dart:async';

import 'package:ai_social_copilot/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// GATE-17-FINAL-CLOSURE (Section 09) — regression test for the physical
// bug: Google web sign-in (Supabase's signInWithOAuth PKCE redirect)
// completed successfully, but the app was left stranded on /login because
// GoRouter never re-evaluated its redirect once the session arrived after
// the router's initial decision. The fix wires GoRouter's
// `refreshListenable` to Supabase's onAuthStateChange stream via
// GoRouterRefreshStream (app.dart) -- go_router itself removed its own
// class of that name years ago (see its CHANGELOG), so this is a small
// local replacement. This test exercises that class directly, against a
// plain stream standing in for onAuthStateChange, since driving the real
// Supabase.instance singleton through an OAuth callback isn't feasible in
// a widget test.
void main() {
  group('GoRouterRefreshStream', () {
    test('does not notify before the stream emits anything', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var notifyCount = 0;
      final refresh = GoRouterRefreshStream(controller.stream)
        ..addListener(() => notifyCount++);
      addTearDown(refresh.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 0);
    });

    test(
        'notifies when the stream emits -- this is what lets GoRouter '
        're-run redirect() for a session that arrives AFTER it already '
        'settled on /login', () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var notifyCount = 0;
      final refresh = GoRouterRefreshStream(controller.stream)
        ..addListener(() => notifyCount++);
      addTearDown(refresh.dispose);

      controller.add(1); // stand-in for a late SIGNED_IN auth event
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 1);
    });

    test('stops notifying after dispose (subscription is cancelled)',
        () async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      var notifyCount = 0;
      final refresh = GoRouterRefreshStream(controller.stream)
        ..addListener(() => notifyCount++);

      refresh.dispose();

      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 0);
    });

    // Physical regression (real device, 2026-09-21): on every cold start,
    // GoTrue's onAuthStateChange fired its first event during Flutter's
    // very first frame, and the old unconditional `notifyListeners()` here
    // propagated that into a GoRouter refresh landing squarely inside
    // Flutter's build phase -- which Riverpod's own build-time guard
    // rejects elsewhere in the app (IveNotifier's constructor-time
    // ref.listen). This does not reproduce that downstream Riverpod crash
    // (that requires the full provider graph); it proves the narrower,
    // directly-testable property that actually prevents it: notifyListeners
    // is never invoked while a widget build is in progress -- an event
    // fired from initState (itself deep inside Flutter's persistentCallbacks
    // phase, the same phase the physical crash happened in) is not
    // delivered until the phase has returned to idle.
    testWidgets(
        'a stream event fired during a widget build is not delivered until '
        'the scheduler phase is back to idle', (tester) async {
      final controller = StreamController<int>.broadcast();
      addTearDown(controller.close);

      late GoRouterRefreshStream refresh;
      SchedulerPhase? phaseWhenNotified;

      await tester.pumpWidget(
        _InitStateStreamFirer(
          onInit: () {
            refresh = GoRouterRefreshStream(controller.stream)
              ..addListener(() {
                phaseWhenNotified = SchedulerBinding.instance.schedulerPhase;
              });
            // Fired from inside initState -- Flutter is still deep in the
            // persistentCallbacks phase building this very widget tree,
            // exactly the window the physical crash happened in.
            controller.add(1);
          },
        ),
      );
      addTearDown(() => refresh.dispose());

      await tester.pumpAndSettle();

      expect(phaseWhenNotified, isNotNull,
          reason: 'the deferred notification must still eventually fire');
      expect(phaseWhenNotified, SchedulerPhase.idle);
    });
  });

  // GATE-17-FINAL-CLOSURE (Section 19, Codex P1) — the group above only
  // proves GoRouterRefreshStream's own notify contract; it never proves
  // GoRouter actually RE-NAVIGATES when that notifier fires. This group
  // wires a real GoRouter (2 routes, a redirect callback shaped exactly
  // like app.dart's `_computeRedirect`: session==null -> /login,
  // session!=null while at /login -> /dashboard) to a fake auth stream via
  // the real GoRouterRefreshStream, and drives it through an actual
  // widget tree -- this is what closes the P1 gap ("does not verify ...
  // a later authenticated event causes /login -> /dashboard"). It uses a
  // standalone router rather than app.dart's own top-level `_router`
  // because that one is tied directly to the real Supabase.instance
  // singleton (which throws when unset in a test process, per
  // diagnostic_logger_service's own test-harness comment elsewhere in
  // this suite) -- the redirect SHAPE under test is identical either way.
  group('GoRouter + GoRouterRefreshStream integration', () {
    testWidgets(
        'a late auth event re-runs redirect and moves /login -> /dashboard '
        '-- the actual physical defect: Google OAuth accepted, browser '
        'returns to the app, SplashScreen samples currentSession too '
        'early and lands on /login, and nothing used to re-check once the '
        'session actually arrived', (tester) async {
      final authEvents = StreamController<int>.broadcast();
      addTearDown(authEvents.close);
      var hasSession = false;

      final router = GoRouter(
        initialLocation: '/login',
        refreshListenable: GoRouterRefreshStream(authEvents.stream),
        redirect: (context, state) {
          final goingToLogin = state.matchedLocation == '/login';
          if (!hasSession && !goingToLogin) return '/login';
          if (hasSession && goingToLogin) return '/dashboard';
          return null;
        },
        routes: [
          GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
          GoRoute(
              path: '/dashboard', builder: (_, __) => const Text('DASHBOARD')),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);

      // The session arrives AFTER the router already settled on /login --
      // exactly the PKCE web callback race this fix closes.
      hasSession = true;
      authEvents.add(1);
      await tester.pumpAndSettle();

      expect(find.text('DASHBOARD'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
    });

    testWidgets(
        'a SIGNED_OUT-equivalent event from a protected route redirects '
        'back to /login', (tester) async {
      final authEvents = StreamController<int>.broadcast();
      addTearDown(authEvents.close);
      var hasSession = true;

      final router = GoRouter(
        initialLocation: '/dashboard',
        refreshListenable: GoRouterRefreshStream(authEvents.stream),
        redirect: (context, state) {
          final goingToLogin = state.matchedLocation == '/login';
          if (!hasSession && !goingToLogin) return '/login';
          if (hasSession && goingToLogin) return '/dashboard';
          return null;
        },
        routes: [
          GoRoute(path: '/login', builder: (_, __) => const Text('LOGIN')),
          GoRoute(
              path: '/dashboard', builder: (_, __) => const Text('DASHBOARD')),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('DASHBOARD'), findsOneWidget);

      hasSession = false;
      authEvents.add(1);
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsNothing);
    });
  });
}

class _InitStateStreamFirer extends StatefulWidget {
  const _InitStateStreamFirer({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_InitStateStreamFirer> createState() => _InitStateStreamFirerState();
}

class _InitStateStreamFirerState extends State<_InitStateStreamFirer> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) =>
      const Directionality(textDirection: TextDirection.ltr, child: SizedBox.shrink());
}
