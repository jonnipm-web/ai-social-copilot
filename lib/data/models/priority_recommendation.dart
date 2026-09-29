import '../../core/utils/ecosystem_labels.dart';
import '../../l10n/app_localizations.dart';

enum RecommendationType {
  investProject,
  executeOpportunity,
  runAction,
  pauseProject,
  mitigateRisk,
  quickWin,
  waste,
}

class PriorityRecommendation {
  final String title;
  final String reason;
  final String dataUsed;
  final String expectedImpact;
  final int confidence;
  final RecommendationType type;
  final String? entityId;
  final String? entityName;

  const PriorityRecommendation({
    required this.title,
    required this.reason,
    required this.dataUsed,
    required this.expectedImpact,
    required this.confidence,
    required this.type,
    this.entityId,
    this.entityName,
  });

  /// R16 — localized display label; single source is
  /// [recommendationTypeLabel] in core/utils/ecosystem_labels.dart.
  String typeLabel(AppLocalizations l10n) => recommendationTypeLabel(type, l10n);
}
