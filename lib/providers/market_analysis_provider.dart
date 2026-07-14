import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/market_analysis.dart';
import '../data/models/competitor.dart';
import '../data/models/gap_analysis.dart';
import '../data/models/opportunity.dart';
import '../data/models/niche_ranking.dart';
import '../data/models/content_cluster.dart';
import '../data/models/revenue_plan.dart';
import '../data/models/opportunity_lab_item.dart';
import '../data/services/market_analysis_service.dart';
import '../data/services/opportunity_lab_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final marketAnalysisServiceProvider = Provider<MarketAnalysisService>(
  (_) => MarketAnalysisService(),
);

// List of all market analyses
final marketAnalysesProvider = FutureProvider.autoDispose<List<MarketAnalysis>>((ref) {
  return ref.read(marketAnalysisServiceProvider).fetchAll();
});

// Single market analysis by id
final marketAnalysisByIdProvider =
    FutureProvider.autoDispose.family<MarketAnalysis, String>((ref, id) async {
  final result = await ref.read(marketAnalysisServiceProvider).fetchById(id);
  if (result == null) throw Exception('Análise não encontrada');
  return result;
});

// Competitors for a market analysis
final competitorsByAnalysisProvider =
    FutureProvider.autoDispose.family<List<Competitor>, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchCompetitors(marketAnalysisId);
});

// Gap analysis for a market analysis
final gapAnalysisByAnalysisProvider =
    FutureProvider.autoDispose.family<GapAnalysis?, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchGapAnalysis(marketAnalysisId);
});

// Opportunities for a market analysis
final opportunitiesByAnalysisProvider =
    FutureProvider.autoDispose.family<List<Opportunity>, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchOpportunities(marketAnalysisId);
});

// Niches for a market analysis
final nichesByAnalysisProvider =
    FutureProvider.autoDispose.family<List<NicheRanking>, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchNiches(marketAnalysisId);
});

// Content cluster for a market analysis
final contentClusterByAnalysisProvider =
    FutureProvider.autoDispose.family<ContentCluster?, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchContentCluster(marketAnalysisId);
});

// Revenue plan for a market analysis
final revenuePlanByAnalysisProvider =
    FutureProvider.autoDispose.family<RevenuePlan?, String>((ref, marketAnalysisId) {
  return ref.read(marketAnalysisServiceProvider).fetchRevenuePlan(marketAnalysisId);
});

// Notifier for running market analysis
class MarketAnalysisNotifier extends StateNotifier<AsyncValue<MarketAnalysis?>> {
  MarketAnalysisNotifier(this._service) : super(const AsyncValue.data(null));

  final MarketAnalysisService _service;

  Future<MarketAnalysis?> analyze(String input, {String inputType = 'url'}) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.analyze(input, inputType: inputType);
      state = AsyncValue.data(result);

      // Auto-seed Opportunity Lab with the top priority actions from the analysis
      _seedOpportunityLab(result);

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);

  void _seedOpportunityLab(MarketAnalysis analysis) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final json = analysis.analysisJson;
    final actions = json['priority_actions'] as List<dynamic>? ?? [];
    if (actions.isEmpty) return;

    final svc = OpportunityLabService();
    // Create up to 3 opportunity lab items from the top priority actions
    final top = actions.take(3);
    for (final a in top) {
      if (a is! Map) continue;
      final title = a['action'] as String? ?? '';
      if (title.isEmpty) continue;
      final score = _parseScore(a['roi_expected'] as String?);
      final item = OpportunityLabItem(
        id:              '',
        userId:          uid,
        opportunityType: 'content',
        title:           title,
        description:     'Gerado pelo Market Intelligence — impacto: ${a['impact'] ?? 'N/A'}, esforço: ${a['effort'] ?? 'N/A'}',
        marketScore:     analysis.opportunityScore,
        revenueScore:    score,
        finalScore:      analysis.opportunityScore,
        createdAt:       DateTime.now(),
      );
      svc.create(item).catchError((_) {});
    }
  }

  static int _parseScore(String? s) {
    if (s == null) return 60;
    final digits = RegExp(r'\d+').firstMatch(s)?.group(0);
    if (digits == null) return 60;
    final v = int.tryParse(digits) ?? 60;
    return v.clamp(0, 100);
  }
}

final marketAnalysisNotifierProvider =
    StateNotifierProvider.autoDispose<MarketAnalysisNotifier, AsyncValue<MarketAnalysis?>>(
  (ref) => MarketAnalysisNotifier(ref.read(marketAnalysisServiceProvider)),
);
