import '../models/action_queue_item.dart';
import '../models/executive_context.dart';
import '../models/knowledge_coverage.dart';
import '../models/market_analysis.dart';
import '../models/opportunity_lab_item.dart';
import '../models/project.dart';

/// Calcula a saúde executiva de um projeto nos 8 pilares.
/// Puro Dart — sem I/O.
class ExecutiveHealthService {
  ExecutiveHealth compute({
    required Project project,
    required KnowledgeCoverage coverage,
    required MarketAnalysis? analysis,
    required List<ActionQueueItem> actions,
    required List<OpportunityLabItem> labItems,
    int knowledgeItemCount = 0,
  }) {
    return ExecutiveHealth(
      knowledge: _knowledgePillar(coverage, knowledgeItemCount),
      market: _marketPillar(analysis),
      execution: _executionPillar(actions),
      monetization: _monetizationPillar(analysis),
      validation: _validationPillar(project, analysis, labItems),
      risks: _riskPillar(analysis, actions),
      technology: _technologyPillar(project, coverage),
      strategy: _strategyPillar(project, analysis, coverage, labItems),
      computedAt: DateTime.now(),
    );
  }

  // ── Pilares ──────────────────────────────────────────────────────────────────

  HealthPillar _knowledgePillar(KnowledgeCoverage coverage, int itemCount) {
    final score =
        _clamp((coverage.score * 0.7 + _min(itemCount * 5, 30)).round());
    return HealthPillar(
      name: 'Conhecimento',
      emoji: '📚',
      score: score,
      status: _status(score),
      strengths: coverage.strengths,
      gaps: coverage.gaps.take(3).toList(),
      recommendation: score < 50
          ? 'Adicione mais documentos de conhecimento para melhorar a precisão das análises.'
          : 'Base de conhecimento sólida. Continue adicionando dados de mercado.',
    );
  }

  HealthPillar _marketPillar(MarketAnalysis? a) {
    if (a == null) {
      return HealthPillar(
        name: 'Mercado',
        emoji: '📊',
        score: 0,
        status: 'crítico',
        gaps: ['Nenhuma análise de mercado executada'],
        recommendation:
            'Execute uma análise de mercado para desbloquear inteligência de mercado.',
      );
    }
    final score = _clamp(
      ((a.opportunityScore ?? 0) * 0.4 +
              (a.scoreSeo ?? 0) * 0.2 +
              (a.scoreGrowth ?? 0) * 0.2 +
              (a.scoreCompetition ?? 0) * 0.2)
          .round(),
    );
    return HealthPillar(
      name: 'Mercado',
      emoji: '📊',
      score: score,
      status: _status(score),
      strengths: [
        if ((a.opportunityScore ?? 0) >= 70) 'Alto Opportunity Score',
        if ((a.scoreGrowth ?? 0) >= 70) 'Mercado em crescimento',
        if ((a.scoreCompetition ?? 0) >= 70) 'Pouca concorrência',
      ],
      gaps: [
        if ((a.scoreSeo ?? 0) < 50)
          'SEO fraco — baixo tráfego orgânico esperado',
        if ((a.scoreGrowth ?? 0) < 50) 'Mercado com crescimento lento',
        if ((a.scoreCompetition ?? 0) < 50) 'Mercado saturado',
      ],
      recommendation: score < 50
          ? 'Revise o nicho ou busque um segmento com menor concorrência.'
          : 'Posição de mercado sólida. Monitore tendências regularmente.',
    );
  }

  HealthPillar _executionPillar(List<ActionQueueItem> actions) {
    if (actions.isEmpty) {
      return HealthPillar(
        name: 'Execução',
        emoji: '⚡',
        score: 0,
        status: 'crítico',
        gaps: ['Nenhuma ação no pipeline'],
        recommendation:
            'Crie ações executáveis para iniciar o momentum do projeto.',
      );
    }
    final completed = actions.where((a) => a.status == 'completed').length;
    final rate = (completed / actions.length * 100).round();
    final pending = actions.where((a) => a.status == 'pending').length;
    final score = _clamp((rate * 0.6 + _min(actions.length * 5, 40)).round());
    return HealthPillar(
      name: 'Execução',
      emoji: '⚡',
      score: score,
      status: _status(score),
      strengths: [
        if (rate >= 50) '$rate% das ações concluídas',
        if (actions.length >= 5) 'Pipeline robusto de ações',
      ],
      gaps: [
        if (pending > 3) '$pending ações pendentes sem progresso',
        if (rate < 30) 'Taxa de execução abaixo de 30%',
      ],
      recommendation: score < 50
          ? 'Aprove e execute as ações pendentes para aumentar o momentum.'
          : 'Boa execução. Mantenha o ritmo e revise prioridades regularmente.',
    );
  }

  HealthPillar _monetizationPillar(MarketAnalysis? a) {
    final score = a == null ? 0 : _clamp(a.scoreMonetization ?? 0);
    return HealthPillar(
      name: 'Monetização',
      emoji: '💰',
      score: score,
      status: _status(score),
      strengths: [
        if (score >= 70) 'Forte potencial de monetização identificado',
        if (a?.monetizationModel != null &&
            (a!.monetizationModel ?? '').isNotEmpty)
          'Modelo de receita definido: ${a?.monetizationModel}',
      ],
      gaps: [
        if (a == null) 'Sem análise de monetização',
        if (score < 50 && a != null)
          'Modelo de monetização com baixa viabilidade',
      ],
      recommendation: score < 50
          ? 'Execute o Revenue Planner para modelar diferentes cenários de receita.'
          : 'Bom potencial de monetização. Documente as premissas de receita.',
    );
  }

  HealthPillar _validationPillar(
      Project p, MarketAnalysis? a, List<OpportunityLabItem> lab) {
    var score = 0;
    if (a != null) score += 30;
    if (lab.isNotEmpty) score += 25;
    if (p.url != null && (p.url ?? '').isNotEmpty) score += 20;
    final approved = lab
        .where((l) => l.status == 'approved' || l.status == 'executing')
        .length;
    score += _min(approved * 10, 25);
    score = _clamp(score);
    return HealthPillar(
      name: 'Validação',
      emoji: '🔬',
      score: score,
      status: _status(score),
      strengths: [
        if (a != null) 'Análise de mercado executada',
        if (lab.isNotEmpty) '${lab.length} oportunidades no Opportunity Lab',
        if (p.url != null && (p.url ?? '').isNotEmpty)
          'Projeto tem presença digital',
      ],
      gaps: [
        if (a == null) 'Sem validação de mercado',
        if (lab.isEmpty) 'Nenhuma oportunidade validada',
      ],
      recommendation: score < 50
          ? 'Execute análises de mercado e valide oportunidades no Opportunity Lab.'
          : 'Validação adequada. Busque feedback real de usuários.',
    );
  }

  HealthPillar _riskPillar(MarketAnalysis? a, List<ActionQueueItem> actions) {
    final risks = a != null ? (a.weaknesses?.length ?? 0) : 0;
    final cancelled = actions.where((act) => act.status == 'cancelled').length;
    var score = 100;
    score -= _min(risks * 10, 40);
    score -= _min(cancelled * 5, 20);
    if (a == null) score -= 30;
    score = _clamp(score);
    return HealthPillar(
      name: 'Riscos',
      emoji: '🛡️',
      score: score,
      status: _status(score),
      strengths: [
        if (risks == 0) 'Sem fraquezas identificadas',
        if (cancelled == 0) 'Nenhuma ação cancelada',
      ],
      gaps: [
        if (risks > 2) '$risks fraquezas/riscos identificados na análise',
        if (cancelled > 0) '$cancelled ações canceladas',
        if (a == null) 'Sem análise de riscos executada',
      ],
      recommendation: score < 50
          ? 'Mitigue os principais riscos identificados criando ações preventivas.'
          : 'Perfil de risco controlado. Monitore fraquezas regularmente.',
    );
  }

  HealthPillar _technologyPillar(Project p, KnowledgeCoverage coverage) {
    var score = 0;
    if (p.url != null && (p.url ?? '').isNotEmpty) score += 30;
    if (p.type == 'website' || p.type == 'saas') score += 20;
    if (coverage.docPoints > 0) score += 30;
    score += _min(coverage.oppPoints, 20);
    score = _clamp(score);
    return HealthPillar(
      name: 'Tecnologia',
      emoji: '🛠️',
      score: score,
      status: _status(score),
      strengths: [
        if (p.url != null && (p.url ?? '').isNotEmpty)
          'Presença digital existente',
        if (coverage.docPoints > 0) 'Documentação técnica presente',
      ],
      gaps: [
        if (p.url == null || (p.url ?? '').isEmpty)
          'Sem presença digital documentada',
        if (coverage.docPoints == 0) 'Sem documentação técnica',
      ],
      recommendation: score < 50
          ? 'Documente a stack tecnológica e adicione o link do projeto.'
          : 'Infraestrutura tecnológica adequada para o estágio atual.',
    );
  }

  HealthPillar _strategyPillar(
    Project p,
    MarketAnalysis? a,
    KnowledgeCoverage coverage,
    List<OpportunityLabItem> lab,
  ) {
    var score = 0;
    if (a?.valueProposition != null && (a!.valueProposition ?? '').isNotEmpty)
      score += 25;
    if (a?.positioning != null && (a?.positioning ?? '').isNotEmpty)
      score += 20;
    if (lab.any((l) => l.status == 'approved')) score += 20;
    if (p.opportunityScore >= 60) score += 20;
    score += _min(coverage.score ~/ 5, 15);
    score = _clamp(score);
    return HealthPillar(
      name: 'Estratégia',
      emoji: '🎯',
      score: score,
      status: _status(score),
      strengths: [
        if (a?.valueProposition != null) 'Proposta de valor definida',
        if (a?.positioning != null) 'Posicionamento estratégico definido',
        if (p.opportunityScore >= 60) 'Alto Opportunity Score estratégico',
      ],
      gaps: [
        if (a == null) 'Sem estratégia de mercado definida',
        if (a?.valueProposition == null) 'Proposta de valor não documentada',
        if (a?.positioning == null) 'Posicionamento estratégico indefinido',
      ],
      recommendation: score < 50
          ? 'Defina a proposta de valor e o posicionamento estratégico do projeto.'
          : 'Estratégia bem definida. Revise alinhamento a cada trimestre.',
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  int _clamp(int v) => v.clamp(0, 100);
  int _min(num a, num b) => a < b ? a.toInt() : b.toInt();

  String _status(int score) {
    if (score >= 70) return 'forte';
    if (score >= 40) return 'atenção';
    return 'crítico';
  }
}
