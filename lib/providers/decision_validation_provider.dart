import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/decision_validation.dart';
import 'project_intelligence_provider.dart';
import 'knowledge_provider.dart';
import 'action_queue_provider.dart';
import 'opportunity_lab_provider.dart';

final decisionValidationMapProvider =
    FutureProvider.autoDispose<Map<String, DecisionValidation>>((ref) async {
  final profiles         = await ref.watch(projectIntelligenceProfilesProvider.future);
  final learningProfiles = await ref.watch(personaLearningProfilesProvider.future);
  final knowledgeItems   = await ref.watch(knowledgeItemsProvider.future);
  final actions          = await ref.watch(actionQueueProvider.future);
  final labItems         = await ref.watch(opportunityLabProvider.future);

  final avgLearning = learningProfiles.isEmpty
      ? 0
      : learningProfiles.map((p) => p.learningScore).reduce((a, b) => a + b) ~/
          learningProfiles.length;

  final totalDocs   = knowledgeItems.length;
  final indexedDocs = knowledgeItems.where((k) => k.status == 'analyzed').length;

  final map = <String, DecisionValidation>{};

  for (final profile in profiles) {
    final projectId       = profile.project.id;
    final coverageScore   = profile.coverage.score;
    final profileComplete = profile.analysis != null;
    final assetCount      = actions.where((a) => a.projectId == projectId).length;
    final opportunityCount = labItems.where((l) => l.projectId == projectId).length;

    // Module 8 — structuring check (no operational intelligence at all)
    final hasNoOperationalIntelligence = opportunityCount == 0 && assetCount == 0;

    // Evidence quality checks
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

    final DecisionValidationStatus status;
    if (hasNoOperationalIntelligence) {
      // Structuring block takes precedence (knowledge exists but no ops intelligence)
      status = DecisionValidationStatus.structuring;
    } else if (blockReasons.isNotEmpty) {
      status = DecisionValidationStatus.blocked;
    } else {
      status = DecisionValidationStatus.approved;
    }

    // For structuring projects, add a descriptive reason
    final reasons = List<String>.from(blockReasons);
    if (hasNoOperationalIntelligence) {
      reasons.add('Nenhuma oportunidade ou ação gerada ainda — execute o Knowledge → Action Engine');
    }

    map[projectId] = DecisionValidation(
      projectId:        projectId,
      entityName:       profile.project.name,
      status:           status,
      coverageScore:    coverageScore,
      learningScore:    avgLearning,
      profileComplete:  profileComplete,
      documentCount:    totalDocs,
      indexedDocuments: indexedDocs,
      assetCount:       assetCount,
      opportunityCount: opportunityCount,
      blockReasons:     reasons,
    );
  }

  return map;
});
