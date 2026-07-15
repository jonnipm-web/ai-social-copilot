import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/knowledge_graph.dart';
import '../data/models/persona_learning_profile.dart';
import '../data/models/project_intelligence_profile.dart';
import '../data/services/project_intelligence_service.dart';
import 'action_queue_provider.dart';
import 'knowledge_provider.dart';
import 'market_analysis_provider.dart';
import 'opportunity_lab_provider.dart';
import 'persona_provider.dart';
import 'persona_training_provider.dart';
import 'project_provider.dart';

final _piService = ProjectIntelligenceService();

// ── Project Intelligence Profiles ─────────────────────────────────────────
final projectIntelligenceProfilesProvider =
    FutureProvider.autoDispose<List<ProjectIntelligenceProfile>>((ref) async {
  final projects      = await ref.watch(projectsProvider.future);
  final analyses      = await ref.watch(marketAnalysesProvider.future);
  final actions       = await ref.watch(actionQueueProvider.future);
  final labItems      = await ref.watch(opportunityLabProvider.future);
  final revenuePlans  = await ref.watch(allRevenuePlansProvider.future);
  final knowledgeList = await ref.watch(knowledgeItemsProvider.future);

  return _piService.computeProfiles(
    projects:            projects,
    analyses:            analyses,
    actions:             actions,
    labItems:            labItems,
    revenuePlans:        revenuePlans,
    totalKnowledgeItems: knowledgeList.length,
  );
});

// ── Persona Learning Profiles ──────────────────────────────────────────────
final personaLearningProfilesProvider =
    FutureProvider.autoDispose<List<PersonaLearningProfile>>((ref) async {
  final personas  = await ref.watch(personasProvider.future);
  final trainings = await ref.watch(allPersonaTrainingsProvider.future);

  return _piService.computeLearningProfiles(
    personas:     personas,
    allTrainings: trainings,
  );
});

// ── Knowledge Graph ────────────────────────────────────────────────────────
final knowledgeGraphProvider =
    FutureProvider.autoDispose<KnowledgeGraph>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final analyses = await ref.watch(marketAnalysesProvider.future);
  final personas = await ref.watch(personasProvider.future);
  final labItems = await ref.watch(opportunityLabProvider.future);

  return _piService.buildGraph(
    projects:  projects,
    analyses:  analyses,
    personas:  personas,
    labItems:  labItems,
  );
});

// ── Portfolio Knowledge Coverage Score (average across projects) ───────────
final portfolioCoverageScoreProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final profiles = await ref.watch(projectIntelligenceProfilesProvider.future);
  return _piService.portfolioCoverageScore(profiles);
});

// ── Average Persona Learning Score ────────────────────────────────────────
final avgLearningScoreProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final profiles = await ref.watch(personaLearningProfilesProvider.future);
  if (profiles.isEmpty) return 0;
  return profiles.fold(0, (s, p) => s + p.learningScore) ~/ profiles.length;
});
