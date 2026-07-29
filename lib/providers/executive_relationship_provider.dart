import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/executive_relationship.dart';
import '../data/services/executive_relationship_service.dart';
import 'market_analysis_provider.dart';
import 'project_provider.dart';

final _relationshipService = ExecutiveRelationshipService();

/// Todas as relações detectadas entre projetos do portfólio.
final executiveRelationshipsProvider =
    FutureProvider.autoDispose<List<ExecutiveRelationship>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final analyses = await ref.watch(marketAnalysesProvider.future);
  return _relationshipService.detect(projects: projects, analyses: analyses);
});

/// Relações de um projeto específico (como projectA ou projectB).
final projectRelationshipsProvider =
    FutureProvider.autoDispose.family<List<ExecutiveRelationship>, String>(
  (ref, projectId) async {
    final all = await ref.watch(executiveRelationshipsProvider.future);
    return all
        .where((r) => r.projectAId == projectId || r.projectBId == projectId)
        .toList();
  },
);

/// Apenas relações que requerem atenção (duplicatas e conflitos).
final criticalRelationshipsProvider =
    FutureProvider.autoDispose<List<ExecutiveRelationship>>((ref) async {
  final all = await ref.watch(executiveRelationshipsProvider.future);
  return all.where((r) => r.requiresAttention).toList();
});
