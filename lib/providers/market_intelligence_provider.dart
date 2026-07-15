import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/execution_score.dart';
import '../data/models/market_profile.dart';
import '../data/models/revenue_intelligence.dart';
import '../data/services/market_intelligence_service.dart';
import 'action_queue_provider.dart';
import 'market_analysis_provider.dart';
import 'opportunity_lab_provider.dart';
import 'project_provider.dart';

final _miService = MarketIntelligenceService();

// ── Market Profiles ───────────────────────────────────────────────────────
final marketProfilesProvider =
    FutureProvider.autoDispose<List<MarketProfile>>((ref) async {
  final projects  = await ref.watch(projectsProvider.future);
  final analyses  = await ref.watch(marketAnalysesProvider.future);
  final labItems  = await ref.watch(opportunityLabProvider.future);

  return _miService.computeMarketProfiles(
    projects: projects,
    analyses: analyses,
    labItems: labItems,
  );
});

// ── Revenue Intelligence ──────────────────────────────────────────────────
final revenueIntelligenceProvider =
    FutureProvider.autoDispose<List<RevenueIntelligence>>((ref) async {
  final projects     = await ref.watch(projectsProvider.future);
  final analyses     = await ref.watch(marketAnalysesProvider.future);
  final revenuePlans = await ref.watch(allRevenuePlansProvider.future);

  return _miService.computeRevenueIntelligence(
    projects:     projects,
    analyses:     analyses,
    revenuePlans: revenuePlans,
  );
});

// ── Execution Scores ──────────────────────────────────────────────────────
final executionScoresProvider =
    FutureProvider.autoDispose<List<ExecutionScore>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final actions  = await ref.watch(actionQueueProvider.future);
  final labItems = await ref.watch(opportunityLabProvider.future);

  return _miService.computeExecutionScores(
    projects: projects,
    actions:  actions,
    labItems: labItems,
  );
});

// ── Portfolio Market Health (avg market score across all projects) ────────
final portfolioMarketHealthProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final profiles = await ref.watch(marketProfilesProvider.future);
  if (profiles.isEmpty) return 0;
  return profiles.fold(0, (s, p) => s + p.marketScore) ~/ profiles.length;
});

// ── Portfolio ROI Health (projects with revenue plans vs total) ───────────
final portfolioRoiHealthProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final intel = await ref.watch(revenueIntelligenceProvider.future);
  if (intel.isEmpty) return 0;
  final withPlan = intel.where((i) => i.hasRealPlan).length;
  return (withPlan / intel.length * 100).round();
});

// ── Portfolio Execution Health (avg execution score) ─────────────────────
final portfolioExecutionHealthProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final scores = await ref.watch(executionScoresProvider.future);
  if (scores.isEmpty) return 0;
  return scores.fold(0, (s, e) => s + e.score) ~/ scores.length;
});
