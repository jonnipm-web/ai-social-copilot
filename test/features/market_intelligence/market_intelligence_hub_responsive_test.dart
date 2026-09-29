import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/competitor.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/opportunity.dart';
import 'package:ai_social_copilot/features/market_intelligence/screens/market_intelligence_hub_screen.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/market_analysis_provider.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (mobile overflow fix) — physically
// confirmed via market_intelligence_scroll_test.dart's RenderFlex
// assertion at a 390px viewport: `_ExecScoreCard`'s Row(score, Spacer,
// context column) overflowed by ~136px. Flutter strips that assert in
// release builds, so this silently clipped content in production instead
// of throwing -- exactly the class of defect `tester.takeException()`
// catches here across every breakpoint the owner asked to cover.
MarketAnalysis _analysisWithLongInput() => MarketAnalysis(
      id: 'analysis-1',
      userId: 'user-1',
      // Long niche + long input URL -- the two dynamic-width strings
      // _ExecScoreCard renders -- deliberately near worst-case, not a
      // short/lucky value that would mask a real overflow.
      input: 'https://a-fairly-long-example-domain-name.com/path',
      niche: 'Educação online e desenvolvimento de carreira',
      opportunityScore: 78,
      analysisJson: const {
        'revenue_monthly_min': 150000,
        'revenue_monthly_max': 800000,
      },
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

List<Competitor> _competitors() => List.generate(
      3,
      (i) => Competitor(
        id: 'c-$i',
        userId: 'user-1',
        marketAnalysisId: 'analysis-1',
        name: 'Competitor $i',
        url: 'https://competitor$i.example.com',
        similarityScore: 70,
        authorityScore: 80,
        relevanceScore: 75,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

Future<void> _pumpHubAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  const analysisId = 'analysis-1';
  await tester.pumpWidget(ProviderScope(
    overrides: [
      marketAnalysisByIdProvider(analysisId)
          .overrideWith((ref) async => _analysisWithLongInput()),
      competitorsByAnalysisProvider(analysisId)
          .overrideWith((ref) async => _competitors()),
      gapAnalysisByAnalysisProvider(analysisId).overrideWith((ref) async => null),
      opportunitiesByAnalysisProvider(analysisId)
          .overrideWith((ref) async => <Opportunity>[]),
      revenuePlanByAnalysisProvider(analysisId)
          .overrideWith((ref) async => null),
    ],
    child: MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MarketIntelligenceHubScreen(analysisId: analysisId),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final breakpoints = <String, Size>{
    'mobile narrow (360x800)': const Size(360, 800),
    'mobile (390x844)': const Size(390, 844),
    'tablet (768x1024)': const Size(768, 1024),
    'desktop (1920x855)': const Size(1920, 855),
  };

  for (final entry in breakpoints.entries) {
    testWidgets(
      'MI-RESPONSIVE: _ExecScoreCard renders without RenderFlex overflow at ${entry.key}',
      (tester) async {
        final captured = <FlutterErrorDetails>[];
        final original = FlutterError.onError;
        FlutterError.onError = (details) => captured.add(details);
        await _pumpHubAt(tester, entry.value);
        FlutterError.onError = original;
        tester.takeException();

        if (captured.isNotEmpty) {
          // ignore: avoid_print
          print('FULL OVERFLOW DETAIL:\n${captured.first.toString()}');
        }
        expect(
          captured,
          isEmpty,
          reason: 'no widget in the Hub (especially _ExecScoreCard\'s score/'
              'niche/input Rows) may overflow at this breakpoint -- a real '
              'exception here is silently clipped content in a release build',
        );

        expect(find.byType(MarketIntelligenceHubScreen), findsOneWidget);
      },
    );
  }
}
