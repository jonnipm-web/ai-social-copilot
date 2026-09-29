import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;

import '../../core/utils/ecosystem_labels.dart';
import '../../l10n/app_localizations.dart';
import '../models/action_queue_item.dart';
import '../models/ecosystem_score.dart';
import '../models/execution_score.dart';
import '../models/market_analysis.dart';
import '../models/market_profile.dart';
import '../models/opportunity_lab_item.dart';
import '../models/priority_recommendation.dart';
import '../models/project.dart';
import '../models/resource_allocation.dart';
import '../models/revenue_intelligence.dart';
import '../models/revenue_plan.dart';
import '../models/roi_metric.dart';
import '../models/weekly_briefing.dart';

class EcosystemIntelligenceService {
  /// R16 — every deterministic sentence this service produces (strengths,
  /// risks, recommendations, allocation reasons, briefing text, execution
  /// explanations) is rendered in the PRESENTATION language via [l10n].
  /// Providers pass `ref.watch(appL10nProvider)` so a language switch
  /// recomputes the text. Verdict codes ('ESCALAR', 'PAUSAR', ...) stay
  /// canonical logic keys — only their display goes through
  /// [ecosystemVerdictLabel]. Omitting [l10n] keeps the legacy PT output.
  EcosystemIntelligenceService({AppLocalizations? l10n})
      : _l10n = l10n ?? lookupAppLocalizations(const Locale('pt'));

  final AppLocalizations _l10n;

  // ── Public API ────────────────────────────────────────────────────────────

  List<EcosystemScore> computeProjectScores({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<RoiMetric> roiMetrics,
    List<RevenuePlan> revenuePlans = const [],
  }) {
    final now    = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 30));

    return projects.map((p) {
      final analysis  = _findAnalysisMatch(p, analyses);
      final plan      = _findRevenuePlan(p, analysis, revenuePlans);
      final pActions  = actions.where((a) => a.projectId == p.id).toList();
      final pLab      = labItems.where((l) => l.projectId == p.id).toList();
      final pRoi      = roiMetrics.where((r) => r.projectId == p.id).toList();
      final hasRoadmap = _projectHasRoadmap(p);

      final marketPts = _marketScore(analysis, pLab);
      final execPts   = _computeExecutionScore(pActions, pLab, hasRoadmap);
      final oppScore  = _opportunityScore(p, analysis, pLab);
      final roi       = _roiScore(pRoi, plan);
      final strategic = _strategicFit(marketPts, roi, execPts.score, p);
      final synergy   = _synergyScore(p, analysis, pLab, pActions);
      final momentum  = _momentumScore(pActions, pLab, cutoff);
      final ecosystem = _weighted(oppScore, strategic, synergy, roi, momentum);

      final enough = _hasEnoughData(analysis, plan, pActions, pLab);
      final rec    = _recommend(ecosystem, enough);

      final totalRoi  = pRoi.fold(0.0, (s, r) => s + r.metricValue);
      final completed = pActions.where((a) => a.status == 'completed').length;

      return EcosystemScore(
        project:          p,
        opportunityScore: oppScore,
        strategicFit:     strategic,
        synergyScore:     synergy,
        roiScore:         roi,
        momentumScore:    momentum,
        ecosystemScore:   ecosystem,
        recommendation:   rec,
        strengths:        _strengths(p, analysis, roi, synergy, momentum, marketPts),
        risks:            _risks(p, pActions, roi, momentum, enough),
        quickWins:        _quickWins(pActions),
        totalRoi:         totalRoi,
        actionCount:      pActions.length,
        completedActions: completed,
        labItemCount:     pLab.length,
        marketScore:      marketPts,
        executionScore:   execPts.score,
        hasEnoughData:    enough,
      );
    }).toList()
      ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  }

  List<MarketProfile> computeMarketProfiles({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<OpportunityLabItem> labItems,
  }) {
    return projects.map((p) {
      final analysis = _findAnalysisMatch(p, analyses);
      return MarketProfile.compute(
        project:  p,
        analysis: analysis,
        labItems: labItems,
      );
    }).toList();
  }

  List<RevenueIntelligence> computeRevenueIntelligence({
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<RevenuePlan> revenuePlans,
  }) {
    return projects.map((p) {
      final analysis = _findAnalysisMatch(p, analyses);
      final plan     = _findRevenuePlan(p, analysis, revenuePlans);
      return plan != null
          ? RevenueIntelligence.fromPlan(plan)
          : RevenueIntelligence.empty(p.id, p.name);
    }).toList();
  }

  List<ExecutionScore> computeExecutionScores({
    required List<Project> projects,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
  }) {
    return projects.map((p) {
      final pActions = actions.where((a) => a.projectId == p.id).toList();
      final pLab     = labItems.where((l) => l.projectId == p.id).toList();
      return _computeExecutionScore(pActions, pLab, _projectHasRoadmap(p));
    }).toList();
  }

  List<PriorityRecommendation> generateRecommendations({
    required List<EcosystemScore> scores,
    required List<OpportunityLabItem> labItems,
    required List<ActionQueueItem> actions,
  }) {
    final l10n = _l10n;
    final recs = <PriorityRecommendation>[];

    // TOP projects to scale or accelerate
    final topProjects = scores
        .where((s) => s.recommendation == 'ESCALAR' || s.recommendation == 'ACELERAR')
        .take(2);
    for (final s in topProjects) {
      recs.add(PriorityRecommendation(
        title: s.recommendation == 'ESCALAR'
            ? l10n.ecoRecScaleTitle(s.project.name)
            : l10n.ecoRecInvestTitle(s.project.name),
        reason:
            l10n.ecoRecTopReason(s.ecosystemScore),
        dataUsed:
            l10n.ecoRecTopData(s.opportunityScore, s.strategicFit, s.marketScore),
        expectedImpact:
            l10n.ecoRecTopImpact(s.labItemCount),
        confidence: _confidence(s.ecosystemScore),
        type:       RecommendationType.investProject,
        entityId:   s.project.id,
        entityName: s.project.name,
      ));
    }

    // Projects needing validation
    for (final s in scores.where((s) => s.recommendation == 'VALIDAR').take(1)) {
      recs.add(PriorityRecommendation(
        title:          l10n.ecoRecValidateTitle(s.project.name),
        reason:         l10n.ecoRecValidateReason(s.ecosystemScore),
        dataUsed:       l10n.ecoRecValidateData(s.marketScore, s.roiScore, s.executionScore),
        expectedImpact: l10n.ecoRecValidateImpact,
        confidence:     _confidence(s.ecosystemScore),
        type:           RecommendationType.investProject,
        entityId:       s.project.id,
        entityName:     s.project.name,
      ));
    }

    // TOP opportunities
    final topLab = List<OpportunityLabItem>.from(labItems)
      ..sort((a, b) => b.finalScore.compareTo(a.finalScore));
    for (final item in topLab.take(3)) {
      recs.add(PriorityRecommendation(
        title:          l10n.ecoRecOppTitle(item.title),
        reason:         l10n.ecoRecOppReason(item.finalScore),
        dataUsed:       l10n.ecoRecOppData(item.marketScore, item.revenueScore),
        expectedImpact: item.description.isNotEmpty
            ? item.description
            : l10n.ecoRecOppImpactFallback,
        confidence: _confidence(item.finalScore),
        type:       RecommendationType.executeOpportunity,
        entityId:   item.id,
        entityName: item.title,
      ));
    }

    // Quick win actions (high impact, low effort)
    final quickActions = actions
        .where((a) => a.status == 'pending' && a.impactScore >= 70 && a.effortScore <= 40)
        .toList()
      ..sort((a, b) =>
          (b.impactScore - b.effortScore).compareTo(a.impactScore - a.effortScore));
    for (final a in quickActions.take(2)) {
      recs.add(PriorityRecommendation(
        title:
            l10n.ecoRecQuickWinTitle(a.title),
        reason:
            l10n.ecoRecQuickWinReason(a.impactScore, a.effortScore),
        dataUsed:       l10n.ecoRecQuickWinData(a.impactScore, a.effortScore),
        expectedImpact: l10n.ecoRecQuickWinImpact,
        confidence:     85,
        type:           RecommendationType.quickWin,
        entityId:       a.id,
        entityName:     a.title,
      ));
    }

    // Projects to pause (only real PAUSAR, not incomplete data)
    for (final s in scores
        .where((s) => s.recommendation == 'PAUSAR' && s.hasEnoughData)
        .take(2)) {
      recs.add(PriorityRecommendation(
        title:
            l10n.ecoRecPauseTitle(s.project.name),
        reason:
            l10n.ecoRecPauseReason(s.ecosystemScore),
        dataUsed:
            l10n.ecoRecPauseData(s.roiScore, s.momentumScore, s.actionCount),
        expectedImpact:
            l10n.ecoRecPauseImpact,
        confidence: _confidence(100 - s.ecosystemScore),
        type:       RecommendationType.pauseProject,
        entityId:   s.project.id,
        entityName: s.project.name,
      ));
    }

    // Risks
    for (final s in scores.take(3)) {
      for (final risk in s.risks.take(1)) {
        recs.add(PriorityRecommendation(
          title:          l10n.ecoRecRiskTitle(s.project.name, risk),
          reason:         l10n.ecoRecRiskReason,
          dataUsed:
              l10n.ecoRecRiskData(s.ecosystemScore, s.momentumScore),
          expectedImpact: l10n.ecoRecRiskImpact,
          confidence:     70,
          type:           RecommendationType.mitigateRisk,
          entityId:       s.project.id,
          entityName:     s.project.name,
        ));
      }
    }

    return recs;
  }

  ResourceAllocation allocateResources({
    required List<EcosystemScore> scores,
    required double budget,
    required String budgetType,
  }) {
    // Exclude ANÁLISE INCOMPLETA from allocation
    final eligible =
        scores.where((s) => s.ecosystemScore >= 20 && s.hasEnoughData).toList();
    if (eligible.isEmpty) {
      return ResourceAllocation(
        totalBudget: budget,
        budgetType:  budgetType,
        items:       [],
        summary:     _l10n.ecoAllocEmptySummary,
      );
    }

    final totalScore = eligible.fold(0, (s, e) => s + e.ecosystemScore);
    final items = eligible.map((s) {
      final pct   = s.ecosystemScore / totalScore;
      final alloc = budget * pct;
      return AllocationItem(
        score:       s,
        allocation:  double.parse(
            alloc.toStringAsFixed(budgetType == 'hours' ? 1 : 0)),
        percentage:  (pct * 100).roundToDouble(),
        reason:      _allocationReason(s, budgetType),
        expectedRoiScore: math.min(100, s.roiScore + 10),
      );
    }).toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final top   = items.first;
    final label = budgetType == 'hours' ? _l10n.ecoAllocUnitHours : 'R\$';
    return ResourceAllocation(
      totalBudget: budget,
      budgetType:  budgetType,
      items:       items,
      summary:     _l10n.ecoAllocSummary(
        top.score.project.name,
        top.allocation.toStringAsFixed(budgetType == 'hours' ? 1 : 0),
        label,
        top.percentage.round(),
        top.score.ecosystemScore,
      ),
    );
  }

  WeeklyBriefing generateBriefing({
    required List<EcosystemScore> scores,
    required List<MarketAnalysis> analyses,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<RoiMetric> roiMetrics,
  }) {
    final now    = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7));

    final newAnalyses = analyses.where((a) => a.createdAt.isAfter(cutoff)).length;
    final newActions  = actions.where((a) => a.createdAt.isAfter(cutoff)).length;
    final newLab      = labItems.where((l) => l.createdAt.isAfter(cutoff)).length;
    final newRoi      = roiMetrics.where((r) => r.createdAt.isAfter(cutoff)).length;

    // Phase 10I recommendation values
    final growing  = scores.where((s) =>
        s.recommendation == 'ESCALAR' || s.recommendation == 'ACELERAR').toList();
    final pausing  = scores.where((s) => s.recommendation == 'PAUSAR').toList();
    final health   = scores.isEmpty
        ? 0
        : scores.fold(0, (s, e) => s + e.ecosystemScore) ~/ scores.length;

    final l10n = _l10n;
    final changed = <BriefingItem>[];
    if (newAnalyses > 0) changed.add(BriefingItem(
        title: l10n.ecoBriefNewAnalysesTitle(newAnalyses),
        detail: l10n.ecoBriefNewAnalysesDetail,
        impact: 70));
    if (newActions > 0) changed.add(BriefingItem(
        title: l10n.ecoBriefNewActionsTitle(newActions),
        detail: l10n.ecoBriefNewActionsDetail,
        impact: 60));
    if (newLab > 0) changed.add(BriefingItem(
        title: l10n.ecoBriefNewLabTitle(newLab),
        detail: l10n.ecoBriefNewLabDetail,
        impact: 65));
    if (newRoi > 0) changed.add(BriefingItem(
        title: l10n.ecoBriefNewRoiTitle(newRoi),
        detail: l10n.ecoBriefNewRoiDetail,
        impact: 80));
    if (changed.isEmpty) changed.add(BriefingItem(
        title: l10n.ecoBriefNoActivityTitle,
        detail: l10n.ecoBriefNoActivityDetail,
        impact: 0));

    final grew = growing.map((s) => BriefingItem(
      title:  l10n.ecoBriefProjectScoreTitle(s.project.name, s.ecosystemScore),
      detail: l10n.ecoBriefRecommendationDetail(
        ecosystemVerdictLabel(s.recommendation, l10n),
        s.strengths.isNotEmpty ? s.strengths.first : l10n.ecoBriefGrewFallback,
      ),
      impact: s.ecosystemScore,
    )).toList();

    final declined = pausing.map((s) => BriefingItem(
      title:  l10n.ecoBriefProjectScoreTitle(s.project.name, s.ecosystemScore),
      detail: l10n.ecoBriefRecommendationDetail(
        ecosystemVerdictLabel('PAUSAR', l10n),
        s.risks.isNotEmpty ? s.risks.first : l10n.ecoBriefDeclinedFallback,
      ),
      impact: s.ecosystemScore,
    )).toList();

    final priorityCandidates = scores
        .where((s) => s.recommendation != 'PAUSAR')
        .take(3)
        .toList();
    final priorities = (priorityCandidates.isNotEmpty
            ? priorityCandidates
            : scores.take(3).toList())
        .map((s) => BriefingItem(
              title:  s.project.name,
              detail: '${s.recommendationEmoji} '
                  '${ecosystemVerdictLabel(s.recommendation, l10n)} — Score ${s.ecosystemScore}/100',
              impact: s.ecosystemScore,
            ))
        .toList();

    final toPause = pausing.map((s) => BriefingItem(
      title:  s.project.name,
      detail: l10n.ecoBriefToPauseDetail(s.ecosystemScore),
      impact: s.ecosystemScore,
    )).toList();

    final newOpps = labItems.where((l) => l.createdAt.isAfter(cutoff)).take(5).map((l) =>
        BriefingItem(
          title:  l.title,
          detail: 'Score ${l.finalScore}/100 — ${l.opportunityType}',
          impact: l.finalScore,
        )).toList();

    final allRisks = scores
        .expand((s) => s.risks.map((r) => BriefingItem(
              title:  r,
              detail: l10n.ecoBriefRiskProjectDetail(s.project.name),
              impact: 100 - s.ecosystemScore,
            )))
        .take(5)
        .toList();

    final summary = scores.isEmpty
        ? l10n.ecoBriefSummaryEmpty
        : l10n.ecoBriefSummary(scores.length, health, growing.length, pausing.length);

    return WeeklyBriefing(
      generatedAt:          now,
      overallHealthScore:   health,
      whatChanged:          changed,
      whatGrew:             grew,
      whatDeclined:         declined,
      topPriorities:        priorities,
      toPause:              toPause,
      newOpportunities:     newOpps,
      risks:                allRisks,
      executiveSummary:     summary,
      analyzedProjectNames: scores.map((s) => s.project.name).toList(),
      projectCount:         scores.length,
      analysisCount:        analyses.length,
      actionsCount:         actions.length,
      opportunitiesCount:   labItems.length,
    );
  }

  // ── Phase 10I — New Score Engines ─────────────────────────────────────────

  // Market Score: composite from analysis sub-scores or opportunity lab data
  int _marketScore(MarketAnalysis? analysis, List<OpportunityLabItem> lab) {
    if (analysis != null) {
      final compAdv = (100 - analysis.scoreCompetition).clamp(0, 100);
      return (analysis.scoreGrowth * 0.30 +
              analysis.scoreMonetization * 0.25 +
              compAdv * 0.20 +
              analysis.scoreSeo * 0.10 +
              analysis.opportunityScore * 0.15)
          .round()
          .clamp(0, 100);
    }
    if (lab.isNotEmpty) {
      final avgMarket  = lab.map((l) => l.marketScore).fold(0, (a, b) => a + b) / lab.length;
      final avgRevenue = lab.map((l) => l.revenueScore).fold(0, (a, b) => a + b) / lab.length;
      final avgFit     = lab.map((l) => l.strategicFit).fold(0, (a, b) => a + b) / lab.length;
      return (avgMarket * 0.45 + avgRevenue * 0.30 + avgFit * 0.25)
          .round()
          .clamp(0, 100);
    }
    return 0;
  }

  // Execution Score: completion rate, approved opportunities, roadmap presence
  ExecutionScore _computeExecutionScore(
    List<ActionQueueItem> actions,
    List<OpportunityLabItem> lab,
    bool hasRoadmap,
  ) {
    final projectId  = actions.isNotEmpty ? (actions.first.projectId ?? '') : '';
    final completed  = actions.where((a) => a.status == 'completed').length;
    final approved   = lab.where((l) => l.status == 'approved').length;

    if (actions.isEmpty && lab.isEmpty) {
      return ExecutionScore(
        projectId:             projectId,
        score:                 hasRoadmap ? 20 : 0,
        completedActions:      0,
        totalActions:          0,
        approvedOpportunities: 0,
        totalOpportunities:    0,
        hasRoadmap:            hasRoadmap,
        explanation:           [
          _l10n.ecoExecNoActions,
          if (hasRoadmap) _l10n.ecoExecRoadmapPresent,
        ],
      );
    }

    final compRate = actions.isEmpty ? 0.0 : completed / actions.length;
    final compPts  = (compRate * 50).round();             // max 50
    final appPts   = math.min(30, approved * 10);         // max 30
    final roadPts  = hasRoadmap ? 20 : 0;                 // 20 pts

    final score = (compPts + appPts + roadPts).clamp(0, 100);

    return ExecutionScore(
      projectId:             projectId,
      score:                 score,
      completedActions:      completed,
      totalActions:          actions.length,
      approvedOpportunities: approved,
      totalOpportunities:    lab.length,
      hasRoadmap:            hasRoadmap,
      explanation:           [
        _l10n.ecoExecCompleted(completed, actions.length, compPts),
        _l10n.ecoExecApproved(approved, appPts),
        hasRoadmap ? _l10n.ecoExecRoadmapPresent : _l10n.ecoExecNoRoadmap,
      ],
    );
  }

  // Opportunity Score: use lab items when no analysis is linked
  int _opportunityScore(
      Project p, MarketAnalysis? analysis, List<OpportunityLabItem> lab) {
    if (analysis != null) return analysis.opportunityScore;
    // Phase 10I fix: derive from opportunity lab final scores
    if (lab.isNotEmpty) {
      final avg = lab.map((l) => l.finalScore).fold(0, (a, b) => a + b) / lab.length;
      // Weight by synergy: more items = higher confidence
      final bonus = math.min(10, lab.length * 2);
      return (avg + bonus).round().clamp(0, 100);
    }
    // Last resort: derive from project fields
    final revScore = math.min(50, (p.revenuePotential / 2000)).round();
    final priScore = (p.priorityScore * 0.30).round();
    final timeBns  = p.timeToRevenueDays > 0 && p.timeToRevenueDays <= 90 ? 10 : 0;
    return (revScore + priScore + timeBns).clamp(0, 100);
  }

  // Strategic Fit 2.0: marketScore×0.35 + priorityScore×0.20 + roiScore×0.25 + executionScore×0.20
  int _strategicFit(int market, int roi, int execution, Project p) {
    final mkt  = market * 0.35;
    final pri  = math.min(100, p.priorityScore) * 0.20;
    final roiP = roi * 0.25;
    final exec = execution * 0.20;
    return (mkt + pri + roiP + exec).round().clamp(0, 100);
  }

  int _synergyScore(Project p, MarketAnalysis? a,
      List<OpportunityLabItem> lab, List<ActionQueueItem> actions) {
    int score = 0;
    if (a != null) score += 25;
    score += math.min(30, lab.length * 8);
    final approved = lab.where((l) => l.status == 'approved').length;
    score += math.min(20, approved * 10);
    score += math.min(15, actions.length * 3);
    return score.clamp(0, 100);
  }

  int _roiScore(List<RoiMetric> roi, RevenuePlan? plan) {
    if (roi.isNotEmpty) {
      final total = roi.fold(0.0, (s, r) => s + r.metricValue);
      return math.min(100, (total / 2000 * 100).round());
    }
    if (plan != null && plan.monthlyModerate > 0) {
      // R$10k/mês = 100pts; R$5k = 50pts
      return math.min(100, (plan.monthlyModerate / 100).round());
    }
    return 0;
  }

  int _momentumScore(
      List<ActionQueueItem> actions, List<OpportunityLabItem> lab, DateTime cutoff) {
    final baseline  = (actions.isNotEmpty || lab.isNotEmpty) ? 15 : 0;
    final recentA   = actions.where((a) => a.createdAt.isAfter(cutoff)).length;
    final recentL   = lab.where((l) => l.createdAt.isAfter(cutoff)).length;
    final completed = actions.where((a) => a.status == 'completed').length;
    return math.min(100, baseline + recentA * 12 + recentL * 8 + completed * 5);
  }

  int _weighted(int opp, int fit, int syn, int roi, int mom) =>
      (opp * 0.25 + fit * 0.25 + syn * 0.20 + roi * 0.20 + mom * 0.10)
          .round()
          .clamp(0, 100);

  // Phase 10I Decision Engine 2.0
  bool _hasEnoughData(MarketAnalysis? analysis, RevenuePlan? plan,
      List<ActionQueueItem> actions, List<OpportunityLabItem> lab) =>
      analysis != null || plan != null || lab.isNotEmpty || actions.isNotEmpty;

  String _recommend(int score, bool hasEnoughData) {
    if (!hasEnoughData) return 'ANÁLISE INCOMPLETA';
    if (score >= 80) return 'ESCALAR';
    if (score >= 60) return 'ACELERAR';
    if (score >= 40) return 'MANTER';
    if (score >= 20) return 'VALIDAR';
    return 'PAUSAR';
  }

  // ── Scoring Helpers ───────────────────────────────────────────────────────

  MarketAnalysis? _findAnalysisMatch(Project p, List<MarketAnalysis> analyses) {
    if (analyses.isEmpty) return null;

    // 1. FK direto: analysis.project_id == project.id (mais confiável)
    for (final a in analyses) {
      if (a.projectId == p.id) return a;
    }

    // 2. FK inverso legado: project.market_analysis_id aponta para a análise
    if (p.marketAnalysisId != null) {
      for (final a in analyses) {
        if (a.id == p.marketAnalysisId) return a;
      }
    }

    // 3. Normalização de URL como último recurso (dados antigos sem FK)
    if (p.url != null && p.url!.isNotEmpty) {
      final pUrl = _normalizeUrl(p.url!);
      for (final a in analyses) {
        if (_normalizeUrl(a.input) == pUrl) return a;
      }
    }

    // Matching por substring de nome REMOVIDO — gerava falsos positivos
    return null;
  }

  RevenuePlan? _findRevenuePlan(
      Project p, MarketAnalysis? a, List<RevenuePlan> plans) {
    if (plans.isEmpty) return null;

    // 1. FK direto: plan.project_id == project.id (mais confiável)
    for (final r in plans) {
      if (r.projectId == p.id) return r;
    }

    // 2. Via project.market_analysis_id
    if (p.marketAnalysisId != null) {
      for (final r in plans) {
        if (r.marketAnalysisId == p.marketAnalysisId) return r;
      }
    }

    // 3. Via análise vinculada
    if (a != null) {
      for (final r in plans) {
        if (r.marketAnalysisId == a.id) return r;
      }
    }

    // Matching por projectName REMOVIDO — quebrava em renomeações e colisões
    return null;
  }

  bool _projectHasRoadmap(Project p) {
    final roadmap = p.detailsJson['roadmap'];
    if (roadmap == null) return false;
    if (roadmap is Map) {
      final items = [
        ...((roadmap['short_term']  as List?) ?? []),
        ...((roadmap['medium_term'] as List?) ?? []),
        ...((roadmap['long_term']   as List?) ?? []),
      ];
      return items.isNotEmpty;
    }
    return false;
  }

  String _normalizeUrl(String url) => url
      .toLowerCase()
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'^www\.'), '')
      .replaceAll(RegExp(r'/$'), '')
      .split('?').first;

  int _confidence(int score) => score.clamp(20, 90);

  List<String> _strengths(Project p, MarketAnalysis? a, int roi, int synergy,
      int momentum, int market) {
    final l10n = _l10n;
    final s = <String>[];
    if (market >= 60)   s.add(l10n.ecoStrengthMarket);
    if ((a?.opportunityScore ?? p.opportunityScore) >= 70)
      s.add(l10n.ecoStrengthOpportunity);
    if (roi >= 50)      s.add(l10n.ecoStrengthRoi);
    if (synergy >= 50)  s.add(l10n.ecoStrengthSynergy);
    if (momentum >= 40) s.add(l10n.ecoStrengthMomentum);
    if (p.priorityScore >= 70) s.add(l10n.ecoStrengthPriority);
    if (s.isEmpty) s.add(l10n.ecoStrengthDefault);
    return s;
  }

  List<String> _risks(Project p, List<ActionQueueItem> actions, int roi,
      int momentum, bool hasEnoughData) {
    final l10n = _l10n;
    final r = <String>[];
    if (!hasEnoughData) r.add(l10n.ecoRiskInsufficientData);
    final pending = actions.where((a) => a.status == 'pending').length;
    if (pending > 5) r.add(l10n.ecoRiskPendingActions(pending));
    if (roi == 0 && actions.isNotEmpty)
      r.add(l10n.ecoRiskNoRoi);
    if (momentum < 10 && actions.isNotEmpty)
      r.add(l10n.ecoRiskLowActivity);
    if (p.status == 'idea') r.add(l10n.ecoRiskIdeaStage);
    return r;
  }

  List<String> _quickWins(List<ActionQueueItem> actions) =>
      actions
          .where((a) => a.status == 'pending' && a.impactScore >= 70 && a.effortScore <= 40)
          .map((a) => a.title)
          .take(3)
          .toList();

  String _allocationReason(EcosystemScore s, String type) {
    final label = type == 'hours' ? _l10n.ecoAllocUnitHours : _l10n.ecoAllocResourceBudget;
    if (s.recommendation == 'ESCALAR')   return _l10n.ecoAllocReasonScale(label);
    if (s.recommendation == 'ACELERAR')  return _l10n.ecoAllocReasonAccelerate(label);
    if (s.recommendation == 'MANTER')    return _l10n.ecoAllocReasonMaintain;
    if (s.recommendation == 'VALIDAR')   return _l10n.ecoAllocReasonValidate;
    return _l10n.ecoAllocReasonPause;
  }
}
