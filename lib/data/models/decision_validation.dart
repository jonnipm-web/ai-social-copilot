enum DecisionValidationStatus { approved, blocked, structuring }

class DecisionValidation {
  static const int minCoverage = 60;
  static const int minLearning = 50;

  final String? projectId;   // null = portfolio-level
  final String entityName;
  final DecisionValidationStatus status;

  // Critérios de validação
  final int coverageScore;
  final int learningScore;
  final bool profileComplete;

  // Métricas de evidência para exibição
  final int documentCount;
  final int indexedDocuments;
  final int assetCount;
  final int opportunityCount;

  // Motivos do bloqueio
  final List<String> blockReasons;

  const DecisionValidation({
    this.projectId,
    required this.entityName,
    required this.status,
    required this.coverageScore,
    required this.learningScore,
    required this.profileComplete,
    required this.documentCount,
    required this.indexedDocuments,
    required this.assetCount,
    required this.opportunityCount,
    required this.blockReasons,
  });

  bool get isBlocked =>
      status == DecisionValidationStatus.blocked ||
      status == DecisionValidationStatus.structuring;

  bool get isStructuring => status == DecisionValidationStatus.structuring;

  String get blockMessage => isStructuring
      ? 'Projeto ainda em fase de estruturação. Conhecimento disponível, mas inteligência operacional insuficiente para recomendação estratégica.'
      : 'Dados insuficientes para decisão estratégica.';

  String get indexingStatus =>
      documentCount == 0 ? 'Sem documentos' : '$indexedDocuments/$documentCount indexados';

  String get coverageLabel {
    if (coverageScore >= minCoverage) return '✅ $coverageScore% (mínimo $minCoverage%)';
    return '❌ $coverageScore% (mínimo $minCoverage%)';
  }

  String get learningLabel {
    if (learningScore >= minLearning) return '✅ $learningScore% (mínimo $minLearning%)';
    return '❌ $learningScore% (mínimo $minLearning%)';
  }

  String get profileLabel =>
      profileComplete ? '✅ Completo' : '❌ Incompleto — vincule uma análise de mercado';
}
