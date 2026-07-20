import 'dart:math' as math;

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

      final marketPts  = _marketScore(analysis, pLab);
      final execPts    = _computeExecutionScore(pActions, pLab, hasRoadmap);
      final oppScore   = _opportunityScore(p, analysis, pLab);
      final hasRoiData = pRoi.isNotEmpty ||
          (plan != null && plan.monthlyModerate > 0);
      final roi        = _roiScore(pRoi, plan);
      final strategic  = _strategicFit(marketPts, roi, execPts.score, p);
      final synergy    = _synergyScore(p, analysis, pLab, pActions);
      final momentum   = _momentumScore(pActions, pLab, cutoff);
      final ecosystem  = _weighted(oppScore, strategic, synergy, roi, momentum);

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
        hasRoiData:       hasRoiData,
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
    final recs = <PriorityRecommendation>[];

    // TOP projects to scale or accelerate
    final topProjects = scores
        .where((s) => s.recommendation == 'ESCALAR' || s.recommendation == 'ACELERAR')
        .take(2);
    for (final s in topProjects) {
      recs.add(PriorityRecommendation(
        title:
            '${s.recommendation == "ESCALAR" ? "Escale" : "Invista mais em"} "${s.project.name}"',
        reason:
            'Ecosystem Score ${s.ecosystemScore}/100 — maior potencial do seu portfólio',
        dataUsed:
            'Score: oportunidade ${s.opportunityScore}, fit ${s.strategicFit}, mercado ${s.marketScore}',
        expectedImpact:
            'Aceleração de receita e execução de ${s.labItemCount} oportunidades mapeadas',
        confidence: _confidence(s.ecosystemScore),
        type:       RecommendationType.investProject,
        entityId:   s.project.id,
        entityName: s.project.name,
      ));
    }

    // Projects needing validation
    for (final s in scores.where((s) => s.recommendation == 'VALIDAR').take(1)) {
      recs.add(PriorityRecommendation(
        title:          'Valide as premissas de "${s.project.name}"',
        reason:         'Score ${s.ecosystemScore}/100 — potencial presente mas dados ainda insuficientes para decisão',
        dataUsed:       'Market score ${s.marketScore}, ROI ${s.roiScore}, execução ${s.executionScore}',
        expectedImpact: 'Clareza estratégica para escalar ou pivotar',
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
        title:          'Execute a oportunidade "${item.title}"',
        reason:         'Score final ${item.finalScore}/100 — maior ROI esperado do Lab',
        dataUsed:       'Market score ${item.marketScore}, revenue score ${item.revenueScore}',
        expectedImpact: item.description.isNotEmpty
            ? item.description
            : 'Alta alavancagem do portfólio',
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
            'Ganho rápido: "${a.title}"',
        reason:
            'Impacto ${a.impactScore} com esforço apenas ${a.effortScore} — melhor relação do portfólio',
        dataUsed:       'Impact score ${a.impactScore}, effort score ${a.effortScore}',
        expectedImpact: 'Execução rápida com alto retorno proporcional',
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
            'Pause ou revise "${s.project.name}"',
        reason:
            'Ecosystem Score ${s.ecosystemScore}/100 — recursos consumidos sem retorno visível',
        dataUsed:
            'ROI score ${s.roiScore}, momentum ${s.momentumScore}, ${s.actionCount} ações sem conclusão',
        expectedImpact:
            'Liberação de tempo e foco para projetos de maior potencial',
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
          title:          'Risco em "${s.project.name}": $risk',
          reason:         'Identificado pelo Ecosystem Intelligence com base nos dados do projeto',
          dataUsed:
              'Ecosystem Score ${s.ecosystemScore}, momentum ${s.momentumScore}',
          expectedImpact: 'Mitigação preventiva antes do impacto no portfólio',
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
        summary:
            'Nenhum projeto com score suficiente para alocação. '
            'Execute o Knowledge → Action Engine para gerar inteligência operacional.',
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
    final label = budgetType == 'hours' ? 'horas' : 'R\$';
    return ResourceAllocation(
      totalBudget: budget,
      budgetType:  budgetType,
      items:       items,
      summary:
          'Priorize "${top.score.project.name}" com '
          '${top.allocation.toStringAsFixed(budgetType == 'hours' ? 1 : 0)} $label '
          '(${top.percentage.round()}% do orçamento). Score: ${top.score.ecosystemScore}/100.',
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

    final changed = <BriefingItem>[];
    if (newAnalyses > 0) changed.add(BriefingItem(
        title: '$newAnalyses nova(s) análise(s) de mercado',
        detail: 'Novas oportunidades mapeadas pelo Market Intelligence',
        impact: 70));
    if (newActions > 0) changed.add(BriefingItem(
        title: '$newActions nova(s) ação(ões) criada(s)',
        detail: 'Action Engine em movimento',
        impact: 60));
    if (newLab > 0) changed.add(BriefingItem(
        title: '$newLab novo(s) item(ns) no Opportunity Lab',
        detail: 'Oportunidades sendo avaliadas',
        impact: 65));
    if (newRoi > 0) changed.add(BriefingItem(
        title: '$newRoi novo(s) registro(s) de ROI',
        detail: 'Resultados financeiros atualizados',
        impact: 80));
    if (changed.isEmpty) changed.add(BriefingItem(
        title: 'Nenhuma atividade nova esta semana',
        detail: 'Adicione análises ou ações para gerar insights',
        impact: 0));

    final grew = growing.map((s) => BriefingItem(
      title:  '${s.project.name} — Ecosystem Score ${s.ecosystemScore}',
      detail: 'Recomendação: ${s.recommendation}. '
              '${s.strengths.isNotEmpty ? s.strengths.first : "Alto potencial identificado."}',
      impact: s.ecosystemScore,
    )).toList();

    final declined = pausing.map((s) => BriefingItem(
      title:  '${s.project.name} — Ecosystem Score ${s.ecosystemScore}',
      detail: 'Recomendação: PAUSAR. '
              '${s.risks.isNotEmpty ? s.risks.first : "Baixo retorno identificado."}',
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
              detail: '${s.recommendationEmoji} ${s.recommendation} — Score ${s.ecosystemScore}/100',
              impact: s.ecosystemScore,
            ))
        .toList();

    final toPause = pausing.map((s) => BriefingItem(
      title:  s.project.name,
      detail: 'Score ${s.ecosystemScore}/100 — libere recursos para projetos de maior potencial',
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
              detail: 'Projeto: ${s.project.name}',
              impact: 100 - s.ecosystemScore,
            )))
        .take(5)
        .toList();

    final summary = scores.isEmpty
        ? 'Nenhum projeto registrado. Comece adicionando projetos e executando análises.'
        : 'Seu ecossistema tem ${scores.length} projeto(s) com saúde geral de $health/100. '
          '${growing.length} projeto(s) em crescimento, ${pausing.length} requerem revisão.';

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
          'Sem ações cadastradas',
          if (hasRoadmap) 'Roadmap presente → +20pts',
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
        '$completed/${actions.length} ações concluídas → ${compPts}pts',
        '$approved oportunidades aprovadas × 10 = ${appPts}pts (max 30)',
        hasRoadmap ? 'Roadmap presente → +20pts' : 'Sem roadmap → +0pts',
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
    final s = <String>[];
    if (market >= 60)   s.add('Mercado com alto potencial identificado');
    if ((a?.opportunityScore ?? p.opportunityScore) >= 70)
      s.add('Alta pontuação de oportunidade de mercado');
    if (roi >= 50)      s.add('ROI positivo registrado');
    if (synergy >= 50)  s.add('Alta sinergia com o ecossistema');
    if (momentum >= 40) s.add('Atividade recente elevada');
    if (p.priorityScore >= 70) s.add('Alta prioridade estratégica');
    if (s.isEmpty) s.add('Projeto com potencial a desenvolver');
    return s;
  }

  List<String> _risks(Project p, List<ActionQueueItem> actions, int roi,
      int momentum, bool hasEnoughData) {
    final r = <String>[];
    if (!hasEnoughData) r.add('Dados insuficientes para análise de valor');
    final pending = actions.where((a) => a.status == 'pending').length;
    if (pending > 5) r.add('$pending ações pendentes acumuladas sem execução');
    if (roi == 0 && actions.isNotEmpty)
      r.add('Sem ROI registrado apesar das ações em andamento');
    if (momentum < 10 && actions.isNotEmpty)
      r.add('Baixa atividade nos últimos 30 dias');
    if (p.status == 'idea') r.add('Projeto ainda em fase de ideia — sem execução iniciada');
    return r;
  }

  List<String> _quickWins(List<ActionQueueItem> actions) =>
      actions
          .where((a) => a.status == 'pending' && a.impactScore >= 70 && a.effortScore <= 40)
          .map((a) => a.title)
          .take(3)
          .toList();

  String _allocationReason(EcosystemScore s, String type) {
    final label = type == 'hours' ? 'horas' : 'budget';
    if (s.recommendation == 'ESCALAR')   return 'Maior potencial — escale o investimento em $label';
    if (s.recommendation == 'ACELERAR')  return 'Alto potencial — maximize o $label aqui';
    if (s.recommendation == 'MANTER')    return 'Projeto saudável — mantenha investimento consistente';
    if (s.recommendation == 'VALIDAR')   return 'Alocação reduzida até validar premissas';
    return 'Não recomendado — considere pausar este projeto';
  }
}
