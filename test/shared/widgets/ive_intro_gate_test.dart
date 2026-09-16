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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_intro_gate.dart';

class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

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
  });

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
}
