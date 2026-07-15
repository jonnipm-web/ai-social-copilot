import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/score_breakdown.dart';
import '../data/models/validation_result.dart';
import '../data/services/intelligence_debug_service.dart';
import 'action_queue_provider.dart';
import 'ecosystem_intelligence_provider.dart';
import 'knowledge_provider.dart';
import 'market_analysis_provider.dart';
import 'market_intelligence_provider.dart';
import 'opportunity_lab_provider.dart';
import 'project_intelligence_provider.dart';
import 'project_provider.dart';
import 'roi_metric_provider.dart';

final _debugService = IntelligenceDebugService();

// ── Score Breakdowns (explainability per project) ──────────────────────────
final scoreBreakdownsProvider =
    FutureProvider.autoDispose<List<ScoreBreakdown>>((ref) async {
  final scores       = await ref.watch(ecosystemScoresProvider.future);
  final projects     = await ref.watch(projectsProvider.future);
  final analyses     = await ref.watch(marketAnalysesProvider.future);
  final actions      = await ref.watch(actionQueueProvider.future);
  final labItems     = await ref.watch(opportunityLabProvider.future);
  final roiMetrics   = await ref.watch(roiMetricsProvider.future);
  final revenuePlans = await ref.watch(allRevenuePlansProvider.future);

  return _debugService.generateBreakdowns(
    scores:       scores,
    projects:     projects,
    analyses:     analyses,
    actions:      actions,
    labItems:     labItems,
    roiMetrics:   roiMetrics,
    revenuePlans: revenuePlans,
  );
});

// ── Validation Report (automated tests T01–T12) ───────────────────────────
final validationReportProvider =
    FutureProvider.autoDispose<ValidationReport>((ref) async {
  final projects          = await ref.watch(projectsProvider.future);
  final knowledgeItems    = await ref.watch(knowledgeItemsProvider.future);
  final learningProfiles  = await ref.watch(personaLearningProfilesProvider.future);
  final analyses          = await ref.watch(marketAnalysesProvider.future);
  final actions           = await ref.watch(actionQueueProvider.future);
  final labItems          = await ref.watch(opportunityLabProvider.future);
  final scores            = await ref.watch(ecosystemScoresProvider.future);
  final recommendations   = await ref.watch(priorityRecommendationsProvider.future);
  final healthScore       = await ref.watch(ecosystemHealthProvider.future);
  // Phase 10I: market profiles + revenue intelligence for T07–T12
  final marketProfiles    = await ref.watch(marketProfilesProvider.future);
  final revenueIntel      = await ref.watch(revenueIntelligenceProvider.future);

  return _debugService.runValidation(
    projects:            projects,
    knowledgeItems:      knowledgeItems,
    learningProfiles:    learningProfiles,
    analyses:            analyses,
    actions:             actions,
    labItems:            labItems,
    scores:              scores,
    recommendations:     recommendations,
    healthScore:         healthScore,
    marketProfiles:      marketProfiles,
    revenueIntelligence: revenueIntel,
  );
});
