import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/decision_validation.dart';
import 'project_intelligence_provider.dart';
import 'knowledge_provider.dart';
import 'action_queue_provider.dart';
import 'opportunity_lab_provider.dart';

final decisionValidationMapProvider =
    FutureProvider.autoDispose<Map<String, DecisionValidation>>((ref) async {
  final profiles        = await ref.watch(projectIntelligenceProfilesProvider.future);
  final learningProfiles = await ref.watch(personaLearningProfilesProvider.future);
  final knowledgeItems  = await ref.watch(knowledgeItemsProvider.future);
  final actions         = await ref.watch(actionQueueProvider.future);
  final labItems        = await ref.watch(opportunityLabProvider.future);

  final avgLearning = learningProfiles.isEmpty
      ? 0
      : learningProfiles.map((p) => p.learningScore).reduce((a, b) => a + b) ~/
          learningProfiles.length;

  final totalDocs   = knowledgeItems.length;
  final indexedDocs = knowledgeItems.where((k) => k.status == 'analyzed').length;

  final map = <String, DecisionValidation>{};

  for (final profile in profiles) {
    final projectId      = profile.project.id;
    final coverageScore  = profile.coverage.score;
    final profileComplete = profile.analysis != null;
    final assetCount      = actions.where((a) => a.projectId == projectId).length;
    final opportunityCount = labItems.where((l) => l.projectId == projectId).length;

    final blockReasons = <String>[];
    if (coverageScore < DecisionValidation.minCoverage) {
      blockReasons.add(
          'Knowledge Coverage insuficiente ($coverageScore% < ${DecisionValidation.minCoverage}%)');
    }
    if (avgLearning < DecisionValidation.minLearning) {
      blockReasons.add(
          'Learning Score médio insuficiente ($avgLearning% < ${DecisionValidation.minLearning}%)');
    }
    if (!profileComplete) {
      blockReasons.add('Perfil de inteligência incompleto — vincule uma análise de mercado');
    }

    map[projectId] = DecisionValidation(
      projectId:       projectId,
      entityName:      profile.project.name,
      status:          blockReasons.isEmpty
          ? DecisionValidationStatus.approved
          : DecisionValidationStatus.blocked,
      coverageScore:   coverageScore,
      learningScore:   avgLearning,
      profileComplete: profileComplete,
      documentCount:   totalDocs,
      indexedDocuments: indexedDocs,
      assetCount:      assetCount,
      opportunityCount: opportunityCount,
      blockReasons:    blockReasons,
    );
  }

  return map;
});
