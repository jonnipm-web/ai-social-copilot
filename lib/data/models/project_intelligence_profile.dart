import '../../l10n/app_localizations.dart';
import 'knowledge_coverage.dart';
import 'market_analysis.dart';
import 'project.dart';

class ProjectIntelligenceProfile {
  final Project project;
  final MarketAnalysis? analysis;
  final KnowledgeCoverage coverage;
  final String maturityStage;        // 'ideia' | 'validando' | 'crescendo' | 'maduro'
  final List<String> relatedProjectNames;
  final List<String> identifiedTopics;
  final List<String> missingKnowledge;
  final String niche;
  final String targetAudience;
  final String monetizationModel;
  final String valueProposition;
  final DateTime computedAt;

  const ProjectIntelligenceProfile({
    required this.project,
    this.analysis,
    required this.coverage,
    required this.maturityStage,
    required this.relatedProjectNames,
    required this.identifiedTopics,
    required this.missingKnowledge,
    required this.niche,
    required this.targetAudience,
    required this.monetizationModel,
    required this.valueProposition,
    required this.computedAt,
  });

  // R16 — [maturityStage] stays a canonical code; this is display only.
  String maturityLabel(AppLocalizations l10n) {
    switch (maturityStage) {
      case 'maduro':    return l10n.ctxMaturityMature;
      case 'crescendo': return l10n.ctxMaturityGrowing;
      case 'validando': return l10n.ctxMaturityValidating;
      default:          return l10n.ctxMaturityIdea;
    }
  }

  String get maturityEmoji {
    switch (maturityStage) {
      case 'maduro':    return '🌳';
      case 'crescendo': return '🌱';
      case 'validando': return '🔬';
      default:          return '💡';
    }
  }

  bool get hasEnoughData => coverage.score >= 30 && analysis != null;

  String? dataWarning(AppLocalizations l10n) {
    if (analysis == null) return l10n.ctxProfileWarningNoAnalysis;
    if (coverage.score < 20) return l10n.ctxProfileWarningLowData;
    return null;
  }

  // R16 — niche/targetAudience/monetizationModel are EMPTY when unknown
  // (language-neutral; previously the PT sentinel 'Não definido').
  bool get hasNiche             => niche.trim().isNotEmpty;
  bool get hasTargetAudience    => targetAudience.trim().isNotEmpty;
  bool get hasMonetizationModel => monetizationModel.trim().isNotEmpty;

  /// Display value for an optional identity field: the value itself, or the
  /// localized "not defined" label when empty.
  static String displayOrNotDefined(String value, AppLocalizations l10n) =>
      value.trim().isEmpty ? l10n.ctxProfileNotDefined : value;
}
