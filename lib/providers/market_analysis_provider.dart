import 'package:flutter/foundation.dart';
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

// Market analyses filtered by project_id
final marketAnalysesByProjectProvider =
    FutureProvider.autoDispose.family<List<MarketAnalysis>, String>((ref, projectId) {
  return ref.read(marketAnalysisServiceProvider).fetchAll(projectId: projectId);
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

// All revenue plans — used by ecosystem scoring
final allRevenuePlansProvider = FutureProvider.autoDispose<List<RevenuePlan>>((ref) {
  return ref.read(marketAnalysisServiceProvider).fetchAllRevenuePlans();
});

// Revenue plans filtered by project_id
final revenuePlansByProjectProvider =
    FutureProvider.autoDispose.family<List<RevenuePlan>, String>((ref, projectId) {
  return ref.read(marketAnalysisServiceProvider).fetchAllRevenuePlans(projectId: projectId);
});

// Notifier for running market analysis
class MarketAnalysisNotifier extends StateNotifier<AsyncValue<MarketAnalysis?>> {
  MarketAnalysisNotifier(this._service) : super(const AsyncValue.data(null));

  final MarketAnalysisService _service;

  Future<MarketAnalysis?> analyze(
    String input, {
    String inputType = 'url',
    String? projectId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.analyze(
        input,
        inputType: inputType,
        projectId: projectId,
      );
      state = AsyncValue.data(result);

      // Auto-seed Opportunity Lab com as top ações da análise
      await _seedOpportunityLab(result, projectId: projectId);

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);

  Future<void> _seedOpportunityLab(
    MarketAnalysis analysis, {
    String? projectId,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final json    = analysis.analysisJson;
    final actions = json['priority_actions'] as List<dynamic>? ?? [];
    if (actions.isEmpty) return;

    final svc = OpportunityLabService();
    final top = actions.take(3);
    for (final a in top) {
      if (a is! Map) continue;
      final title = a['action'] as String? ?? '';
      if (title.isEmpty) continue;
      final score = _parseScore(a['roi_expected'] as String?);

      final item = OpportunityLabItem(
        id:               '',
        userId:           uid,
        projectId:        projectId ?? analysis.projectId,
        marketAnalysisId: analysis.id,
        opportunityType:  'content',
        title:            title,
        description:      'Impacto: ${a['impact'] ?? 'N/A'} · Esforço: ${a['effort'] ?? 'N/A'}',
        marketScore:      analysis.opportunityScore,
        revenueScore:     score,
        finalScore:       analysis.opportunityScore,
        createdAt:        DateTime.now(),
        origin:           'market_analysis',
        sources:          [analysis.id],
        rationale:        a['rationale'] as String? ??
            'Identificado pelo Market Intelligence com base na análise de ${analysis.input}.',
        confidence:       (score * 0.8).round().clamp(0, 100),
        risks:            a['effort'] != null ? ['Esforço: ${a['effort']}'] : [],
        actionSteps:      a['timeframe'] != null ? ['Prazo estimado: ${a['timeframe']}'] : [],
      );
      try {
        await svc.create(item);
      } catch (e) {
        debugPrint('[MarketAnalysis] seed opportunity lab error: $e');
      }
    }
  }

  // _tryLinkProject REMOVIDO — o project_id agora é passado diretamente ao criar a análise

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
