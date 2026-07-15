class BootstrapProjectResult {
  final String projectId;
  final String projectName;
  final bool success;
  final String? error;
  final int opportunitiesCreated;
  final int actionsCreated;
  final bool revenuePlanCreated;
  final bool roadmapCreated;
  final int personasTrained;

  const BootstrapProjectResult({
    required this.projectId,
    required this.projectName,
    required this.success,
    this.error,
    this.opportunitiesCreated = 0,
    this.actionsCreated = 0,
    this.revenuePlanCreated = false,
    this.roadmapCreated = false,
    this.personasTrained = 0,
  });

  bool get hasIssue => !success || error != null;

  String get summary {
    if (!success) return '❌ Falha: ${error ?? "erro desconhecido"}';
    final parts = <String>[];
    if (opportunitiesCreated > 0) parts.add('$opportunitiesCreated oportunidades');
    if (actionsCreated > 0) parts.add('$actionsCreated ações');
    if (revenuePlanCreated) parts.add('plano de receita');
    if (roadmapCreated) parts.add('roadmap');
    if (personasTrained > 0) parts.add('$personasTrained personas treinadas');
    return parts.isEmpty ? '⚠️ Nada gerado' : '✅ ${parts.join(', ')}';
  }
}

class BootstrapReport {
  final List<BootstrapProjectResult> projectResults;
  final int personasTrainedTotal;
  final DateTime completedAt;

  const BootstrapReport({
    required this.projectResults,
    required this.personasTrainedTotal,
    required this.completedAt,
  });

  int get projectsBootstrapped => projectResults.where((r) => r.success).length;
  int get totalOpportunities =>
      projectResults.fold(0, (s, r) => s + r.opportunitiesCreated);
  int get totalActions => projectResults.fold(0, (s, r) => s + r.actionsCreated);
  int get totalRevenuePlans => projectResults.where((r) => r.revenuePlanCreated).length;
  bool get hasErrors => projectResults.any((r) => r.hasIssue);
}
