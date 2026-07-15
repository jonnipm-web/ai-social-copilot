import 'dart:math' as math;

import '../models/action_queue_item.dart';
import '../models/ecosystem_score.dart';
import '../models/knowledge_item.dart';
import '../models/market_analysis.dart';
import '../models/opportunity_lab_item.dart';
import '../models/persona_learning_profile.dart';
import '../models/priority_recommendation.dart';
import '../models/project.dart';
import '../models/revenue_plan.dart';
import '../models/roi_metric.dart';
import '../models/score_breakdown.dart';
import '../models/validation_result.dart';

class IntelligenceDebugService {
  // ── Public API ─────────────────────────────────────────────────────────────

  List<ScoreBreakdown> generateBreakdowns({
    required List<EcosystemScore> scores,
    required List<Project> projects,
    required List<MarketAnalysis> analyses,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<RoiMetric> roiMetrics,
    required List<RevenuePlan> revenuePlans,
  }) {
    return scores.map((score) {
      final p        = score.project;
      final analysis = _findAnalysis(p, analyses);
      final plan     = _findPlan(p, analysis, revenuePlans);
      final pActions = actions.where((a) => a.projectId == p.id).toList();
      final pLab     = labItems.where((l) => l.projectId == p.id).toList();
      final pRoi     = roiMetrics.where((r) => r.projectId == p.id).toList();

      return _buildBreakdown(p, analysis, pActions, pLab, pRoi, plan, score);
    }).toList();
  }

  ValidationReport runValidation({
    required List<Project> projects,
    required List<KnowledgeItem> knowledgeItems,
    required List<PersonaLearningProfile> learningProfiles,
    required List<MarketAnalysis> analyses,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    required List<EcosystemScore> scores,
    required List<PriorityRecommendation> recommendations,
    required int healthScore,
  }) {
    final tests = <ValidationTest>[];

    // T01 — Projetos com ativos
    final projectsWithAssets = projects.where((p) {
      return actions.any((a) => a.projectId == p.id) ||
             labItems.any((l) => l.projectId == p.id);
    }).length;
    tests.add(ValidationTest(
      id: 'T01',
      name: 'Projetos com Ativos',
      description: 'Todos os projetos possuem ações ou oportunidades cadastradas?',
      status: _status(projectsWithAssets, projects.length),
      passed: projectsWithAssets,
      total: projects.length,
      failedItems: projects
          .where((p) => !actions.any((a) => a.projectId == p.id) &&
                        !labItems.any((l) => l.projectId == p.id))
          .map((p) => p.name)
          .toList(),
      suggestion: 'Adicione ações ou oportunidades no Opportunity Lab para cada projeto.',
    ));

    // T02 — Ativos com projeto vinculado
    final totalAssets   = actions.length + labItems.length;
    final linkedAssets  = actions.where((a) => a.projectId != null).length +
                          labItems.where((l) => l.projectId != null).length;
    tests.add(ValidationTest(
      id: 'T02',
      name: 'Ativos Vinculados a Projeto',
      description: 'Todos os ativos (ações e oportunidades) estão vinculados a um projeto?',
      status: _status(linkedAssets, totalAssets),
      passed: linkedAssets,
      total: totalAssets,
      failedItems: [
        ...actions.where((a) => a.projectId == null).map((a) => 'Ação: ${a.title}'),
        ...labItems.where((l) => l.projectId == null).map((l) => 'Oportunidade: ${l.title}'),
      ],
      suggestion: 'Vincule todas as ações e oportunidades a projetos existentes.',
    ));

    // T03 — Documentos indexados
    final indexedDocs = knowledgeItems.where((k) => k.status == 'analyzed').length;
    tests.add(ValidationTest(
      id: 'T03',
      name: 'Documentos Indexados',
      description: 'Todos os documentos foram processados pelo sistema de conhecimento?',
      status: _status(indexedDocs, knowledgeItems.length),
      passed: indexedDocs,
      total: knowledgeItems.length,
      failedItems: knowledgeItems
          .where((k) => k.status != 'analyzed')
          .map((k) => '${k.title} [${k.status}]')
          .toList(),
      suggestion: 'Acesse o Cofre de Conhecimento e reprocesse os documentos pendentes.',
    ));

    // T04 — Personas com aprendizado
    final personasWithLearning = learningProfiles.where((p) => p.learningScore > 0).length;
    tests.add(ValidationTest(
      id: 'T04',
      name: 'Personas com Aprendizado',
      description: 'Todas as personas possuem pelo menos um treinamento registrado?',
      status: _status(personasWithLearning, learningProfiles.length),
      passed: personasWithLearning,
      total: learningProfiles.length,
      failedItems: learningProfiles
          .where((p) => p.learningScore == 0)
          .map((p) => p.persona.name)
          .toList(),
      suggestion: 'Treine as personas no Cofre de Conhecimento com documentos relevantes.',
    ));

    // T05 — Recomendações com evidências
    final recsWithEvidence = recommendations
        .where((r) => r.dataUsed.isNotEmpty && r.confidence >= 40)
        .length;
    tests.add(ValidationTest(
      id: 'T05',
      name: 'Recomendações com Evidências',
      description: 'Todas as recomendações possuem dados rastreáveis e confiança ≥ 40%?',
      status: _status(recsWithEvidence, recommendations.length),
      passed: recsWithEvidence,
      total: recommendations.length,
      failedItems: recommendations
          .where((r) => r.dataUsed.isEmpty || r.confidence < 40)
          .map((r) => '${r.title} [${r.confidence}% confiança]')
          .toList(),
      suggestion: 'Adicione análises de mercado e métricas ROI para aumentar a confiança.',
    ));

    // T06 — Scores com dados suficientes
    final scoresWithData = scores.where((s) => s.ecosystemScore > 15).length;
    tests.add(ValidationTest(
      id: 'T06',
      name: 'Scores com Dados Suficientes',
      description: 'Todos os scores do ecossistema possuem dados reais suficientes?',
      status: _status(scoresWithData, scores.length),
      passed: scoresWithData,
      total: scores.length,
      failedItems: scores
          .where((s) => s.ecosystemScore <= 15)
          .map((s) => '${s.project.name} [${s.ecosystemScore}pts]')
          .toList(),
      suggestion: 'Vincule análises de mercado e registre métricas ROI para melhorar os scores.',
    ));

    final orphanActions = actions.where((a) => a.projectId == null).length;
    final orphanLab     = labItems.where((l) => l.projectId == null).length;

    return ValidationReport(
      tests:                     tests,
      runAt:                     DateTime.now(),
      projectsAudited:           projects.length,
      documentsFound:            knowledgeItems.length,
      documentsIndexed:          indexedDocs,
      assetsFound:               totalAssets,
      orphanAssets:              orphanActions + orphanLab,
      personasAudited:           learningProfiles.length,
      personasWithLearning:      personasWithLearning,
      personasWithoutLearning:   learningProfiles.length - personasWithLearning,
      opportunitiesAudited:      labItems.length,
      recommendationsAudited:    recommendations.length,
      scoresAudited:             scores.length,
      invalidScores:             scores.length - scoresWithData,
      brokenRules:               tests.where((t) => t.status == ValidationStatus.fail).length,
      problemsFound:             tests.fold(0, (s, t) => s + t.failedCount),
      intelligenceScoreBefore:   healthScore,
      intelligenceScoreAfter:    healthScore,
    );
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  ScoreBreakdown _buildBreakdown(
    Project p,
    MarketAnalysis? analysis,
    List<ActionQueueItem> pActions,
    List<OpportunityLabItem> pLab,
    List<RoiMetric> pRoi,
    RevenuePlan? plan,
    EcosystemScore score,
  ) {
    final now    = DateTime.now();
    final cut30  = now.subtract(const Duration(days: 30));

    // ── Opportunity ──────────────────────────────────────────────────────────
    final oppSources = <String>[];
    final String oppFormula;
    final int oppRaw;
    if (analysis != null) {
      oppRaw    = analysis.opportunityScore;
      oppFormula = 'analysis.opportunityScore (via análise vinculada)';
      oppSources.add('MarketAnalysis.opportunityScore = $oppRaw');
    } else {
      final revPart  = math.min(50.0, p.revenuePotential / 2000);
      final priPart  = p.priorityScore * 0.30;
      final timePart = (p.timeToRevenueDays >= 1 && p.timeToRevenueDays <= 90) ? 10.0 : 0.0;
      oppRaw    = (revPart + priPart + timePart).round().clamp(0, 100);
      oppFormula = 'min(50, revenuePotential/2000) + priorityScore×0.30 + (days≤90 ? 10 : 0)';
      oppSources.add('revenuePotential=${p.revenuePotential} → ${revPart.round()}pts');
      oppSources.add('priorityScore=${p.priorityScore} × 0.30 = ${priPart.round()}pts');
      if (timePart > 0) {
        oppSources.add('timeToRevenueDays=${p.timeToRevenueDays} (≤90d) → +10pts');
      } else {
        oppSources.add('timeToRevenueDays=${p.timeToRevenueDays} (>90d) → +0pts');
      }
      oppSources.add('SEM análise de mercado vinculada — score derivado dos campos do projeto');
    }

    // ── Strategic Fit ────────────────────────────────────────────────────────
    final completedActions = pActions.where((a) => a.status == 'completed').length;
    final totalRoiValue    = pRoi.fold<double>(0, (s, r) => s + r.metricValue);
    final baseOpp          = analysis?.opportunityScore ?? oppRaw;
    final marketComp       = baseOpp * 0.35;
    final priorityComp     = p.priorityScore * 0.20;
    final roiComp          = math.min(100.0, totalRoiValue / 2000 * 100) * 0.25;
    final execComp         = pActions.isEmpty ? 5.0 : (completedActions / pActions.length * 100) * 0.20;
    final fitRaw           = (marketComp + priorityComp + roiComp + execComp).round().clamp(0, 100);
    final fitSources = [
      'mercado=$baseOpp × 0.35 = ${marketComp.round()}pts',
      'priorityScore=${p.priorityScore} × 0.20 = ${priorityComp.round()}pts',
      'ROI=R\$${totalRoiValue.round()} / 2000 × 100 × 0.25 = ${roiComp.round()}pts',
      pActions.isEmpty
          ? 'sem ações → execComp = 5pts (baseline)'
          : '$completedActions/${pActions.length} ações concluídas × 100 × 0.20 = ${execComp.round()}pts',
    ];

    // ── Synergy ──────────────────────────────────────────────────────────────
    final approvedLab = pLab.where((l) => l.status == 'approved').length;
    final synBase     = analysis != null ? 25 : 0;
    final synLab      = math.min(30, pLab.length * 8);
    final synApproved = math.min(20, approvedLab * 10);
    final synActions  = math.min(15, pActions.length * 3);
    final synRaw      = (synBase + synLab + synApproved + synActions).clamp(0, 100);
    final synSources = [
      analysis != null ? 'análise vinculada → +25pts' : 'SEM análise → +0pts',
      'labItems=${pLab.length} × 8 = ${synLab}pts (max 30)',
      'lab aprovados=$approvedLab × 10 = ${synApproved}pts (max 20)',
      'ações=${pActions.length} × 3 = ${synActions}pts (max 15)',
    ];

    // ── ROI ──────────────────────────────────────────────────────────────────
    final String roiFormula;
    final int roiRaw;
    final roiSources = <String>[];
    if (pRoi.isNotEmpty) {
      roiRaw    = math.min(100, (totalRoiValue / 2000 * 100).round());
      roiFormula = 'min(100, Σ(metricValue) / 2000 × 100)';
      roiSources.add('${pRoi.length} métricas ROI encontradas');
      roiSources.add('total = R\$${totalRoiValue.round()} / 2000 × 100 = ${roiRaw}pts');
      for (final r in pRoi.take(3)) {
        roiSources.add('  ${r.metricType}: R\$${r.metricValue.round()}');
      }
    } else if (plan != null && plan.monthlyModerate > 0) {
      roiRaw    = math.min(100, (plan.monthlyModerate / 100).round());
      roiFormula = 'min(100, RevenuePlan.monthlyModerate / 100)  ← estimativa';
      roiSources.add('SEM métricas ROI reais — usando plano de receita como proxy');
      roiSources.add('monthlyModerate = R\$${plan.monthlyModerate.round()} → ${roiRaw}pts');
    } else {
      roiRaw    = 0;
      roiFormula = 'sem dados → 0';
      roiSources.add('SEM métricas ROI e SEM plano de receita');
    }

    // ── Momentum ─────────────────────────────────────────────────────────────
    final recentActions  = pActions.where((a) => a.createdAt.isAfter(cut30)).length;
    final recentLab      = pLab.where((l) => l.createdAt.isAfter(cut30)).length;
    final completedCount = pActions.where((a) => a.status == 'completed').length;
    final baseline       = (pActions.isNotEmpty || pLab.isNotEmpty) ? 15 : 0;
    final momRaw         = math.min(100,
        baseline + recentActions * 12 + recentLab * 8 + completedCount * 5);
    final momSources = [
      baseline > 0 ? 'itens existentes → baseline ${baseline}pts' : 'sem itens → baseline 0pts',
      'ações últimos 30d = $recentActions × 12 = ${recentActions * 12}pts',
      'oportunidades últimos 30d = $recentLab × 8 = ${recentLab * 8}pts',
      'ações concluídas = $completedCount × 5 = ${completedCount * 5}pts',
    ];

    // ── Missing data & sources ───────────────────────────────────────────────
    final missing = <String>[];
    if (analysis == null)       missing.add('Análise de mercado não vinculada');
    if (pRoi.isEmpty)           missing.add('Sem métricas ROI registradas');
    if (plan == null)           missing.add('Sem plano de receita');
    if (pActions.isEmpty)       missing.add('Sem ações cadastradas');
    if (pLab.isEmpty)           missing.add('Sem oportunidades no Opportunity Lab');

    final allSources = <String>[];
    if (analysis != null) allSources.add('MarketAnalysis: ${analysis.id.substring(0, 8)}... (${analysis.input.substring(0, math.min(30, analysis.input.length))}...)');
    if (plan != null)     allSources.add('RevenuePlan: ${plan.projectName} — R\$${plan.monthlyModerate.round()}/mês');
    if (pRoi.isNotEmpty)  allSources.add('${pRoi.length} RoiMetric(s)');
    if (pActions.isNotEmpty) allSources.add('${pActions.length} Action(s) (${completedCount} concluídas)');
    if (pLab.isNotEmpty)  allSources.add('${pLab.length} OpportunityLabItem(s)');
    if (allSources.isEmpty) allSources.add('Nenhuma fonte de dados vinculada');

    final confidence = missing.isEmpty ? 90 : (missing.length <= 2 ? 60 : 30);

    return ScoreBreakdown(
      projectId:     p.id,
      projectName:   p.name,
      opportunity:   ScoreComponent(
        name:        'Opportunity Score',
        rawValue:    oppRaw,
        maxValue:    100,
        weight:      0.25,
        formula:     oppFormula,
        explanation: analysis != null
            ? 'Score obtido diretamente da análise de mercado vinculada.'
            : 'Score derivado de campos do projeto (revenuePotential, priorityScore, timeToRevenueDays). Para maior precisão, vincule uma análise de mercado.',
        dataSources: oppSources,
        hasData:     analysis != null,
      ),
      strategicFit:  ScoreComponent(
        name:        'Strategic Fit',
        rawValue:    fitRaw,
        maxValue:    100,
        weight:      0.25,
        formula:     'mercado×0.35 + prioridade×0.20 + ROI×0.25 + execução×0.20',
        explanation: 'Mede alinhamento estratégico: oportunidade de mercado, priorização, retorno esperado e capacidade de execução.',
        dataSources: fitSources,
        hasData:     true,
      ),
      synergy:       ScoreComponent(
        name:        'Synergy Score',
        rawValue:    synRaw,
        maxValue:    100,
        weight:      0.20,
        formula:     'análise(+25) + lab×8(max30) + aprovados×10(max20) + ações×3(max15)',
        explanation: 'Mede a riqueza do ecossistema ao redor do projeto: análise vinculada, oportunidades mapeadas e ações definidas.',
        dataSources: synSources,
        hasData:     pLab.isNotEmpty || pActions.isNotEmpty,
      ),
      roi:           ScoreComponent(
        name:        'ROI Score',
        rawValue:    roiRaw,
        maxValue:    100,
        weight:      0.20,
        formula:     roiFormula,
        explanation: pRoi.isNotEmpty
            ? 'Calculado a partir de métricas ROI reais registradas.'
            : (plan != null
                ? 'Estimado a partir do plano de receita moderado (proxy — sem métricas reais).'
                : 'Sem dados de ROI. Registre métricas de ROI ou crie um plano de receita.'),
        dataSources: roiSources,
        hasData:     pRoi.isNotEmpty || plan != null,
      ),
      momentum:      ScoreComponent(
        name:        'Momentum Score',
        rawValue:    momRaw,
        maxValue:    100,
        weight:      0.10,
        formula:     'baseline(15) + açõesUlt30d×12 + labUlt30d×8 + concluídas×5',
        explanation: 'Mede a velocidade de atividade recente. Projetos inativos nos últimos 30 dias perdem momentum.',
        dataSources: momSources,
        hasData:     pActions.isNotEmpty || pLab.isNotEmpty,
      ),
      finalScore:    score.ecosystemScore,
      recommendation: score.recommendation,
      allDataSources: allSources,
      missingData:   missing,
      confidence:    confidence,
    );
  }

  MarketAnalysis? _findAnalysis(Project p, List<MarketAnalysis> analyses) {
    if (analyses.isEmpty) return null;
    if (p.marketAnalysisId != null) {
      final d = analyses.where((a) => a.id == p.marketAnalysisId).toList();
      if (d.isNotEmpty) return d.first;
    }
    if (p.url != null && p.url!.isNotEmpty) {
      final pUrl = _normalizeUrl(p.url!);
      for (final a in analyses) {
        if (_normalizeUrl(a.input) == pUrl) return a;
      }
    }
    return null;
  }

  RevenuePlan? _findPlan(Project p, MarketAnalysis? a, List<RevenuePlan> plans) {
    if (plans.isEmpty) return null;
    if (p.marketAnalysisId != null) {
      final d = plans.where((r) => r.marketAnalysisId == p.marketAnalysisId).toList();
      if (d.isNotEmpty) return d.first;
    }
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

  ValidationStatus _status(int passed, int total) {
    if (total == 0) return ValidationStatus.pass;
    final rate = passed / total;
    if (rate >= 1.0) return ValidationStatus.pass;
    if (rate >= 0.5) return ValidationStatus.warning;
    return ValidationStatus.fail;
  }
}
