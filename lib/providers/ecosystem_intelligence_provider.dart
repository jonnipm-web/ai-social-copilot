import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/ecosystem_score.dart';
import '../data/models/priority_recommendation.dart';
import '../data/models/resource_allocation.dart';
import '../data/models/weekly_briefing.dart';
import '../data/services/ecosystem_intelligence_service.dart';
import 'project_provider.dart';
import 'market_analysis_provider.dart';
import 'action_queue_provider.dart';
import 'opportunity_lab_provider.dart';
import 'roi_metric_provider.dart';

final _eiService = EcosystemIntelligenceService();

// ── Master provider: loads all data and computes ecosystem scores ──────────
final ecosystemScoresProvider =
    FutureProvider.autoDispose<List<EcosystemScore>>((ref) async {
  final projects  = await ref.watch(projectsProvider.future);
  final analyses  = await ref.watch(marketAnalysesProvider.future);
  final actions   = await ref.watch(actionQueueProvider.future);
  final labItems  = await ref.watch(opportunityLabProvider.future);
  final roiList   = await ref.watch(roiMetricsProvider.future);

  return _eiService.computeProjectScores(
    projects:   projects,
    analyses:   analyses,
    actions:    actions,
    labItems:   labItems,
    roiMetrics: roiList,
  );
});

// ── Priority recommendations based on scores ─────────────────────────────
final priorityRecommendationsProvider =
    FutureProvider.autoDispose<List<PriorityRecommendation>>((ref) async {
  final scores   = await ref.watch(ecosystemScoresProvider.future);
  final labItems = await ref.watch(opportunityLabProvider.future);
  final actions  = await ref.watch(actionQueueProvider.future);

  return _eiService.generateRecommendations(
    scores:   scores,
    labItems: labItems,
    actions:  actions,
  );
});

// ── Weekly briefing ────────────────────────────────────────────────────────
final weeklyBriefingProvider =
    FutureProvider.autoDispose<WeeklyBriefing>((ref) async {
  final scores   = await ref.watch(ecosystemScoresProvider.future);
  final analyses = await ref.watch(marketAnalysesProvider.future);
  final actions  = await ref.watch(actionQueueProvider.future);
  final labItems = await ref.watch(opportunityLabProvider.future);
  final roiList  = await ref.watch(roiMetricsProvider.future);

  return _eiService.generateBriefing(
    scores:    scores,
    analyses:  analyses,
    actions:   actions,
    labItems:  labItems,
    roiMetrics: roiList,
  );
});

// ── Resource allocation providers (parameterized by budget) ──────────────
final resourceAllocationHoursProvider =
    Provider.autoDispose.family<AsyncValue<ResourceAllocation>, double>((ref, hours) {
  return ref.watch(ecosystemScoresProvider).whenData((scores) =>
      _eiService.allocateResources(scores: scores, budget: hours, budgetType: 'hours'));
});

final resourceAllocationMoneyProvider =
    Provider.autoDispose.family<AsyncValue<ResourceAllocation>, double>((ref, money) {
  return ref.watch(ecosystemScoresProvider).whenData((scores) =>
      _eiService.allocateResources(scores: scores, budget: money, budgetType: 'money'));
});

// ── Overall ecosystem health score ───────────────────────────────────────
final ecosystemHealthProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final scores = await ref.watch(ecosystemScoresProvider.future);
  if (scores.isEmpty) return 0;
  return scores.fold(0, (s, e) => s + e.ecosystemScore) ~/ scores.length;
});
