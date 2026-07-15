import 'dart:math' as math;

import '../models/action_queue_item.dart';
import '../models/ecosystem_score.dart';
import '../models/market_analysis.dart';
import '../models/opportunity_lab_item.dart';
import '../models/priority_recommendation.dart';
import '../models/project.dart';
import '../models/resource_allocation.dart';
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
      final analysis = _findAnalysisMatch(p, analyses);
      final plan     = _findRevenuePlan(p, analysis, revenuePlans);
      final pActions = actions.where((a) => a.projectId == p.id).toList();
      final pLab     = labItems.where((l) => l.projectId == p.id).toList();
      final pRoi     = roiMetrics.where((r) => r.projectId == p.id).toList();

      // Use analysis score when available; derive from project fields when not
      final oppScore  = analysis?.opportunityScore ?? _deriveOppScore(p);
      final strategic = _strategicFit(p, analysis, pActions, pRoi);
      final synergy   = _synergyScore(p, analysis, pLab, pActions);
      final roi       = _roiScore(pRoi, plan);
      final momentum  = _momentumScore(pActions, pLab, cutoff);
      final ecosystem = _weighted(oppScore, strategic, synergy, roi, momentum);
      final rec       = _recommend(ecosystem);
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
        strengths:        _strengths(p, analysis, roi, synergy, momentum),
        risks:            _risks(p, pActions, roi, momentum),
        quickWins:        _quickWins(pActions),
        totalRoi:         totalRoi,
        actionCount:      pActions.length,
        completedActions: completed,
        labItemCount:     pLab.length,
      );
    }).toList()
      ..sort((a, b) => b.ecosystemScore.compareTo(a.ecosystemScore));
  }

  List<PriorityRecommendation> generateRecommendations({
    required List<EcosystemScore> scores,
    required List<OpportunityLabItem> labItems,
    required List<ActionQueueItem> actions,
  }) {
    final recs = <PriorityRecommendation>[];

    // TOP projects to invest
    for (final s in scores.where((s) => s.recommendation == 'ACELERAR').take(2)) {
      recs.add(PriorityRecommendation(
        title:          'Invista mais tempo em "${s.project.name}"',
        reason:         'Ecosystem Score ${s.ecosystemScore}/100 — maior potencial do seu portfólio',
        dataUsed:       'Score: oportunidade ${s.opportunityScore}, fit ${s.strategicFit}, sinergia ${s.synergyScore}',
        expectedImpact: 'Aceleração de receita e execução de ${s.labItemCount} oportunidades mapeadas',
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
        expectedImpact: item.description.isNotEmpty ? item.description : 'Alta alavancagem do portfólio',
        confidence:     _confidence(item.finalScore),
        type:           RecommendationType.executeOpportunity,
        entityId:       item.id,
        entityName:     item.title,
      ));
    }

    // Quick win actions (high impact, low effort)
    final quickActions = actions
        .where((a) => a.status == 'pending' && a.impactScore >= 70 && a.effortScore <= 40)
        .toList()
      ..sort((a, b) => (b.impactScore - b.effortScore).compareTo(a.impactScore - a.effortScore));
    for (final a in quickActions.take(2)) {
      recs.add(PriorityRecommendation(
        title:          'Ganho rápido: "${a.title}"',
        reason:         'Impacto ${a.impactScore} com esforço apenas ${a.effortScore} — melhor relação do portfólio',
        dataUsed:       'Impact score ${a.impactScore}, effort score ${a.effortScore}',
        expectedImpact: 'Execução rápida com alto retorno proporcional',
        confidence:     85,
        type:           RecommendationType.quickWin,
        entityId:       a.id,
        entityName:     a.title,
      ));
    }

    // Projects to pause
    for (final s in scores.where((s) => s.recommendation == 'PAUSAR').take(2)) {
      recs.add(PriorityRecommendation(
        title:          'Pause ou revise "${s.project.name}"',
        reason:         'Ecosystem Score ${s.ecosystemScore}/100 — recursos consumidos sem retorno visível',
        dataUsed:       'ROI score ${s.roiScore}, momentum ${s.momentumScore}, ${s.actionCount} ações sem conclusão',
        expectedImpact: 'Liberação de tempo e foco para projetos de maior potencial',
        confidence:     _confidence(100 - s.ecosystemScore),
        type:           RecommendationType.pauseProject,
        entityId:       s.project.id,
        entityName:     s.project.name,
      ));
    }

    // Risks
    for (final s in scores.take(3)) {
      for (final risk in s.risks.take(1)) {
        recs.add(PriorityRecommendation(
          title:          'Risco em "${s.project.name}": $risk',
          reason:         'Identificado pelo Ecosystem Intelligence com base nos dados do projeto',
          dataUsed:       'Ecosystem Score ${s.ecosystemScore}, momentum ${s.momentumScore}',
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
    final eligible = scores.where((s) => s.ecosystemScore >= 20).toList();
    if (eligible.isEmpty) {
      return ResourceAllocation(
        totalBudget: budget,
        budgetType:  budgetType,
        items:       [],
        summary:     'Nenhum projeto com score suficiente para alocação. Adicione projetos e análises.',
      );
    }

    final totalScore = eligible.fold(0, (s, e) => s + e.ecosystemScore);
    final items = eligible.map((s) {
      final pct   = s.ecosystemScore / totalScore;
      final alloc = budget * pct;
      return AllocationItem(
        score:            s,
        allocation:       double.parse(alloc.toStringAsFixed(budgetType == 'hours' ? 1 : 0)),
        percentage:       (pct * 100).roundToDouble(),
        reason:           _allocationReason(s, budgetType),
        expectedRoiScore: math.min(100, s.roiScore + 10),
      );
    }).toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final top = items.first;
    final label = budgetType == 'hours' ? 'horas' : 'R\$';
    return ResourceAllocation(
      totalBudget: budget,
      budgetType:  budgetType,
      items:       items,
      summary:     'Priorize "${top.score.project.name}" com ${top.allocation.toStringAsFixed(budgetType == 'hours' ? 1 : 0)} $label '
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
    final now     = DateTime.now();
    final cutoff  = now.subtract(const Duration(days: 7));

    final newAnalyses = analyses.where((a) => a.createdAt.isAfter(cutoff)).length;
    final newActions  = actions.where((a) => a.createdAt.isAfter(cutoff)).length;
    final newLab      = labItems.where((l) => l.createdAt.isAfter(cutoff)).length;
    final newRoi      = roiMetrics.where((r) => r.createdAt.isAfter(cutoff)).length;

    final accelerating = scores.where((s) => s.recommendation == 'ACELERAR').toList();
    final pausing      = scores.where((s) => s.recommendation == 'PAUSAR').toList();
    final health       = scores.isEmpty ? 0
        : scores.fold(0, (s, e) => s + e.ecosystemScore) ~/ scores.length;

    final changed = <BriefingItem>[];
    if (newAnalyses > 0) changed.add(BriefingItem(title: '$newAnalyses nova(s) análise(s) de mercado', detail: 'Novas oportunidades mapeadas pelo Market Intelligence', impact: 70));
    if (newActions > 0)  changed.add(BriefingItem(title: '$newActions nova(s) ação(ões) criada(s)', detail: 'Action Engine em movimento', impact: 60));
    if (newLab > 0)      changed.add(BriefingItem(title: '$newLab novo(s) item(ns) no Opportunity Lab', detail: 'Oportunidades sendo avaliadas', impact: 65));
    if (newRoi > 0)      changed.add(BriefingItem(title: '$newRoi novo(s) registro(s) de ROI', detail: 'Resultados financeiros atualizados', impact: 80));
    if (changed.isEmpty) changed.add(BriefingItem(title: 'Nenhuma atividade nova esta semana', detail: 'Considere adicionar análises ou ações para gerar insights', impact: 0));

    final grew = accelerating.map((s) => BriefingItem(
      title:  '${s.project.name} — Ecosystem Score ${s.ecosystemScore}',
      detail: 'Recomendação: ACELERAR. ${s.strengths.isNotEmpty ? s.strengths.first : "Alto potencial identificado."}',
      impact: s.ecosystemScore,
    )).toList();

    final declined = pausing.map((s) => BriefingItem(
      title:  '${s.project.name} — Ecosystem Score ${s.ecosystemScore}',
      detail: 'Recomendação: PAUSAR. ${s.risks.isNotEmpty ? s.risks.first : "Baixo retorno identificado."}',
      impact: s.ecosystemScore,
    )).toList();

    // Only show non-PAUSAR projects as priorities to avoid contradiction
    final priorityCandidates = scores
        .where((s) => s.recommendation != 'PAUSAR')
        .take(3)
        .toList();
    final priorities = (priorityCandidates.isNotEmpty ? priorityCandidates : scores.take(3))
        .map((s) => BriefingItem(
          title:  s.project.name,
          detail: '${s.recommendationEmoji} ${s.recommendation} — Score ${s.ecosystemScore}/100',
          impact: s.ecosystemScore,
        )).toList();

    final toPause = pausing.map((s) => BriefingItem(
      title:  s.project.name,
      detail: 'Score ${s.ecosystemScore}/100 — libere recursos para projetos de maior potencial',
      impact: s.ecosystemScore,
    )).toList();

    final newOpps = labItems.where((l) => l.createdAt.isAfter(cutoff)).take(5).map((l) => BriefingItem(
      title:  l.title,
      detail: 'Score ${l.finalScore}/100 — ${l.opportunityType}',
      impact: l.finalScore,
    )).toList();

    final allRisks = scores.expand((s) => s.risks.map((r) => BriefingItem(
      title:  r,
      detail: 'Projeto: ${s.project.name}',
      impact: 100 - s.ecosystemScore,
    ))).take(5).toList();

    final summary = scores.isEmpty
        ? 'Nenhum projeto registrado ainda. Comece adicionando projetos e executando análises de mercado.'
        : 'Seu ecossistema tem ${scores.length} projeto(s) com saúde geral de $health/100. '
          '${accelerating.length} projeto(s) em aceleração, ${pausing.length} requerem revisão.';

    return WeeklyBriefing(
      generatedAt:       now,
      overallHealthScore: health,
      whatChanged:       changed,
      whatGrew:          grew,
      whatDeclined:      declined,
      topPriorities:     priorities,
      toPause:           toPause,
      newOpportunities:  newOpps,
      risks:             allRisks,
      executiveSummary:  summary,
    );
  }

  // ── Scoring Helpers ───────────────────────────────────────────────────────

  // 3-strategy analysis lookup: FK → URL → skip
  MarketAnalysis? _findAnalysisMatch(Project p, List<MarketAnalysis> analyses) {
    if (analyses.isEmpty) return null;

    // Strategy 1: direct FK (most reliable)
    if (p.marketAnalysisId != null) {
      final direct = analyses.where((a) => a.id == p.marketAnalysisId).toList();
      if (direct.isNotEmpty) return direct.first;
    }

    // Strategy 2: URL match (analysis.input vs project.url)
    if (p.url != null && p.url!.isNotEmpty) {
      final pUrl = _normalizeUrl(p.url!);
      for (final a in analyses) {
        if (_normalizeUrl(a.input) == pUrl) return a;
      }
    }

    // Strategy 3: project name appears in analysis input/niche (fuzzy)
    final pName = p.name.toLowerCase().trim();
    if (pName.length >= 4) {
      for (final a in analyses) {
        final inputLow = _normalizeUrl(a.input);
        final nicheLow = (a.niche ?? '').toLowerCase();
        if (inputLow.contains(pName) || nicheLow.contains(pName)) return a;
      }
    }

    return null;
  }

  // Derive opportunity score from project's own fields when no analysis exists
  int _deriveOppScore(Project p) {
    final revScore = math.min(50, (p.revenuePotential / 2000)).round();
    final priScore = (p.priorityScore * 0.30).round();
    final timeBonus = p.timeToRevenueDays > 0 && p.timeToRevenueDays <= 90 ? 10 : 0;
    return (revScore + priScore + timeBonus).clamp(0, 100);
  }

  // Revenue plan linked via analysis chain
  RevenuePlan? _findRevenuePlan(Project p, MarketAnalysis? a, List<RevenuePlan> plans) {
    if (plans.isEmpty) return null;
    // Via project's direct FK
    if (p.marketAnalysisId != null) {
      final direct = plans.where((r) => r.marketAnalysisId == p.marketAnalysisId).toList();
      if (direct.isNotEmpty) return direct.first;
    }
    // Via matched analysis
    if (a != null) {
      final linked = plans.where((r) => r.marketAnalysisId == a.id).toList();
      if (linked.isNotEmpty) return linked.first;
    }
    return null;
  }

  String _normalizeUrl(String url) => url
      .toLowerCase()
      .replaceAll(RegExp(r'^https?://'), '')
      .replaceAll(RegExp(r'^www\.'), '')
      .replaceAll(RegExp(r'/$'), '')
      .split('?').first;

  int _strategicFit(Project p, MarketAnalysis? a, List<ActionQueueItem> actions, List<RoiMetric> roi) {
    final market   = (a?.opportunityScore ?? _deriveOppScore(p)) * 0.35;
    final priority = p.priorityScore * 0.20;
    final totalRoi = roi.fold(0.0, (s, r) => s + r.metricValue);
    final roiComp  = math.min(100.0, totalRoi / 2000 * 100) * 0.25;
    final total    = actions.length;
    final done     = actions.where((a) => a.status == 'completed').length;
    // 5.0 baseline for zero-action projects — honest floor, not inflated
    final execComp = total == 0 ? 5.0 : (done / total * 100) * 0.20;
    return (market + priority + roiComp + execComp).round().clamp(0, 100);
  }

  int _synergyScore(Project p, MarketAnalysis? a, List<OpportunityLabItem> lab, List<ActionQueueItem> actions) {
    int score = 0;
    // Analysis link: 25 pts — single condition, no double-count
    if (a != null) score += 25;
    score += math.min(30, lab.length * 8);
    final approved = lab.where((l) => l.status == 'approved').length;
    score += math.min(20, approved * 10);
    score += math.min(15, actions.length * 3);
    return score.clamp(0, 100);
  }

  int _roiScore(List<RoiMetric> roi, RevenuePlan? plan) {
    // Actual recorded ROI takes priority
    if (roi.isNotEmpty) {
      final total = roi.fold(0.0, (s, r) => s + r.metricValue);
      return math.min(100, (total / 2000 * 100).round());
    }
    // Projected ROI from revenue plan (R$5000/month ≈ 50 pts; R$10000 ≈ 100 pts)
    if (plan != null && plan.monthlyModerate > 0) {
      return math.min(100, (plan.monthlyModerate / 100).round());
    }
    return 0;
  }

  int _momentumScore(List<ActionQueueItem> actions, List<OpportunityLabItem> lab, DateTime cutoff) {
    // Baseline: project with any items shows it's being worked on
    final baseline = (actions.isNotEmpty || lab.isNotEmpty) ? 15 : 0;
    final recentA  = actions.where((a) => a.createdAt.isAfter(cutoff)).length;
    final recentL  = lab.where((l) => l.createdAt.isAfter(cutoff)).length;
    final completed = actions.where((a) => a.status == 'completed').length;
    return math.min(100, baseline + recentA * 12 + recentL * 8 + completed * 5);
  }

  int _weighted(int opp, int fit, int syn, int roi, int mom) =>
      (opp * 0.25 + fit * 0.25 + syn * 0.20 + roi * 0.20 + mom * 0.10).round().clamp(0, 100);

  String _recommend(int score) {
    if (score >= 70) return 'ACELERAR';
    if (score >= 45) return 'MANTER';
    if (score >= 25) return 'REVISAR';
    return 'PAUSAR';
  }

  // Allow low confidence for data-sparse projects (was clamp(50, 95) — always ≥50)
  int _confidence(int score) => score.clamp(20, 90);

  List<String> _strengths(Project p, MarketAnalysis? a, int roi, int synergy, int momentum) {
    final s = <String>[];
    if ((a?.opportunityScore ?? p.opportunityScore) >= 70) s.add('Alta pontuação de oportunidade de mercado');
    if (roi >= 50) s.add('ROI positivo registrado');
    if (synergy >= 50) s.add('Alta sinergia com o ecossistema');
    if (momentum >= 40) s.add('Atividade recente elevada');
    if (p.priorityScore >= 70) s.add('Alta prioridade estratégica');
    if (s.isEmpty) s.add('Projeto com potencial a desenvolver');
    return s;
  }

  List<String> _risks(Project p, List<ActionQueueItem> actions, int roi, int momentum) {
    final r = <String>[];
    final pending = actions.where((a) => a.status == 'pending').length;
    if (pending > 5) r.add('$pending ações pendentes acumuladas sem execução');
    if (roi == 0 && actions.isNotEmpty) r.add('Sem ROI registrado apesar das ações em andamento');
    if (momentum < 10 && actions.isNotEmpty) r.add('Baixa atividade nos últimos 30 dias');
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
    if (s.recommendation == 'ACELERAR') return 'Maior potencial identificado — maximize o $label aqui';
    if (s.recommendation == 'MANTER')   return 'Projeto saudável — mantenha o investimento consistente';
    if (s.recommendation == 'REVISAR')  return 'Alocação mínima até reavaliar a estratégia';
    return 'Não recomendado — considere pausar este projeto';
  }
}
