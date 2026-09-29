import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/ai_enum_labels.dart';
import '../core/utils/app_exceptions.dart';
import '../core/utils/language_utils.dart';
import '../l10n/app_localizations.dart';
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
  if (result == null) throw const AppException(AppErrorCode.notFound);
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
  MarketAnalysisNotifier(this._service, {AppLocalizations Function()? l10n})
      : _l10n = l10n,
        super(const AsyncValue.data(null));

  final MarketAnalysisService _service;

  /// R16 — resolves the CURRENT UI-language localizations at seed time, so
  /// the Opportunity Lab rows persisted below are written in the language
  /// the user is actually using (never hard-coded Portuguese).
  final AppLocalizations Function()? _l10n;

  Future<MarketAnalysis?> analyze(
    String input, {
    String inputType = 'url',
    String? projectId,
    String language = 'pt-BR',
    String? idempotencyKey,
  }) async {
    // R16 — resolve the UI-language localizations BEFORE any await (the
    // autoDispose provider's ref may be gone afterwards).
    final l10n = _resolveL10n();
    state = const AsyncValue.loading();
    try {
      final result = await _service.analyze(
        input,
        inputType: inputType,
        projectId: projectId,
        language: language,
        idempotencyKey: idempotencyKey,
      );
      state = AsyncValue.data(result);

      // Auto-seed Opportunity Lab com as top ações da análise
      await _seedOpportunityLab(result, projectId: projectId, l10n: l10n);

      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);

  AppLocalizations _resolveL10n() {
    try {
      final v = _l10n?.call();
      if (v != null) return v;
    } catch (_) {
      // fall through to the deterministic PT fallback
    }
    return lookupAppLocalizations(const Locale('pt'));
  }

  Future<void> _seedOpportunityLab(
    MarketAnalysis analysis, {
    String? projectId,
    required AppLocalizations l10n,
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
      final texts = buildOpportunitySeedTexts(a, analysis.input, l10n);

      final item = OpportunityLabItem(
        id:               '',
        userId:           uid,
        projectId:        projectId ?? analysis.projectId,
        marketAnalysisId: analysis.id,
        opportunityType:  'content',
        title:            title,
        description:      texts.description,
        marketScore:      analysis.opportunityScore,
        revenueScore:     score,
        finalScore:       analysis.opportunityScore,
        createdAt:        DateTime.now(),
        origin:           'market_analysis',
        sources:          [analysis.id],
        rationale:        texts.rationale,
        confidence:       (score * 0.8).round().clamp(0, 100),
        risks:            texts.risks,
        actionSteps:      texts.actionSteps,
      );
      try {
        await svc.create(item);
      } catch (e) {
        // ignore: avoid_print
        print('[MarketAnalysis] seed opportunity lab error: $e');
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
  (ref) => MarketAnalysisNotifier(
    ref.read(marketAnalysisServiceProvider),
    l10n: () => ref.read(appL10nProvider),
  ),
);

/// R16 — client-built text persisted on an auto-seeded Opportunity Lab row.
class OpportunitySeedTexts {
  const OpportunitySeedTexts({
    required this.description,
    required this.rationale,
    required this.risks,
    required this.actionSteps,
  });
  final String       description;
  final String       rationale;
  final List<String> risks;
  final List<String> actionSteps;
}

/// R16 — builds the persisted Opportunity Lab seed texts for one
/// market-analysis `priority_actions[]` entry in the language of [l10n]
/// (the user's CURRENT UI language). The AI's fixed-value codes
/// ("Alto"/"Médio"/"Baixo") are mapped to localized labels; the AI's own
/// free-text `rationale` is kept as returned.
OpportunitySeedTexts buildOpportunitySeedTexts(
  Map<dynamic, dynamic> action,
  String input,
  AppLocalizations l10n,
) {
  String level(dynamic v) {
    final raw = v?.toString().trim() ?? '';
    return raw.isEmpty ? l10n.uxNotAvailableShort : aiLevelLabel(raw, l10n);
  }

  final effortRaw    = action['effort']?.toString().trim() ?? '';
  final timeframeRaw = action['timeframe']?.toString().trim() ?? '';
  final rationaleRaw = action['rationale'] is String
      ? (action['rationale'] as String).trim()
      : '';

  return OpportunitySeedTexts(
    description: l10n.uxOppSeedDescription(
      level(action['impact']),
      level(action['effort']),
    ),
    rationale: rationaleRaw.isNotEmpty
        ? rationaleRaw
        : l10n.uxOppSeedRationaleFallback(input),
    risks: effortRaw.isNotEmpty
        ? [l10n.uxOppSeedRiskEffort(aiLevelLabel(effortRaw, l10n))]
        : const [],
    actionSteps: timeframeRaw.isNotEmpty
        ? [l10n.uxOppSeedEstimatedTimeframe(aiTimeframeLabel(timeframeRaw, l10n))]
        : const [],
  );
}
