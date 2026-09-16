// STABILITY-09-FIX — regression coverage for the exact race a symbolicated
// production stack proved (mission STABILITY-09O-SHA): IveIntroGate is
// mounted as a Stack SIBLING of GoRouter's own Router/Navigator (see
// app.dart's MaterialApp.router builder), not a descendant of it, so on the
// very first route transition (splash -> dashboard/login, driven by the
// SAME currentProfileProvider resolution that triggers this widget's
// one-time intro-scheduling) the Navigator can be transiently unmounted for
// one or a few frames. These tests reproduce that exact topology (a widget
// tree with NO Navigator ancestor, later replaced by one) rather than a
// generic/unrelated Navigator failure.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  // No MaterialApp, no Navigator, no Router -- the exact real topology
  // IveIntroGate occupies for one or more frames during the production
  // race: reachable ancestors are only Directionality/MediaQuery, nothing
  // that can satisfy Navigator.maybeOf(context).
  Widget noNavigatorHarness(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [IveIntroGate()]),
          ),
        ),
      );

  Widget withNavigatorHarness(List<Override> overrides) => ProviderScope(
        overrides: overrides,
        // locale must be explicit (matches ive_intro_sheet_test.dart's own
        // harness) -- without it MaterialApp falls back to the test
        // environment's system locale, not 'pt', and every find.text(...)
        // below (which loads PT-BR strings explicitly) finds nothing.
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Stack(children: [IveIntroGate()])),
        ),
      );

  testWidgets(
    'Navigator available from the first frame (normal/steady-state case) — '
    'the intro sheet opens, no regression from the pre-fix behavior',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      await tester.pumpWidget(withNavigatorHarness(baseOverrides()));
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — Navigator genuinely absent for several frames: '
    'no exception, ever (this is the exact symbolicated production crash)',
    (tester) async {
      await tester.pumpWidget(noNavigatorHarness(baseOverrides()));
      // Pump well past the bounded retry window (10 attempts) -- must
      // never throw, at any point, even though a Navigator never appears.
      for (var i = 0; i < 15; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with no Navigator ever available');
      }
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — Navigator absent initially, becomes available a few '
    'frames later: the intro still opens (no permanent loss), no exception in between',
    (tester) async {
      final introKey = GlobalKey();
      var navigatorReady = false;

      Widget buildTree() {
        final overrides = baseOverrides();
        if (!navigatorReady) {
          return ProviderScope(
            overrides: overrides,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(children: [IveIntroGate(key: introKey)]),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [IveIntroGate(key: introKey)])),
          ),
        );
      }

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      await tester.pumpWidget(buildTree());
      await tester.pump(); // lets currentProfileProvider's Future resolve, schedules the callback
      // A couple of frames with genuinely no Navigator -- exactly the
      // transient window the production race exhibited.
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Navigator becomes available (route transition completes) well
      // within the bounded retry window.
      navigatorReady = true;
      await tester.pumpWidget(buildTree());
      await pumpUntilFound(tester, titleFinder);

      expect(titleFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'CODEX/STABILITY-09-FIX — retry window fully exhausted (Navigator never appeared in time), '
    'THEN the profile re-resolves (a later rebuild) with a Navigator now available -- '
    'the intro is still shown, proving it was re-armed rather than permanently lost',
    (tester) async {
      final introKey = GlobalKey();
      var navigatorReady = false;

      Widget buildTree() {
        final overrides = baseOverrides();
        if (!navigatorReady) {
          return ProviderScope(
            overrides: overrides,
            child: MediaQuery(
              data: const MediaQueryData(),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(children: [IveIntroGate(key: introKey)]),
              ),
            ),
          );
        }
        return ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [IveIntroGate(key: introKey)])),
          ),
        );
      }

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      final titleFinder = find.text(l10n.ivIntroTitle);

      await tester.pumpWidget(buildTree());
      // Exhaust the full bounded retry window with NO Navigator ever
      // appearing -- the pathological case, not the one reproduced in
      // production, but the one section 07 explicitly requires recovery
      // from.
      for (var i = 0; i < 12; i++) {
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      // Only NOW does a Navigator become available, well after the
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
      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => null),
        ],
        child: const MediaQuery(
          data: MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [IveIntroGate()]),
          ),
        ),
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
      await tester.pumpWidget(noNavigatorHarness(baseOverrides()));
      await tester.pump(); // schedules the callback for next frame
      // Replace the whole tree before that callback runs -- IveIntroGate
      // (and its State) is disposed mid-flight.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
