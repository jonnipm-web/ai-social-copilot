import 'dart:math' as math;

import '../../l10n/app_localizations.dart';
import 'action_queue_item.dart';
import 'market_analysis.dart';
import 'opportunity_lab_item.dart';
import 'project.dart';
import 'revenue_plan.dart';

class KnowledgeCoverage {
  final String projectId;
  final String projectName;
  final int score;
  final int docPoints;
  final int oppPoints;
  final int actionPoints;
  final int roadmapPoints;
  final int revenuePoints;
  final int personaPoints;
  final List<String> gaps;      // R16: language-neutral codes (kGap*)
  final List<String> strengths; // R16: language-neutral codes (kStrength*)

  const KnowledgeCoverage({
    required this.projectId,
    required this.projectName,
    required this.score,
    required this.docPoints,
    required this.oppPoints,
    required this.actionPoints,
    required this.roadmapPoints,
    required this.revenuePoints,
    required this.personaPoints,
    required this.gaps,
    required this.strengths,
  });

  // Legacy aliases used by existing widgets
  int get analysisPoints  => 0;
  int get knowledgePoints => docPoints;
  int get opportunityPoints => oppPoints;

  String coverageLabel(AppLocalizations l10n) {
    if (score >= 80) return l10n.ctxCoverageExcellent;
    if (score >= 60) return l10n.ctxCoverageGood;
    if (score >= 40) return l10n.ctxCoverageModerate;
    if (score >= 20) return l10n.ctxCoverageBasic;
    return l10n.ctxCoverageMinimal;
  }

  // ── R16 — gaps/strengths are stored as language-neutral CODES ─────────────
  // (see the k* constants below) and rendered in the presentation language
  // only at display time via [gapLabel]/[strengthLabel].
  static const kGapNoDocuments       = 'no_documents';
  static const kGapNoOpportunities   = 'no_opportunities';
  static const kGapNoActions         = 'no_actions';
  static const kGapNoRoadmap         = 'no_roadmap';
  static const kGapNoRevenuePlan     = 'no_revenue_plan';
  static const kGapUntrainedPersonas = 'untrained_personas';

  static const kStrengthKnowledgeBase   = 'knowledge_base';
  static const kStrengthOpportunities   = 'opportunities_mapped';
  static const kStrengthActions         = 'actions_planned';
  static const kStrengthRoadmap         = 'roadmap_structured';
  static const kStrengthRevenuePlan     = 'revenue_plan';
  static const kStrengthTrainedPersonas = 'trained_personas';

  static String gapLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case kGapNoDocuments:       return l10n.ctxGapNoDocuments;
      case kGapNoOpportunities:   return l10n.ctxGapNoOpportunities;
      case kGapNoActions:         return l10n.ctxGapNoActions;
      case kGapNoRoadmap:         return l10n.ctxGapNoRoadmap;
      case kGapNoRevenuePlan:     return l10n.ctxGapNoRevenuePlan;
      case kGapUntrainedPersonas: return l10n.ctxGapUntrainedPersonas;
      default:                    return code;
    }
  }

  static String strengthLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case kStrengthKnowledgeBase:   return l10n.ctxStrengthKnowledgeBase;
      case kStrengthOpportunities:   return l10n.ctxStrengthOpportunities;
      case kStrengthActions:         return l10n.ctxStrengthActions;
      case kStrengthRoadmap:         return l10n.ctxStrengthRoadmap;
      case kStrengthRevenuePlan:     return l10n.ctxStrengthRevenuePlan;
      case kStrengthTrainedPersonas: return l10n.ctxStrengthTrainedPersonas;
      default:                       return code;
    }
  }

  List<String> gapLabels(AppLocalizations l10n) =>
      gaps.map((g) => gapLabel(g, l10n)).toList();

  List<String> strengthLabels(AppLocalizations l10n) =>
      strengths.map((g) => strengthLabel(g, l10n)).toList();

  String get coverageEmoji {
    if (score >= 80) return '🟢';
    if (score >= 60) return '🔵';
    if (score >= 40) return '🟡';
    if (score >= 20) return '🟠';
    return '🔴';
  }

  // ── Coverage 2.0 ──────────────────────────────────────────────────────────
  // Documentos  25 pts  — conhecimento bruto indexado
  // Oportunidades 20 pts  — inteligência de oportunidades
  // Ações       20 pts  — plano de execução
  // Roadmap     15 pts  — visão estruturada de futuro
  // Revenue Plan 10 pts  — viabilidade financeira
  // Personas    10 pts  — capacidade de comunicação treinada
  // Total       100 pts
  static KnowledgeCoverage compute({
    required Project project,
    required MarketAnalysis? analysis,       // kept for compat; no longer scores
    required int knowledgeItemCount,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required RevenuePlan? revenuePlan,
    int trainedPersonaCount = 0,
  }) {
    final docPts      = math.min(25, knowledgeItemCount * 5);
    final oppPts      = math.min(20, labItems.length * 7);
    final actionPts   = math.min(20, actions.length * 4);
    final hasRoadmap  = _projectHasRoadmap(project);
    final roadmapPts  = hasRoadmap ? 15 : 0;
    final revenuePts  = revenuePlan != null ? 10 : 0;
    final personaPts  = math.min(10, trainedPersonaCount * 5);

    final total = docPts + oppPts + actionPts + roadmapPts + revenuePts + personaPts;

    final gaps = <String>[];
    if (knowledgeItemCount == 0) gaps.add(kGapNoDocuments);
    if (labItems.isEmpty)        gaps.add(kGapNoOpportunities);
    if (actions.isEmpty)         gaps.add(kGapNoActions);
    if (!hasRoadmap)             gaps.add(kGapNoRoadmap);
    if (revenuePlan == null)     gaps.add(kGapNoRevenuePlan);
    if (trainedPersonaCount == 0) gaps.add(kGapUntrainedPersonas);

    final strengths = <String>[];
    if (knowledgeItemCount >= 3) strengths.add(kStrengthKnowledgeBase);
    if (labItems.length >= 3)    strengths.add(kStrengthOpportunities);
    if (actions.length >= 3)     strengths.add(kStrengthActions);
    if (hasRoadmap)              strengths.add(kStrengthRoadmap);
    if (revenuePlan != null)     strengths.add(kStrengthRevenuePlan);
    if (trainedPersonaCount > 0) strengths.add(kStrengthTrainedPersonas);

    return KnowledgeCoverage(
      projectId:      project.id,
      projectName:    project.name,
      score:          total.clamp(0, 100),
      docPoints:      docPts,
      oppPoints:      oppPts,
      actionPoints:   actionPts,
      roadmapPoints:  roadmapPts,
      revenuePoints:  revenuePts,
      personaPoints:  personaPts,
      gaps:           gaps,
      strengths:      strengths,
    );
  }

  static bool _projectHasRoadmap(Project project) {
    final details = project.detailsJson;
    final roadmap = details['roadmap'];
    if (roadmap == null) return false;
    if (roadmap is Map) {
      final items = [
        ...(roadmap['short_term'] as List? ?? []),
        ...(roadmap['medium_term'] as List? ?? []),
        ...(roadmap['long_term'] as List? ?? []),
      ];
      return items.isNotEmpty;
    }
    return false;
  }
}
