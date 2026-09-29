import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/competitor.dart';
import 'package:ai_social_copilot/data/models/gap_analysis.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/opportunity.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/data/models/revenue_plan.dart';
import 'package:ai_social_copilot/features/market_intelligence/screens/competitor_discovery_screen.dart';
import 'package:ai_social_copilot/features/market_intelligence/screens/market_intelligence_hub_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (Section B) -- Codex's own read-only
// audit (task-mulylshc-h9tydy) of the physically-reproduced P1 scroll-lock
// found no static-source explanation (providers are stable, the global
// NotificationListener never consumes, IveOverlay's hit-test area is
// bounded to its own small Positioned child) and explicitly recommended
// THIS test: mount the real screen with real providers, inside the exact
// SafeArea -> Stack -> NotificationListener -> overlay composition
// app.dart itself builds, then perform a genuine fling and assert
// ScrollPosition.pixels actually moves. A pass here (scroll works in the
// headless Flutter test engine) would mean the defect is NOT in this
// app's Dart/widget code, narrowing it to the Flutter-Web/CanvasKit
// rendering pipeline or the GitHub Pages deployment shell -- information
// no amount of further source reading could produce.
class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

class MockSession extends Mock implements Session {}

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 5,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

AuthState _authState() =>
    AuthState(AuthChangeEvent.signedIn, MockSession());

MarketAnalysis _fakeAnalysis(String id) => MarketAnalysis(
      id: id,
      userId: 'user-1',
      input: 'https://example.com',
      niche: 'Test Niche',
      opportunityScore: 78,
      analysisJson: {
        'revenue_monthly_min': 150000,
        'revenue_monthly_max': 800000,
        'recommendations': [
          'Launch premium subscription program',
          'Institutional fundraising campaign',
          'Technical SEO optimization',
          'Content expansion into emerging languages',
          'AI-based moderation',
        ],
      },
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

List<Competitor> _fakeCompetitors(String analysisId, int count) => List.generate(
      count,
      (i) => Competitor(
        id: 'competitor-$i',
        userId: 'user-1',
        marketAnalysisId: analysisId,
        name: 'Competitor $i',
        url: 'https://competitor$i.example.com',
        similarityScore: 70,
        authorityScore: 80,
        relevanceScore: 75,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

GapAnalysis _fakeGap(String analysisId) => GapAnalysis(
      id: 'gap-1',
      userId: 'user-1',
      marketAnalysisId: analysisId,
      contentGaps: const ['Gap 1', 'Gap 2'],
      seoGaps: const ['SEO gap'],
      authorityGaps: const ['Authority gap'],
      monetizationGaps: const ['Monetization gap'],
      productGaps: const ['Product gap'],
      createdAt: DateTime(2026, 1, 1),
    );

List<Opportunity> _fakeOpportunities(String analysisId, int count) => List.generate(
      count,
      (i) => Opportunity(
        id: 'opportunity-$i',
        userId: 'user-1',
        marketAnalysisId: analysisId,
        title: 'Opportunity $i',
        description: 'Description $i',
        opportunityScore: 70,
        monetizationScore: 60,
        difficultyScore: 40,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

RevenuePlan _fakePlan(String analysisId) => RevenuePlan(
      id: 'plan-1',
      userId: 'user-1',
      marketAnalysisId: analysisId,
      projectName: 'Test',
      monthlyModerate: 300000,
      createdAt: DateTime(2026, 1, 1),
    );

/// Mounts [child] as the sole route's page inside the SAME
/// SafeArea -> Consumer -> Stack(NotificationListener(child), IveOverlay)
/// composition app.dart's MaterialApp.router `builder` uses (app.dart
/// lines ~860-882) -- a screen-only harness would miss the shared overlay
/// layer Codex flagged as the strongest remaining suspect.
Future<void> _pumpAppComposition(
  WidgetTester tester, {
  required List<Override> overrides,
  required Widget child,
  bool includeOverlay = true,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, __) => child)],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
      currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
      authStateProvider.overrideWith((ref) => Stream.value(_authState())),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, routedChild) => SafeArea(
        top: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: ivePageScrollNotification,
              child: routedChild!,
            ),
            if (includeOverlay) IveOverlay(navigatorKey: navigatorKey),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// `pumpAndSettle()` waits for ZERO pending timers, but
/// `ivePageScrollNotification` (ive_overlay.dart) deliberately arms a
/// 400ms debounce `Timer` on every `ScrollEndNotification` -- real,
/// intentional app behavior (see that function's own doc comment), not a
/// defect. A `fling` inside `pumpAndSettle` re-triggers that timer on each
/// settle pass and never quiesces, so this app's own screens cannot be
/// driven with `pumpAndSettle` once mounted under the real overlay
/// composition. Pumping a bounded, generous number of fixed frames instead
/// settles animations/futures without waiting out that timer.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  const analysisId = 'analysis-1';

  testWidgets(
    'MI-SCROLL-00 (diagnostic): MarketIntelligenceHubScreen WITHOUT '
    'IveOverlay -- isolates whether the overlay is why pumpAndSettle never '
    'quiesces',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 855);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpAppComposition(
        tester,
        includeOverlay: false,
        overrides: [
          marketAnalysisByIdProvider(analysisId)
              .overrideWith((ref) async => _fakeAnalysis(analysisId)),
          competitorsByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeCompetitors(analysisId, 8)),
          gapAnalysisByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeGap(analysisId)),
          opportunitiesByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeOpportunities(analysisId, 5)),
          revenuePlanByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakePlan(analysisId)),
        ],
        child: const MarketIntelligenceHubScreen(analysisId: analysisId),
      );
      await _settle(tester);

      final scrollableFinder = find.byType(Scrollable).first;
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      final position = scrollableState.position;

      expect(position.maxScrollExtent, greaterThan(0));

      final before = position.pixels;
      await tester.fling(scrollableFinder, const Offset(0, -600), 2000);
      await _settle(tester);
      final after = position.pixels;

      expect(after, greaterThan(before));
    },
  );

  testWidgets(
    'MI-SCROLL-01: MarketIntelligenceHubScreen -- a real fling moves '
    'ScrollPosition.pixels inside the full app-level Stack/overlay composition',
    (tester) async {
      // Replicates the exact desktop viewport used for the live browser
      // reproduction (1920x855 real / ~1568x698 screenshot-scaled) -- the
      // narrower 390x844 mobile size independently surfaced a SEPARATE
      // RenderFlex overflow in _ExecScoreCard (score digits vs. niche
      // badge Row), which is a real defect but not necessarily the one
      // physically reproduced on desktop. Isolating the variable here.
      tester.view.physicalSize = const Size(1920, 855);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpAppComposition(
        tester,
        overrides: [
          marketAnalysisByIdProvider(analysisId)
              .overrideWith((ref) async => _fakeAnalysis(analysisId)),
          competitorsByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeCompetitors(analysisId, 8)),
          gapAnalysisByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeGap(analysisId)),
          opportunitiesByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeOpportunities(analysisId, 5)),
          revenuePlanByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakePlan(analysisId)),
        ],
        child: const MarketIntelligenceHubScreen(analysisId: analysisId),
      );
      await _settle(tester);

      final scrollableFinder = find.byType(Scrollable).first;
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      final position = scrollableState.position;

      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: 'the Hub has far more content than the 855px test viewport; '
            'a zero maxScrollExtent here would mean the test setup itself is '
            'not representative (vacuous test), not that scrolling truly works',
      );

      final before = position.pixels;
      await tester.fling(scrollableFinder, const Offset(0, -600), 2000);
      await _settle(tester);
      final after = position.pixels;

      expect(
        after,
        greaterThan(before),
        reason: 'a real fling gesture must move the SingleChildScrollView -- '
            'this is the exact symptom physically reproduced live: zero '
            'movement under mouse wheel, drag, and keyboard End on the '
            'deployed Flutter-Web build',
      );
    },
  );

  testWidgets(
    'MI-SCROLL-02: CompetitorDiscoveryScreen -- a real fling moves '
    'ScrollPosition.pixels with 15 real competitor rows',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 855);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpAppComposition(
        tester,
        overrides: [
          marketAnalysisByIdProvider(analysisId)
              .overrideWith((ref) async => _fakeAnalysis(analysisId)),
          competitorsByAnalysisProvider(analysisId)
              .overrideWith((ref) async => _fakeCompetitors(analysisId, 15)),
        ],
        child: const CompetitorDiscoveryScreen(analysisId: analysisId),
      );
      await _settle(tester);

      final scrollableFinder = find.byType(Scrollable).first;
      final scrollableState = tester.state<ScrollableState>(scrollableFinder);
      final position = scrollableState.position;

      expect(
        position.maxScrollExtent,
        greaterThan(0),
        reason: '15 competitor cards far exceed the 855px test viewport',
      );

      final before = position.pixels;
      await tester.fling(scrollableFinder, const Offset(0, -600), 2000);
      await _settle(tester);
      final after = position.pixels;

      expect(after, greaterThan(before));
    },
  );
}
