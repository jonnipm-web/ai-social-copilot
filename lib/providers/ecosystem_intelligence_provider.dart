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
  final projects     = await ref.watch(projectsProvider.future);
  final analyses     = await ref.watch(marketAnalysesProvider.future);
  final actions      = await ref.watch(actionQueueProvider.future);
  final labItems     = await ref.watch(opportunityLabProvider.future);
  final roiList      = await ref.watch(roiMetricsProvider.future);
  final revenuePlans = await ref.watch(allRevenuePlansProvider.future);

  return _eiService.computeProjectScores(
    projects:      projects,
    analyses:      analyses,
    actions:       actions,
    labItems:      labItems,
    roiMetrics:    roiList,
    revenuePlans:  revenuePlans,
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

// ── Project-scoped briefing (IVE-COMMERCIAL-EXPERIENCE-14, Phase B) ────────
// REUSES the exact same deterministic (non-AI, zero quota cost)
// generateBriefing() computation weeklyBriefingProvider already calls —
// only the four input lists are filtered down to this ONE project first, so
// every BriefingItem this produces is legitimately attributable to
// projectId (mission Section 05: "must contain only data legitimately
// attributable to the selected project. Never present global information
// as project-specific."). ecosystemScoresProvider's own scores already
// carry the full Project object (EcosystemScore.project), so filtering by
// project.id is exact, not a heuristic.
final projectBriefingProvider =
    FutureProvider.autoDispose.family<WeeklyBriefing, String>((ref, projectId) async {
  final scores   = await ref.watch(ecosystemScoresProvider.future);
  final analyses = await ref.watch(marketAnalysesProvider.future);
  final actions  = await ref.watch(actionQueueProvider.future);
  final labItems = await ref.watch(opportunityLabProvider.future);
  final roiList  = await ref.watch(roiMetricsProvider.future);

  return _eiService.generateBriefing(
    scores:     scores.where((s) => s.project.id == projectId).toList(),
    analyses:   analyses.where((a) => a.projectId == projectId).toList(),
    actions:    actions.where((a) => a.projectId == projectId).toList(),
    labItems:   labItems.where((l) => l.projectId == projectId).toList(),
    roiMetrics: roiList.where((r) => r.projectId == projectId).toList(),
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
