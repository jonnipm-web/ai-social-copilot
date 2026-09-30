import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/competitor.dart';
import 'package:ai_social_copilot/data/models/content_cluster.dart';
import 'package:ai_social_copilot/data/models/market_analysis.dart';
import 'package:ai_social_copilot/data/models/niche_ranking.dart';
import 'package:ai_social_copilot/data/models/opportunity.dart';
import 'package:ai_social_copilot/data/models/revenue_plan.dart';
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

// COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-02) — worst-case data for the 3
// new Hub summary cards (Niches/Content Cluster/Revenue Planner), same
// "deliberately near worst-case, not a short/lucky value" discipline as
// _analysisWithLongInput() above.
List<NicheRanking> _niches() => [
      NicheRanking(
        id: 'n-1',
        userId: 'user-1',
        marketAnalysisId: 'analysis-1',
        name: 'Consultoria especializada em migração de infraestrutura legada para nuvem híbrida',
        overallScore: 82,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

ContentCluster _contentCluster() => ContentCluster(
      id: 'cc-1',
      userId: 'user-1',
      marketAnalysisId: 'analysis-1',
      mainKeyword: 'estratégias avançadas de otimização de conversão para e-commerce internacional',
      clusters: const [
        {'name': 'Cluster A'},
        {'name': 'Cluster B'},
      ],
      articles: const [
        {'title': 'Artigo 1'},
      ],
      createdAt: DateTime(2026, 1, 1),
    );

RevenuePlan _revenuePlan() => RevenuePlan(
      id: 'rp-1',
      userId: 'user-1',
      marketAnalysisId: 'analysis-1',
      projectName: 'Projeto Teste',
      monthlyModerate: 45000,
      planJson: const {
        'milestones': [
          {'title': 'Atingir os primeiros mil clientes pagantes recorrentes na América Latina', 'target': 10000},
        ],
        'revenue_sources': [
          {'name': 'Assinatura'},
        ],
      },
      createdAt: DateTime(2026, 1, 1),
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
          .overrideWith((ref) async => _revenuePlan()),
      nichesByAnalysisProvider(analysisId)
          .overrideWith((ref) async => _niches()),
      contentClusterByAnalysisProvider(analysisId)
          .overrideWith((ref) async => _contentCluster()),
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
      'MI-RESPONSIVE: Hub (incl. Niche/Content Cluster/Revenue Planner summary cards) renders without RenderFlex overflow at ${entry.key}',
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
          reason: 'no widget in the Hub (including the PQ-02 _NicheSummaryCard/'
              '_ContentClusterSummaryCard/_RevenuePlannerSummaryCard, each fed '
              'a long name/keyword/milestone title here) may overflow at this '
              'breakpoint -- a real exception here is silently clipped content '
              'in a release build',
        );

        expect(find.byType(MarketIntelligenceHubScreen), findsOneWidget);
      },
    );
  }
}
