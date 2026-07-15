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

// All revenue plans — used by ecosystem scoring
final allRevenuePlansProvider = FutureProvider.autoDispose<List<RevenuePlan>>((ref) {
  return ref.read(marketAnalysisServiceProvider).fetchAllRevenuePlans();
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
      await _seedOpportunityLab(result);

      // Auto-link matching project by URL so ecosystem scores become non-zero immediately
      if (inputType == 'url') await _tryLinkProject(result, input);

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);

  Future<void> _seedOpportunityLab(MarketAnalysis analysis) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final json = analysis.analysisJson;
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
        marketAnalysisId: analysis.id,
        opportunityType:  'content',
        title:            title,
        description:      'Gerado pelo Market Intelligence — impacto: ${a['impact'] ?? 'N/A'}, esforço: ${a['effort'] ?? 'N/A'}',
        marketScore:      analysis.opportunityScore,
        revenueScore:     score,
        finalScore:       analysis.opportunityScore,
        createdAt:        DateTime.now(),
      );
      try {
        await svc.create(item);
      } catch (e) {
        // Log but don't fail the main analysis flow
        // ignore: avoid_print
        print('[MarketAnalysis] seed opportunity lab error: $e');
      }
    }
  }

  // Auto-link the analysis to a project whose URL matches the analyzed input
  Future<void> _tryLinkProject(MarketAnalysis analysis, String input) async {
    try {
      final client = Supabase.instance.client;
      final normInput = _normalizeUrl(input);

      final rows = await client
          .from('projects')
          .select('id, url, market_analysis_id')
          .is_('market_analysis_id', null);

      for (final row in (rows as List)) {
        final url = row['url'] as String? ?? '';
        if (url.isEmpty) continue;
        if (_normalizeUrl(url) == normInput) {
          await client
              .from('projects')
              .update({
                'market_analysis_id': analysis.id,
                'opportunity_score':  analysis.opportunityScore,
                'updated_at':         DateTime.now().toIso8601String(),
              })
              .eq('id', row['id'] as String);
          break;
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[MarketAnalysis] auto-link project error: $e');
    }
  }

  static String _normalizeUrl(String url) => url
      .toLowerCase()
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'^www\.'), '')
      .replaceAll(RegExp(r'/$'), '')
      .split('?').first;

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
