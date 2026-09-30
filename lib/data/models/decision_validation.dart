import '../../l10n/app_localizations.dart';

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

  // R16 — display labels take the presentation-language [AppLocalizations].
  String blockMessage(AppLocalizations l10n) => isStructuring
      ? l10n.ctxDvBlockStructuring
      : l10n.ctxDvBlockInsufficient;

  String indexingStatus(AppLocalizations l10n) => documentCount == 0
      ? l10n.ctxDvNoDocuments
      : l10n.ctxDvIndexedCount(indexedDocuments, documentCount);

  String coverageLabel(AppLocalizations l10n) => l10n.ctxDvThresholdLabel(
      coverageScore >= minCoverage ? '✅' : '❌', coverageScore, minCoverage);

  String learningLabel(AppLocalizations l10n) => l10n.ctxDvThresholdLabel(
      learningScore >= minLearning ? '✅' : '❌', learningScore, minLearning);

  String profileLabel(AppLocalizations l10n) =>
      profileComplete ? l10n.ctxDvProfileComplete : l10n.ctxDvProfileIncomplete;
}
