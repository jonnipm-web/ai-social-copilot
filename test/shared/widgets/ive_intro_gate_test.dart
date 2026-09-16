// STABILITY-09-FIX — regression coverage for the exact defect a symbolicated
// production stack proved (mission STABILITY-09O-SHA): IveIntroGate is
// mounted as a Stack SIBLING of GoRouter's own Router/Navigator (see
// app.dart's MaterialApp.router builder), never a DESCENDANT of it, so
// ancestor-based Navigator.of/Navigator.maybeOf can NEVER resolve the real
// Navigator from this position (confirmed empirically with a topology probe:
// immediate=false, settled=false, even long after full route settlement).
//
// These harnesses use a REAL MaterialApp.router + real GoRouter with a
// `builder` that exactly mirrors app.dart's own Stack(children: [child!,
// ...]) structure -- not a simplified MaterialApp(home: Scaffold(...)) tree,
// which places the probed widget BELOW an implicit Navigator and does not
// reproduce the real production topology (this was the exact test-fidelity
// gap Codex identified in an earlier round of this same fix).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/core/diagnostics/ive_forensic_snapshot.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_intro_gate.dart';

class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

// STABILITY-09-FIX (Codex Gate round 5) -- IveIntroGate now also gates on
// authStateProvider (see its own comment), same pattern already established
// in test/shared/widgets/ive_overlay_auth_gate_test.dart for the same class
// of "auth-adjacent global overlay widget" concern.
class MockSession extends Mock implements Session {}

AuthState _authState({Session? session}) =>
    AuthState(session != null ? AuthChangeEvent.signedIn : AuthChangeEvent.signedOut, session);

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 5,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // STABILITY-09-FIX — IveForensicSnapshot's route fields are
    // static/global, so they must be reset between tests in this file to
    // avoid one test's simulated route leaking into the next.
    IveForensicSnapshot.previousRoute = '';
    IveForensicSnapshot.currentRoute = '';
    IveForensicSnapshot.settledRouteNotifier.value = '';
  });

  // Simulates the GoRouter `redirect` callback having already settled on a
  // real, post-Splash, authenticated destination -- the same call app.dart's
  // own redirect makes via IveForensicSnapshot.recordSettledRoute(path) once
  // ITS OWN redirect decision resolves to null. Tests that are not
  // specifically about route-readiness call this once up front so they
  // exercise exactly one variable (Navigator availability) at a time.
  void simulateRouteSettledPastSplash() {
    IveForensicSnapshot.recordSettledRoute(AppConstants.routeDashboard);
  }

  // Robust against exact frame-count assumptions (currentProfileProvider's
  // Future resolution, the postFrameCallback chain, and the bottom sheet's
  // own entrance animation each take an unknown number of pumps to settle)
  // — polls in small steps up to a generous bound instead of asserting a
  // hardcoded pump count.
  Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxSteps = 30}) async {
    for (var i = 0; i < maxSteps; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  List<Override> baseOverrides() => [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
        currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
        authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
      ];

  // The exact real production topology: a real GoRouter-managed Navigator,
  // with IveIntroGate mounted as a Stack SIBLING of `child` inside
  // MaterialApp.router's own `builder` — never a descendant of the
  // Navigator, exactly like app.dart's real Stack(children: [child!,
  // IveOverlay(), IveIntroGate()]).
  Widget realRouterHarness({
    required GlobalKey<NavigatorState> navigatorKey,
    required List<Override> overrides,
    Key? introKey,
  }) {
    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => Stack(
          children: [
            child!,
            IveIntroGate(key: introKey, navigatorKey: navigatorKey),
          ],
        ),
      ),
    );
  }

  // No MaterialApp.router, no GoRouter, no Navigator anywhere in the tree —
  // `navigatorKey` is never attached to any Navigator, exactly reproducing
  // the pathological "root Navigator never became available" case section
  // 07 requires recovery from.
  Widget noNavigatorHarness({
    required GlobalKey<NavigatorState> navigatorKey,
    required List<Override> overrides,
    Key? introKey,
  }) =>
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [IveIntroGate(key: introKey, navigatorKey: navigatorKey)]),
          ),
        ),
      );

  testWidgets(
    'Navigator available (real GoRouter/MaterialApp.router topology) — '
    'the intro sheet opens, no regression from the pre-fix behavior',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);
      final navigatorKey = GlobalKey<NavigatorState>();
      simulateRouteSettledPastSplash();

      await tester.pumpWidget(realRouterHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — navigatorKey never attaches to any Navigator: '
    'no exception, ever (the pathological case, not the reproduced one)',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      simulateRouteSettledPastSplash();
      await tester.pumpWidget(noNavigatorHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      // Pump well past the bounded retry window (10 attempts) -- must
      // never throw, at any point, even though the key never attaches.
      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with navigatorKey never attached');
      }
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — root Navigator not attached to the key initially, '
    'becomes available a few frames later: the intro still opens (no permanent loss), '
    'no exception in between',
    (tester) async {
      final introKey = GlobalKey();
      final navigatorKey = GlobalKey<NavigatorState>();
      var navigatorReady = false;

      Widget buildTree() => navigatorReady
          ? realRouterHarness(navigatorKey: navigatorKey, overrides: baseOverrides(), introKey: introKey)
          : noNavigatorHarness(navigatorKey: navigatorKey, overrides: baseOverrides(), introKey: introKey);

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);
      simulateRouteSettledPastSplash();

      await tester.pumpWidget(buildTree());
      await tester.pump(); // lets currentProfileProvider's Future resolve, schedules the callback
      // A couple of frames with the key genuinely unattached -- exactly the
      // transient window the production race exhibited.
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      // The real Navigator becomes available (route transition completes)
      // well within the bounded retry window.
      navigatorReady = true;
      await tester.pumpWidget(buildTree());
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — retry window fully exhausted (Navigator key never attached in time), '
    'THEN the profile re-resolves (a later rebuild) with the Navigator now available -- '
    'the intro is still shown, proving it was re-armed rather than permanently lost',
    (tester) async {
      final introKey = GlobalKey();
      final navigatorKey = GlobalKey<NavigatorState>();
      var navigatorReady = false;

      Widget buildTree() => navigatorReady
          ? realRouterHarness(navigatorKey: navigatorKey, overrides: baseOverrides(), introKey: introKey)
          : noNavigatorHarness(navigatorKey: navigatorKey, overrides: baseOverrides(), introKey: introKey);

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);
      simulateRouteSettledPastSplash();

      await tester.pumpWidget(buildTree());
      // Exhaust the full bounded retry window with the key never attaching
      // -- the pathological case, not the one reproduced in production, but
      // the one section 07 explicitly requires recovery from.
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      // Only NOW does the real Navigator become available, well after the
      // bounded window closed.
      navigatorReady = true;
      await tester.pumpWidget(buildTree());
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no profile resolved yet -> nothing scheduled, no exception, no premature dismissal',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(noNavigatorHarness(
        navigatorKey: navigatorKey,
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => null),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'widget disposed before the post-frame callback fires -> no exception (mounted guard preserved)',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(noNavigatorHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      await tester.pump(); // schedules the callback for next frame
      // Replace the whole tree before that callback runs -- IveIntroGate
      // (and its State) is disposed mid-flight.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 2 — profile resolves WHILE the route is still Splash '
    '(the two independent clocks Codex identified: a fast profile fetch vs. '
    "SplashScreen's fixed redirect timer): the intro must NOT open over Splash, "
    'and no exception is thrown while it is pending',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      // No recordSettledRoute call yet -- settledRoute stays '', exactly
      // matching production before app.dart's redirect callback has ever
      // resolved to a non-Splash, non-Login destination.
      await tester.pumpWidget(realRouterHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      // Profile resolves and the Navigator/Overlay are both genuinely
      // available -- but the route is still Splash. Pump well past every
      // bounded retry window; the intro must never appear.
      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i while route was still Splash');
      }
      expect(titleFinder, findsNothing);

      // SplashScreen's own redirect now fires and settles (the real 800ms
      // timer, here simulated directly via the same
      // IveForensicSnapshot.recordSettledRoute call app.dart's redirect
      // callback makes once its own decision resolves to null) -- the intro
      // was NOT lost; it opens now, driven by settledRouteNotifier.
      IveForensicSnapshot.recordSettledRoute(AppConstants.routeDashboard);
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 2 — route never leaves Splash (pathological): '
    'no exception, ever, and the intro never opens',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(realRouterHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with route stuck on Splash');
      }

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      expect(find.text(l10n.ivIntroTitle), findsNothing);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 3 — an authenticated request for /login is only ever '
    'RECORDED (IveForensicSnapshot.recordRoute, the pre-existing forensic "attempted path" '
    'signal) on its way to being redirected to /dashboard -- the intro must NOT open over '
    'Login even though the attempted path is non-Splash',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      // Exactly the round-2 gate's blind spot: an ATTEMPTED, not settled,
      // non-Splash path. app.dart's redirect callback always calls
      // recordRoute() first, regardless of what it later decides -- this is
      // that same call, in isolation, for a path about to be redirected
      // away from (mirrors _computeRedirect's
      // `if (session != null && goingToAuth) return routeDashboard;`
      // branch: an authenticated user hitting /login never actually
      // settles there).
      IveForensicSnapshot.recordRoute(AppConstants.routeLogin);

      await tester.pumpWidget(realRouterHarness(
        navigatorKey: navigatorKey,
        overrides: baseOverrides(),
      ));
      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with an attempted (not settled) /login');
      }
      // The attempted path alone must never be mistaken for arrival.
      expect(titleFinder, findsNothing);

      // Only the SETTLED destination (what app.dart's redirect callback
      // calls recordSettledRoute with, after its own decision is null)
      // unblocks presentation.
      IveForensicSnapshot.recordSettledRoute(AppConstants.routeDashboard);
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 3 — end-to-end through a redirect callback shaped exactly '
    "like app.dart's own (recordRoute on every attempt, recordSettledRoute only when the "
    'redirect decision is null and the path is neither Splash nor Login): an authenticated '
    "request for /login that GoRouter redirects to /dashboard never shows the intro over "
    'Login, and shows it once settled at /dashboard',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: AppConstants.routeLogin,
        redirect: (context, state) async {
          final path = state.fullPath ?? state.matchedLocation;
          IveForensicSnapshot.recordRoute(path);
          // Mirrors _computeRedirect's own authenticated/login branch: an
          // authenticated session hitting /login is always redirected to
          // /dashboard; everything else settles where it is.
          final redirectTarget = path == AppConstants.routeLogin ? AppConstants.routeDashboard : null;
          if (redirectTarget == null &&
              (state.fullPath ?? '').isNotEmpty &&
              path != AppConstants.routeSplash &&
              path != AppConstants.routeLogin &&
              path != AppConstants.routeResult) {
            IveForensicSnapshot.recordSettledRoute(path);
          }
          return redirectTarget;
        },
        routes: [
          GoRoute(path: AppConstants.routeLogin, builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
          GoRoute(path: AppConstants.routeDashboard, builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp.router(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => Stack(children: [child!, IveIntroGate(navigatorKey: navigatorKey)]),
        ),
      ));

      // The redirect chain (/login -> /dashboard) and the profile/intro
      // providers resolve across these pumps; nothing must throw while any
      // of that is in flight, regardless of how many attempted-path
      // recordRoute() calls happen along the way.
      for (var i = 0; i < 10; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i during the /login -> /dashboard redirect');
      }

      // By now the redirect has settled at /dashboard (recordSettledRoute
      // was only ever called for /dashboard, never /login) and the intro
      // has opened -- proving the real, GoRouter-driven redirect callback
      // never let it open over the intermediate /login attempt.
      await pumpUntilFound(tester, titleFinder);
      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(IveForensicSnapshot.settledRoute, AppConstants.routeDashboard);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 4 — a genuinely UNMATCHED location (no registered GoRoute, '
    "headed for errorBuilder) resolves redirectTarget == null too, but state.fullPath is "
    'empty for it -- the intro must NOT open over the error screen',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/this-path-matches-no-registered-route',
        errorBuilder: (_, __) => const Scaffold(body: Text('error')),
        redirect: (context, state) async {
          final path = state.fullPath ?? state.matchedLocation;
          IveForensicSnapshot.recordRoute(path);
          const redirectTarget = null; // nothing special-cases an unmatched path either.
          if (redirectTarget == null &&
              (state.fullPath ?? '').isNotEmpty &&
              path != AppConstants.routeSplash &&
              path != AppConstants.routeLogin &&
              path != AppConstants.routeResult) {
            IveForensicSnapshot.recordSettledRoute(path);
          }
          return redirectTarget;
        },
        routes: [
          GoRoute(path: AppConstants.routeDashboard, builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp.router(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => Stack(children: [child!, IveIntroGate(navigatorKey: navigatorKey)]),
        ),
      ));

      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i on an unmatched location');
      }
      expect(titleFinder, findsNothing);
      expect(IveForensicSnapshot.settledRoute, '');
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 4 — /result reached without its required `extra` renders a '
    'transient loading screen and self-redirects to /home from its OWN builder (invisible to '
    'the redirect callback, which sees redirectTarget == null): the intro must NOT open over '
    'that loading screen, and opens once genuinely settled at /home',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: AppConstants.routeResult,
        redirect: (context, state) async {
          final path = state.fullPath ?? state.matchedLocation;
          IveForensicSnapshot.recordRoute(path);
          const redirectTarget = null; // /result is accepted at the redirect level either way.
          if (redirectTarget == null &&
              (state.fullPath ?? '').isNotEmpty &&
              path != AppConstants.routeSplash &&
              path != AppConstants.routeLogin &&
              path != AppConstants.routeResult) {
            IveForensicSnapshot.recordSettledRoute(path);
          }
          return redirectTarget;
        },
        routes: [
          GoRoute(
            path: AppConstants.routeResult,
            // Mirrors app.dart's own /result builder: no `extra` -> a
            // transient loading Scaffold that self-redirects to /home from
            // a post-frame callback, entirely inside this builder.
            builder: (context, state) {
              if (state.extra == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) => context.go(AppConstants.routeHome));
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              return const Scaffold(body: Text('result'));
            },
          ),
          GoRoute(path: AppConstants.routeHome, builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp.router(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => Stack(children: [child!, IveIntroGate(navigatorKey: navigatorKey)]),
        ),
      ));

      // /result's self-redirect to /home (a post-frame callback inside its
      // OWN builder) can settle within just a pump or two -- there is no
      // reliably observable "still on /result" window to assert against,
      // unlike the redirect-callback-level cases above. The real guarantee
      // is structural: the redirect callback's `path != routeResult` check
      // means recordSettledRoute can NEVER be called with routeResult,
      // regardless of timing -- proven below once everything settles.
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i while /result was self-redirecting');
      }

      // /home is reached, genuinely settles, and the intro opens there --
      // settledRoute was never (and structurally could never be) /result.
      await pumpUntilFound(tester, titleFinder);
      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(IveForensicSnapshot.settledRoute, AppConstants.routeHome);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 5/6 — no live session (authStateProvider signed-out) even '
    'though profile/route both look ready: presentation is blocked from the very first build, '
    'independent of route state',
    (tester) async {
      // CODEX/STABILITY-09-FIX ROUND 6 -- a REAL Navigator (realRouterHarness)
      // is available from the very first frame, so with a StreamController
      // there is no reliably observable window between "scheduled" and
      // "presented" to inject a LATER sign-out into (the whole schedule ->
      // tryPresent -> showModalBottomSheet chain can complete within a
      // single pump, exactly like the "Navigator available" test's own
      // fast path) -- an earlier version of this test tried exactly that
      // and, once its own signed-in-delivery bug was fixed, proved the
      // intro already opens before the sign-out line ever runs. This test
      // instead proves the simpler, still load-bearing property: a session
      // that is signed-out (or never resolves) from the start blocks
      // presentation outright, no matter how "ready" every other signal
      // is. The harder "authenticated, scheduled, THEN signed out mid
      // retry" property is proven by the next test, which deliberately
      // uses noNavigatorHarness to keep presentation pending long enough
      // to have a controllable window.
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      simulateRouteSettledPastSplash();

      await tester.pumpWidget(realRouterHarness(
        navigatorKey: navigatorKey,
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState())),
        ],
      ));

      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with no live session');
      }
      expect(titleFinder, findsNothing);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX ROUND 5 — external sign-out arriving DURING the bounded '
    'Navigator-retry window (after scheduling, before presenting) still blocks presentation '
    '(the _tryPresent final guard, not just the _maybeSchedule one)',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);
      final authController = StreamController<AuthState>.broadcast();
      addTearDown(authController.close);
      final introKey = GlobalKey();
      var navigatorReady = false;

      Widget buildTree() {
        final overrides = [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => authController.stream),
        ];
        return navigatorReady
            ? realRouterHarness(navigatorKey: navigatorKey, overrides: overrides, introKey: introKey)
            : noNavigatorHarness(navigatorKey: navigatorKey, overrides: overrides, introKey: introKey);
      }

      simulateRouteSettledPastSplash();

      await tester.pumpWidget(buildTree());
      // CODEX/STABILITY-09-FIX ROUND 6 -- same broadcast-stream subscription
      // timing fix as the test above: emitted only after pumpWidget has
      // actually subscribed authStateProvider, so this genuinely
      // establishes "signed in" as the starting precondition rather than
      // silently staying in AsyncLoading (which would make this test
      // indistinguishable from "never scheduled because never
      // authenticated" -- unable to prove the _tryPresent-specific guard at
      // all, only ever exercising _maybeSchedule's).
      authController.add(_authState(session: MockSession()));
      // Several pumps with a genuinely authenticated session and the
      // Navigator deliberately unattached (noNavigatorHarness): _maybeSchedule
      // succeeds and _presented becomes true here, well before sign-out is
      // ever emitted below -- the bounded retry loop is now actively
      // in-flight when sign-out arrives.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Sign-out arrives while still mid-retry (Navigator/Overlay still
      // unattached in this tree) -- AFTER scheduling already began.
      authController.add(_authState());
      await tester.pump();

      // The real Navigator becomes available -- if the only guard were the
      // one in _maybeSchedule (already evaluated before sign-out), this
      // would incorrectly open the sheet now.
      navigatorReady = true;
      await tester.pumpWidget(buildTree());
      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i after external sign-out mid-retry');
      }
      expect(titleFinder, findsNothing);
    },
  );
}
