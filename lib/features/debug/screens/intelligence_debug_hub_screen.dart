import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/project.dart';
import '../../../data/models/score_breakdown.dart';
import '../../../data/models/validation_result.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/auto_bootstrap_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/intelligence_debug_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_intelligence_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

// ─── Palette ───────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF080810);
const _kCard     = Color(0xFF0E0E1C);
const _kBorder   = Color(0xFF1A1A2E);
const _kPrimary  = Color(0xFF7C4DFF);
const _kGreen    = Color(0xFF00E676);
const _kOrange   = Color(0xFFFF9100);
const _kRed      = Color(0xFFFF1744);
const _kCyan     = Color(0xFF00E5FF);
const _kGold     = Color(0xFFFFD700);
const _kMono     = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF9E9EBF));

// ═══════════════════════════════════════════════════════════════════════════
// Intelligence Debug Hub
// ═══════════════════════════════════════════════════════════════════════════
class IntelligenceDebugHubScreen extends ConsumerWidget {
  const IntelligenceDebugHubScreen({super.key});

  static const _tabs = [
    Tab(text: 'Projetos'),
    Tab(text: 'Personas'),
    Tab(text: 'Oportunidades'),
    Tab(text: 'Decisões'),
    Tab(text: 'Scores'),
    Tab(text: 'Grafo'),
    Tab(text: 'Saúde'),
    Tab(text: 'Testes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: _kBg,
        drawer: const AppDrawer(),
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Intelligence Debug Center',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('Observabilidade · Rastreabilidade · Auditoria',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
              tooltip: 'Atualizar tudo',
              onPressed: () {
                ref.invalidate(scoreBreakdownsProvider);
                ref.invalidate(validationReportProvider);
                ref.invalidate(ecosystemScoresProvider);
                ref.invalidate(projectIntelligenceProfilesProvider);
                ref.invalidate(personaLearningProfilesProvider);
                ref.invalidate(knowledgeGraphProvider);
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: _kPrimary,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _kPrimary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: _tabs,
          ),
        ),
        body: const TabBarView(
          children: [
            _ProjectsTab(),
            _PersonasTab(),
            _OpportunitiesTab(),
            _DecisionsTab(),
            _ScoresTab(),
            _GraphTab(),
            _HealthTab(),
            _TestsTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 1 — Project Intelligence Debug
// ═══════════════════════════════════════════════════════════════════════════
class _ProjectsTab extends ConsumerWidget {
  const _ProjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync  = ref.watch(projectsProvider);
    final profilesAsync  = ref.watch(projectIntelligenceProfilesProvider);
    final analysesAsync  = ref.watch(marketAnalysesProvider);
    final actionsAsync   = ref.watch(actionQueueProvider);
    final labAsync       = ref.watch(opportunityLabProvider);
    final kAsync         = ref.watch(knowledgeItemsProvider);

    if (projectsAsync.isLoading || profilesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final projects  = projectsAsync.valueOrNull ?? [];
    final profiles  = profilesAsync.valueOrNull ?? [];
    final analyses  = analysesAsync.valueOrNull ?? [];
    final actions   = actionsAsync.valueOrNull ?? [];
    final labItems  = labAsync.valueOrNull ?? [];
    final kItems    = kAsync.valueOrNull ?? [];

    if (projects.isEmpty) {
      return _empty('Nenhum projeto encontrado.', 'Crie projetos no Project Command Center.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('${projects.length} Projetos Auditados'),
        ...projects.map((project) {
          final profile = profiles.where((p) => p.project.id == project.id).toList();
          final linked  = analyses.where((a) => a.id == project.marketAnalysisId).toList();
          final pActs   = actions.where((a) => a.projectId == project.id).toList();
          final pLab    = labItems.where((l) => l.projectId == project.id).toList();

          return _DebugCard(
            leading:  '📁',
            title:    project.name,
            subtitle: 'ID: ${project.id.substring(0, 12)}... · Status: ${project.status}',
            children: [
              _debugRow('Project ID',    project.id),
              _debugRow('Status',        project.status),
              _debugRow('Atualizado em', project.updatedAt.toIso8601String().substring(0, 16)),
              const _Divider(),
              _sectionLabel('CONHECIMENTO'),
              _debugRow('Documentos no cofre',        '${kItems.length} total'),
              _debugRow('Ativos (ações)',              '${pActs.length}'),
              _debugRow('Oportunidades (Lab)',         '${pLab.length}'),
              _debugRow('Análise de mercado',         linked.isNotEmpty ? '✅ Vinculada' : '❌ Não vinculada'),
              _debugRow('Personas vinculadas',         'via nicho'),
              const _Divider(),
              _sectionLabel('INDEXAÇÃO'),
              _debugRow('Documentos indexados',   '${kItems.where((k) => k.status == "analyzed").length}/${kItems.length}'),
              _debugRow('Docs pendentes',          '${kItems.where((k) => k.status == "pending" || k.status == "processing").length}'),
              _debugRow('Embeddings (status)',     kItems.isEmpty ? 'sem documentos' : 'processados pelo edge function'),
              const _Divider(),
              _sectionLabel('COBERTURA'),
              if (profile.isNotEmpty) ...[
                _debugRow('Knowledge Coverage Score', '${profile.first.coverage.score}%  ${profile.first.coverage.coverageEmoji}'),
                _debugRow('Análise de mercado',       '${profile.first.coverage.analysisPoints}/30pts'),
                _debugRow('Base de conhecimento',     '${profile.first.coverage.knowledgePoints}/25pts'),
                _debugRow('Ações planejadas',         '${profile.first.coverage.actionPoints}/20pts'),
                _debugRow('Oportunidades mapeadas',   '${profile.first.coverage.opportunityPoints}/15pts'),
                _debugRow('Plano de receita',         '${profile.first.coverage.revenuePoints}/10pts'),
                _debugRow('Estágio de maturidade',    '${profile.first.maturityEmoji} ${profile.first.maturityLabel}'),
              ] else
                _debugRow('Perfil de inteligência', 'Não computado'),
              const _Divider(),
              _sectionLabel('FONTES'),
              if (linked.isNotEmpty)
                _debugRow('Análise vinculada', '${linked.first.input.substring(0, 30)}...'),
              _debugRow('Ações disponíveis',   pActs.map((a) => a.title).take(3).join(', ')),
              _debugRow('Oportunidades',       pLab.map((l) => l.title).take(3).join(', ')),
              if (profile.isNotEmpty && profile.first.relatedProjectNames.isNotEmpty)
                _debugRow('Projetos relacionados', profile.first.relatedProjectNames.join(', ')),
              if (profile.isNotEmpty && profile.first.coverage.gaps.isNotEmpty)
                _debugRow('Gaps detectados',
                    profile.first.coverage.gaps.map((g) => '⚠ $g').join('\n')),
            ],
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 2 — Persona Debug Center
// ═══════════════════════════════════════════════════════════════════════════
class _PersonasTab extends ConsumerWidget {
  const _PersonasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(personaLearningProfilesProvider);
    final kAsync        = ref.watch(knowledgeItemsProvider);

    if (profilesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final profiles = profilesAsync.valueOrNull ?? [];
    final kItems   = kAsync.valueOrNull ?? [];

    if (profiles.isEmpty) {
      return _empty('Nenhuma persona encontrada.', 'Crie personas na seção Personas / Marcas.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('${profiles.length} Personas Auditadas'),
        ...profiles.map((p) {
          final personaKItems = kItems.where((k) => k.personaId == p.persona.id).toList();
          return _DebugCard(
            leading:  p.learningEmoji,
            title:    p.persona.name,
            subtitle: '${p.learningLabel} · Score: ${p.learningScore}%',
            children: [
              _debugRow('Persona ID',      p.persona.id),
              _debugRow('Função',          p.persona.description ?? '—'),
              _debugRow('Nicho',           p.persona.niche ?? '—'),
              _debugRow('Tom de voz',      p.persona.voiceTone ?? '—'),
              const _Divider(),
              _sectionLabel('APRENDIZADO'),
              _debugRow('Treinamentos realizados',  '${p.trainingCount}'),
              _debugRow('Palavras no vocabulário',  '${p.vocabularySize}'),
              _debugRow('Valores de marca',         '${p.brandValueCount}'),
              _debugRow('Último aprendizado',
                  p.lastTrainedAt?.toIso8601String().substring(0, 16) ?? 'Nunca'),
              _debugRow('Treinamento recente (30d)', p.hasRecentTraining ? '✅ Sim' : '❌ Não'),
              const _Divider(),
              _sectionLabel('FONTES'),
              _debugRow('Documentos vinculados à persona', '${personaKItems.length}'),
              if (personaKItems.isNotEmpty)
                ...personaKItems.take(5).map((k) => _debugRow('  › ${k.title}', k.status)),
              const _Divider(),
              _sectionLabel('ESTATÍSTICAS'),
              _debugRow('Learning Score',    '${p.learningScore}/100'),
              _debugRow('Nível de confiança', '${(p.confidenceLevel * 100).round()}%'),
              _debugRow('Nível',              p.learningLabel),
              if (p.knownTopics.isNotEmpty)
                _debugRow('Tópicos conhecidos', p.knownTopics.take(5).join(', ')),
              if (p.knownNiches.isNotEmpty)
                _debugRow('Nichos conhecidos', p.knownNiches.take(3).join(', ')),
              const _Divider(),
              _sectionLabel('FÓRMULA LEARNING SCORE'),
              _debugRow('Treinamentos (40pts)',  '${p.trainingCount} treinos'),
              _debugRow('Vocabulário (20pts)',   '${p.vocabularySize} palavras'),
              _debugRow('Valores de marca (20pts)', '${p.brandValueCount} valores'),
              _debugRow('Recência (10pts)',      p.hasRecentTraining ? 'recente → +10' : 'inativo → +0'),
            ],
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 3 — Opportunity Lab Debug
// ═══════════════════════════════════════════════════════════════════════════
class _OpportunitiesTab extends ConsumerWidget {
  const _OpportunitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labAsync      = ref.watch(opportunityLabProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final analysesAsync = ref.watch(marketAnalysesProvider);

    if (labAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final labItems = labAsync.valueOrNull ?? [];
    final projects = projectsAsync.valueOrNull ?? [];
    final analyses = analysesAsync.valueOrNull ?? [];

    if (labItems.isEmpty) {
      return _empty('Nenhuma oportunidade encontrada.', 'Execute análises de mercado para gerar oportunidades.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('${labItems.length} Oportunidades Auditadas'),
        ...labItems.map((opp) {
          final project  = projects.where((p) => p.id == opp.projectId).toList();
          final analysis = analyses.where((a) => a.id == opp.marketAnalysisId).toList();
          final totalW   = opp.marketScore * 0.30 + opp.revenueScore * 0.30 +
                           (100 - opp.competitionScore) * 0.20 +
                           opp.synergyScore * 0.10 + opp.strategicFit * 0.10;

          return _DebugCard(
            leading:  '💡',
            title:    opp.title,
            subtitle: '${opp.opportunityType} · Score: ${opp.finalScore} · ${opp.status}',
            children: [
              _debugRow('Opportunity ID',     opp.id),
              _debugRow('Projeto associado',  project.isNotEmpty ? project.first.name : 'Sem projeto'),
              _debugRow('Análise vinculada',  analysis.isNotEmpty ? '✅ ${analysis.first.input.substring(0, 30)}...' : '❌ Não'),
              _debugRow('Origem',             opp.opportunityType),
              _debugRow('Criado em',          opp.createdAt.toIso8601String().substring(0, 16)),
              const _Divider(),
              _sectionLabel('JUSTIFICATIVA'),
              if (opp.description.isNotEmpty)
                _debugRow('Descrição', opp.description),
              _debugRow('Dados de mercado',    'Score: ${opp.marketScore}/100'),
              _debugRow('Dados de receita',    'Score: ${opp.revenueScore}/100'),
              _debugRow('Dados de competição', 'Score: ${opp.competitionScore}/100 (invertido)'),
              _debugRow('Sinergia detectada',  'Score: ${opp.synergyScore}/100'),
              _debugRow('Fit estratégico',     'Score: ${opp.strategicFit}/100'),
              const _Divider(),
              _sectionLabel('CÁLCULO DO SCORE'),
              _debugRow('Market Potential (30%)',    '${opp.marketScore} × 0.30 = ${(opp.marketScore * 0.30).round()}'),
              _debugRow('Revenue Potential (30%)',   '${opp.revenueScore} × 0.30 = ${(opp.revenueScore * 0.30).round()}'),
              _debugRow('Execution Complexity (20%)', '(100−${opp.competitionScore}) × 0.20 = ${((100 - opp.competitionScore) * 0.20).round()}'),
              _debugRow('Synergy (10%)',             '${opp.synergyScore} × 0.10 = ${(opp.synergyScore * 0.10).round()}'),
              _debugRow('Strategic Fit (10%)',       '${opp.strategicFit} × 0.10 = ${(opp.strategicFit * 0.10).round()}'),
              const _Divider(),
              _debugRow('OPPORTUNITY SCORE',
                  '${totalW.round()} (final registrado: ${opp.finalScore})',
                  highlight: true),
            ],
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 4 — Decision Trace Engine
// ═══════════════════════════════════════════════════════════════════════════
class _DecisionsTab extends ConsumerWidget {
  const _DecisionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync    = ref.watch(priorityRecommendationsProvider);
    final scoresAsync  = ref.watch(ecosystemScoresProvider);
    final breakAsync   = ref.watch(scoreBreakdownsProvider);

    if (recsAsync.isLoading || scoresAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final recs       = recsAsync.valueOrNull ?? [];
    final scores     = scoresAsync.valueOrNull ?? [];
    final breakdowns = breakAsync.valueOrNull ?? [];

    if (recs.isEmpty && scores.isEmpty) {
      return _empty('Nenhuma decisão encontrada.', 'Projetos com análises geram recomendações automáticas.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (scores.isNotEmpty) ...[
          _sectionHeader('${scores.length} Decisões de Projeto'),
          ...scores.map((s) {
            final bd = breakdowns.where((b) => b.projectId == s.project.id).toList();
            return _DebugCard(
              leading:  s.recommendationEmoji,
              title:    s.project.name,
              subtitle: '${s.recommendation} · Ecosystem: ${s.ecosystemScore}',
              children: [
                _sectionLabel('RECOMENDAÇÃO'),
                _debugRow('Decisão',    s.recommendation, highlight: true),
                _debugRow('Pontos fortes',  s.strengths.join('; ')),
                _debugRow('Riscos',         s.risks.join('; ')),
                _debugRow('Ganhos rápidos', s.quickWins.join('; ')),
                const _Divider(),
                _sectionLabel('EVIDÊNCIAS'),
                if (bd.isNotEmpty) ...[
                  _debugRow('Fontes de dados', bd.first.allDataSources.join('\n')),
                  _debugRow('Dados ausentes',  bd.first.missingData.isEmpty
                      ? 'Nenhum — score completo'
                      : bd.first.missingData.join('\n')),
                ] else
                  _debugRow('Evidências', 'Breakdown não disponível'),
                const _Divider(),
                _sectionLabel('REGRAS QUE DISPARARAM'),
                _debugRow('Limiar ACELERAR', '≥ 70pts  →  ${s.ecosystemScore >= 70 ? "✅ disparou" : "não disparou"}'),
                _debugRow('Limiar MANTER',   '45–69pts →  ${s.ecosystemScore >= 45 && s.ecosystemScore < 70 ? "✅ disparou" : "não disparou"}'),
                _debugRow('Limiar REVISAR',  '25–44pts →  ${s.ecosystemScore >= 25 && s.ecosystemScore < 45 ? "✅ disparou" : "não disparou"}'),
                _debugRow('Limiar PAUSAR',   '< 25pts  →  ${s.ecosystemScore < 25 ? "✅ disparou" : "não disparou"}'),
                const _Divider(),
                _sectionLabel('FÓRMULA'),
                if (bd.isNotEmpty)
                  _monoText(bd.first.weightedFormula),
                const _Divider(),
                _sectionLabel('RESULTADO FINAL'),
                _debugRow('Ecosystem Score', '${s.ecosystemScore}/100', highlight: true),
                if (bd.isNotEmpty)
                  _debugRow('Confiança', '${bd.first.confidence}%'),
              ],
            );
          }),
        ],
        if (recs.isNotEmpty) ...[
          _sectionHeader('${recs.length} Recomendações Prioritárias'),
          ...recs.map((r) => _DebugCard(
            leading:  '🎯',
            title:    r.title,
            subtitle: '${r.typeLabel} · ${r.confidence}% confiança',
            children: [
              _debugRow('Tipo',            r.typeLabel),
              _debugRow('Entidade',        r.entityName ?? '—'),
              _debugRow('Entidade ID',     r.entityId ?? '—'),
              const _Divider(),
              _sectionLabel('EVIDÊNCIAS'),
              _debugRow('Dados utilizados', r.dataUsed),
              const _Divider(),
              _sectionLabel('MOTIVOS'),
              _debugRow('Razão',          r.reason),
              _debugRow('Impacto esperado', r.expectedImpact),
              const _Divider(),
              _sectionLabel('RESULTADO'),
              _debugRow('Confiança', '${r.confidence}%', highlight: true),
            ],
          )),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 5 — Score Debug Center
// ═══════════════════════════════════════════════════════════════════════════
class _ScoresTab extends ConsumerWidget {
  const _ScoresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakAsync   = ref.watch(scoreBreakdownsProvider);
    final roiAsync     = ref.watch(roiMetricsProvider);

    if (breakAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final breakdowns = breakAsync.valueOrNull ?? [];
    final roiMetrics = roiAsync.valueOrNull ?? [];

    if (breakdowns.isEmpty) {
      return _empty('Sem scores calculados.', 'Crie projetos para gerar scores de ecossistema.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('${breakdowns.length} Projetos com Scores Detalhados'),
        ...breakdowns.map((bd) {
          final pRoi = roiMetrics.where((r) => r.projectId == bd.projectId).toList();
          return _DebugCard(
            leading:  '📊',
            title:    bd.projectName,
            subtitle: 'Ecosystem: ${bd.finalScore} · ${bd.recommendation}',
            children: [
              _scoreComponentWidget(bd.opportunity),
              const _Divider(),
              _scoreComponentWidget(bd.roi),
              _sectionLabel('ROI — Últimos 30/90 dias'),
              _debugRow('Métricas ROI registradas', '${pRoi.length}'),
              if (pRoi.isNotEmpty) ...[
                ...pRoi.take(5).map((r) =>
                    _debugRow('  ${r.metricType}', 'R\$${r.metricValue.round()} em ${r.createdAt.toString().substring(0, 10)}')),
              ],
              const _Divider(),
              _scoreComponentWidget(bd.momentum),
              const _Divider(),
              _scoreComponentWidget(bd.synergy),
              const _Divider(),
              _scoreComponentWidget(bd.strategicFit),
              const _Divider(),
              _sectionLabel('FÓRMULA FINAL PONDERADA'),
              _monoText(bd.weightedFormula),
              const _Divider(),
              _debugRow('Score Final',    '${bd.finalScore}/100', highlight: true),
              _debugRow('Recomendação',   bd.recommendation, highlight: true),
              _debugRow('Confiança',      '${bd.confidence}%'),
              if (bd.missingData.isNotEmpty)
                _debugRow('Dados ausentes', bd.missingData.map((m) => '⚠ $m').join('\n')),
            ],
          );
        }),
      ],
    );
  }

  Widget _scoreComponentWidget(ScoreComponent c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _sectionLabel('${c.name.toUpperCase()}  (peso ${c.displayWeight})'),
            const Spacer(),
            Text('${c.rawValue}/100',
                style: TextStyle(
                    color: c.hasData ? _kCyan : _kOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ]),
          Text(c.formula, style: _kMono),
          const SizedBox(height: 4),
          Text(c.explanation, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          ...c.dataSources.map((s) => Text('  › $s', style: _kMono)),
          if (!c.hasData)
            const Text('  ⚠ Sem dados suficientes para este componente',
                style: TextStyle(color: _kOrange, fontSize: 11)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 6 — Knowledge Graph Visualizer
// ═══════════════════════════════════════════════════════════════════════════
class _GraphTab extends ConsumerWidget {
  const _GraphTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graphAsync    = ref.watch(knowledgeGraphProvider);
    final projectsAsync = ref.watch(projectsProvider);
    final labAsync      = ref.watch(opportunityLabProvider);
    final profilesAsync = ref.watch(projectIntelligenceProfilesProvider);
    final kAsync        = ref.watch(knowledgeItemsProvider);

    if (graphAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kPrimary));
    }

    final graph    = graphAsync.valueOrNull;
    final projects = projectsAsync.valueOrNull ?? [];
    final labItems = labAsync.valueOrNull ?? [];
    final profiles = profilesAsync.valueOrNull ?? [];
    final kItems   = kAsync.valueOrNull ?? [];

    final edges = graph?.edges ?? [];

    // Orphan detection
    final connectedProjectIds = edges.map((e) => e.sourceId).toSet()
      ..addAll(edges.map((e) => e.targetId));
    final orphanProjects = projects.where((p) => !connectedProjectIds.contains(p.id)).toList();
    final unlinkedKItems = kItems.where((k) => k.personaId == null).toList();
    final orphanLab      = labItems.where((l) => l.projectId == null).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('Knowledge Graph — ${graph?.nodeCount ?? 0} nós · ${edges.length} conexões'),
        // Global stats
        _DebugCard(
          leading: '🕸️',
          title: 'Visão Geral do Grafo',
          subtitle: 'Computado em ${graph?.computedAt.toIso8601String().substring(0, 16) ?? "—"}',
          children: [
            _debugRow('Total de nós',        '${graph?.nodeCount ?? 0}'),
            _debugRow('Total de conexões',   '${edges.length}'),
            _debugRow('Conexões projeto↔projeto', '${edges.where((e) => e.sourceType == "project" && e.targetType == "project").length}'),
            _debugRow('Conexões projeto→oportunidade', '${edges.where((e) => e.targetType == "opportunity").length}'),
            _debugRow('Conexões persona→projeto', '${edges.where((e) => e.sourceType == "persona").length}'),
            _debugRow('Projetos órfãos (sem conexões)', '${orphanProjects.length}', highlight: orphanProjects.isNotEmpty),
            _debugRow('Documentos sem persona vinculada', '${unlinkedKItems.length}', highlight: unlinkedKItems.isNotEmpty),
            _debugRow('Oportunidades sem projeto', '${orphanLab.length}', highlight: orphanLab.isNotEmpty),
          ],
        ),
        // Hierarchical view per project
        _sectionHeader('Hierarquia por Projeto'),
        ...projects.map((project) {
          final profile  = profiles.where((p) => p.project.id == project.id).toList();
          final pLab     = labItems.where((l) => l.projectId == project.id).toList();
          final pEdges   = edges.where((e) => e.sourceId == project.id || e.targetId == project.id).toList();
          final isOrphan = !connectedProjectIds.contains(project.id);

          return _DebugCard(
            leading: isOrphan ? '🔴' : '🟢',
            title: project.name,
            subtitle: '${pEdges.length} conexões · ${pLab.length} oportunidades · ${isOrphan ? "ÓRFÃO" : "Conectado"}',
            children: [
              _graphNodeRow('📁 PROJETO', project.name, project.id),
              const SizedBox(height: 4),
              _debugRow('  ↓ Análise de mercado',
                  profile.isNotEmpty && profile.first.analysis != null
                      ? '✅ ${profile.first.analysis!.input.substring(0, 30)}...'
                      : '❌ Não vinculada'),
              _debugRow('  ↓ Estágio',
                  profile.isNotEmpty ? '${profile.first.maturityEmoji} ${profile.first.maturityLabel}' : 'Não computado'),
              if (pLab.isNotEmpty) ...[
                _debugRow('  ↓ Oportunidades (${pLab.length})',
                    pLab.map((l) => l.title).take(3).join(', ')),
              ],
              if (pEdges.isNotEmpty) ...[
                const _Divider(),
                _sectionLabel('CONEXÕES NO GRAFO'),
                ...pEdges.take(5).map((e) => _debugRow(
                    '  ${e.sourceId == project.id ? "→" : "←"} ${e.targetName}',
                    '${e.relationshipLabel} (peso: ${e.weight.toStringAsFixed(2)})')),
              ],
              if (isOrphan)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('⚠ Projeto sem conexões detectadas no grafo de conhecimento.',
                      style: TextStyle(color: _kOrange, fontSize: 11)),
                ),
            ],
          );
        }),
        if (orphanLab.isNotEmpty) ...[
          _sectionHeader('Ativos Órfãos — Oportunidades sem Projeto'),
          ...orphanLab.map((l) => _DebugCard(
            leading: '🔴',
            title: l.title,
            subtitle: '${l.opportunityType} · score: ${l.finalScore}',
            children: [
              _debugRow('ID',         l.id),
              _debugRow('Projeto',    '❌ Não vinculado'),
              _debugRow('Ação',       'Vincule esta oportunidade a um projeto existente.'),
            ],
          )),
        ],
        if (unlinkedKItems.isNotEmpty) ...[
          _sectionHeader('Documentos sem Indexação de Persona'),
          ...unlinkedKItems.take(10).map((k) => _DebugCard(
            leading: '📄',
            title: k.title,
            subtitle: '${k.sourceType} · ${k.status}',
            children: [
              _debugRow('ID',       k.id),
              _debugRow('Status',   k.status),
              _debugRow('Persona',  k.personaId ?? '❌ Não vinculado'),
              _debugRow('Ação',     'Treine uma persona com este documento no Cofre de Conhecimento.'),
            ],
          )),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 7 — Intelligence Health Monitor
// ═══════════════════════════════════════════════════════════════════════════
class _HealthTab extends ConsumerWidget {
  const _HealthTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync    = ref.watch(ecosystemHealthProvider);
    final coverageAsync  = ref.watch(portfolioCoverageScoreProvider);
    final learningAsync  = ref.watch(avgLearningScoreProvider);
    final recsAsync      = ref.watch(priorityRecommendationsProvider);
    final labAsync       = ref.watch(opportunityLabProvider);
    final kAsync         = ref.watch(knowledgeItemsProvider);
    final profilesAsync  = ref.watch(personaLearningProfilesProvider);
    final scoresAsync    = ref.watch(ecosystemScoresProvider);

    final health     = healthAsync.valueOrNull ?? 0;
    final coverage   = coverageAsync.valueOrNull ?? 0;
    final learning   = learningAsync.valueOrNull ?? 0;
    final recs       = recsAsync.valueOrNull ?? [];
    final labItems   = labAsync.valueOrNull ?? [];
    final kItems     = kAsync.valueOrNull ?? [];
    final personas   = profilesAsync.valueOrNull ?? [];
    final scores     = scoresAsync.valueOrNull ?? [];

    final indexedDocs = kItems.where((k) => k.status == 'analyzed').length;
    final activePersonas = personas.where((p) => p.learningScore > 0).length;
    final recsWithEvidence = recs.where((r) => r.dataUsed.isNotEmpty).length;
    final highScoreOpps = labItems.where((l) => l.finalScore >= 60).length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('Intelligence Health Monitor'),

        // Global score
        _HealthGauge(label: 'Ecosystem Health', value: health, icon: '💎'),
        const SizedBox(height: 12),

        // Knowledge Health
        _DebugCard(
          leading: '📚',
          title: 'Knowledge Health',
          subtitle: 'Indexação · Cobertura · Qualidade · Atualização',
          children: [
            _healthMetric('Documentos indexados', indexedDocs, kItems.length),
            _healthMetric('Cobertura do portfólio', coverage, 100),
            _debugRow('Qualidade',     kItems.isEmpty ? '—' : '${kItems.where((k) => k.status == "analyzed").length}/${kItems.length} processados'),
            _debugRow('Docs recentes (30d)', '${kItems.where((k) => k.updatedAt.isAfter(DateTime.now().subtract(const Duration(days: 30)))).length}'),
            _debugRow('Status', _healthLabel(indexedDocs, kItems.length)),
          ],
        ),

        // Persona Health
        _DebugCard(
          leading: '🧠',
          title: 'Persona Health',
          subtitle: 'Aprendizado · Memória · Utilização',
          children: [
            _healthMetric('Personas com aprendizado', activePersonas, personas.length),
            _healthMetric('Learning Score médio', learning, 100),
            _debugRow('Personas com treinamento recente',
                '${personas.where((p) => p.hasRecentTraining).length}/${personas.length}'),
            _debugRow('Status', _healthLabel(activePersonas, personas.length)),
          ],
        ),

        // Decision Health
        _DebugCard(
          leading: '🧭',
          title: 'Decision Health',
          subtitle: 'Qualidade das recomendações · Evidências · Consistência',
          children: [
            _healthMetric('Recomendações com evidências', recsWithEvidence, recs.length),
            _debugRow('Confiança média',
                recs.isEmpty ? '—' : '${(recs.fold(0, (s, r) => s + r.confidence) / recs.length).round()}%'),
            _debugRow('Scores > 45 (MANTER/ACELERAR)',
                '${scores.where((s) => s.ecosystemScore >= 45).length}/${scores.length}'),
            _debugRow('Scores < 25 (PAUSAR)',
                '${scores.where((s) => s.ecosystemScore < 25).length}/${scores.length}'),
            _debugRow('Status', _healthLabel(recsWithEvidence, recs.length)),
          ],
        ),

        // Opportunity Health
        _DebugCard(
          leading: '💡',
          title: 'Opportunity Health',
          subtitle: 'Quantidade · Relevância · Origem',
          children: [
            _debugRow('Total de oportunidades', '${labItems.length}'),
            _healthMetric('Oportunidades de alta qualidade (≥60)', highScoreOpps, labItems.length),
            _debugRow('Aprovadas',   '${labItems.where((l) => l.status == "approved").length}'),
            _debugRow('Executando',  '${labItems.where((l) => l.status == "executing").length}'),
            _debugRow('Pendentes',   '${labItems.where((l) => l.status == "pending").length}'),
            _debugRow('Status', _healthLabel(highScoreOpps, labItems.length)),
          ],
        ),
      ],
    );
  }

  String _healthLabel(int passed, int total) {
    if (total == 0) return '⚪ Sem dados';
    final r = passed / total;
    if (r >= 0.8) return '🟢 Saudável';
    if (r >= 0.5) return '🟡 Atenção necessária';
    return '🔴 Crítico';
  }

  Widget _healthMetric(String label, int value, int max) {
    final pct    = max == 0 ? 0.0 : value / max;
    final color  = pct >= 0.8 ? _kGreen : pct >= 0.5 ? _kOrange : _kRed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11))),
        Text('$value/$max', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: pct.clamp(0, 1),
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODULE 8 — Automated Validation Tests + Bootstrap Engine
// ═══════════════════════════════════════════════════════════════════════════
class _TestsTab extends ConsumerWidget {
  const _TestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync         = ref.watch(validationReportProvider);
    final bootstrapState      = ref.watch(autoBootstrapNotifierProvider);
    final needsBootstrapAsync = ref.watch(projectsNeedingBootstrapProvider);
    final bootstrapNotifier   = ref.read(autoBootstrapNotifierProvider.notifier);

    if (reportAsync.isLoading) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: _kPrimary),
          SizedBox(height: 12),
          Text('Executando testes de validação...', style: TextStyle(color: Colors.white38)),
        ]),
      );
    }

    if (reportAsync.hasError) {
      return _empty('Erro ao executar validação.', reportAsync.error.toString());
    }

    final report = reportAsync.valueOrNull;
    if (report == null) return _empty('Relatório indisponível.', '');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Knowledge → Action Engine ──────────────────────────────────
        _BootstrapEngineCard(
          bootstrapState:      bootstrapState,
          notifier:            bootstrapNotifier,
          needsBootstrapAsync: needsBootstrapAsync,
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF1A1A2E), height: 1),
        const SizedBox(height: 12),
        // Summary header
        _TestSummaryCard(report: report),
        const SizedBox(height: 12),
        _sectionHeader('Testes Individuais'),
        ...report.tests.map((t) => _TestResultCard(test: t)),
        const SizedBox(height: 12),
        _sectionHeader('Relatório Final de Auditoria'),
        _FinalReportCard(report: report),
      ],
    );
  }
}

// ── Bootstrap Engine Card ─────────────────────────────────────────────────
class _BootstrapEngineCard extends StatelessWidget {
  final BootstrapState bootstrapState;
  final AutoBootstrapNotifier notifier;
  final AsyncValue<List<Project>> needsBootstrapAsync;

  const _BootstrapEngineCard({
    required this.bootstrapState,
    required this.notifier,
    required this.needsBootstrapAsync,
  });

  @override
  Widget build(BuildContext context) {
    final report    = bootstrapState.report;
    final isRunning = bootstrapState.isRunning;
    final isDone    = bootstrapState.isDone;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: _kOrange, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Knowledge → Action Engine',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('Converte documentos em oportunidades, ações e roadmap',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status / pending info
          needsBootstrapAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text('Verificando projetos...', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (projects) {
              if (isDone) return const SizedBox.shrink();
              if (isRunning) return const SizedBox.shrink();
              if (projects.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: _kGreen, size: 14),
                      SizedBox(width: 6),
                      Text('Todos os projetos têm inteligência operacional.',
                          style: TextStyle(color: _kGreen, fontSize: 11)),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '⚡ ${projects.length} projeto${projects.length != 1 ? "s" : ""} com documentos mas sem oportunidades ou ações.',
                  style: const TextStyle(color: _kOrange, fontSize: 11),
                ),
              );
            },
          ),

          // Progress
          if (isRunning) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: bootstrapState.totalProjects > 0
                        ? bootstrapState.currentProject / bootstrapState.totalProjects
                        : null,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(_kOrange),
                    minHeight: 3,
                  ),
                  const SizedBox(height: 6),
                  Text(bootstrapState.progressLabel,
                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ],

          // Results
          if (isDone && report != null) ...[
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Divider(color: Colors.white12, height: 1),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resultado do Bootstrap',
                      style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                          fontSize: 10)),
                  const SizedBox(height: 6),
                  _resultRow('Projetos processados', '${report.projectsBootstrapped}'),
                  _resultRow('Oportunidades criadas', '${report.totalOpportunities}'),
                  _resultRow('Ações criadas',         '${report.totalActions}'),
                  _resultRow('Planos de receita',     '${report.totalRevenuePlans}'),
                  _resultRow('Personas treinadas',    '${report.personasTrainedTotal}'),
                  ...report.projectResults.map((r) => Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('  ${r.projectName}: ${r.summary}',
                        style: TextStyle(
                            color: r.success ? Colors.white54 : _kRed,
                            fontSize: 10)),
                  )),
                ],
              ),
            ),
          ],

          // Error
          if (bootstrapState.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text('Erro: ${bootstrapState.error}',
                  style: const TextStyle(color: _kRed, fontSize: 10)),
            ),

          // Action button
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isRunning ? null : () {
                  if (isDone) {
                    notifier.reset();
                  } else {
                    notifier.runAll();
                  }
                },
                icon: Icon(isDone
                    ? Icons.refresh_rounded
                    : Icons.play_arrow_rounded),
                label: Text(isRunning
                    ? 'Executando...'
                    : isDone
                        ? 'Executar novamente'
                        : '▶ Executar Knowledge → Action Engine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRunning
                      ? Colors.white10
                      : _kOrange.withOpacity(0.2),
                  foregroundColor: _kOrange,
                  side: BorderSide(color: _kOrange.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ),
        Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared Widget Helpers
// ═══════════════════════════════════════════════════════════════════════════

class _DebugCard extends StatefulWidget {
  final String leading;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _DebugCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  State<_DebugCard> createState() => _DebugCardState();
}

class _DebugCardState extends State<_DebugCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text(widget.leading, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              ),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white38, size: 18),
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white12, height: 12),
                ...widget.children,
              ],
            ),
          ),
      ]),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white12, height: 20);
}

class _HealthGauge extends StatelessWidget {
  final String label;
  final int value;
  final String icon;

  const _HealthGauge({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = value >= 70 ? _kGreen : value >= 45 ? _kOrange : _kRed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ])),
        const SizedBox(width: 14),
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24)),
      ]),
    );
  }
}

class _TestResultCard extends StatelessWidget {
  final ValidationTest test;
  const _TestResultCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final color = test.status == ValidationStatus.pass ? _kGreen
        : test.status == ValidationStatus.warning ? _kOrange : _kRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(test.statusEmoji),
          const SizedBox(width: 6),
          Text('[${test.id}]', style: _kMono.copyWith(color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(test.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
          Text('${test.passed}/${test.total}',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Text(test.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        if (test.failedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...test.failedItems.take(5).map((item) =>
              Text('  › $item', style: _kMono.copyWith(color: _kOrange))),
          if (test.failedItems.length > 5)
            Text('  ... e mais ${test.failedItems.length - 5}',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
        if (test.suggestion != null && test.status != ValidationStatus.pass) ...[
          const SizedBox(height: 6),
          Text('💡 ${test.suggestion}',
              style: const TextStyle(color: _kCyan, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _TestSummaryCard extends StatelessWidget {
  final ValidationReport report;
  const _TestSummaryCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = report.failedTests == 0 ? _kGreen
        : report.failedTests <= 2 ? _kOrange : _kRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(report.failedTests == 0 ? '✅' : report.failedTests <= 2 ? '⚠️' : '❌',
              style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(report.overallLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
          Text('${report.passedTests}/${report.tests.length} testes passaram',
              style: TextStyle(color: color, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: report.healthRatio,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _chip('✅ ${report.passedTests}', _kGreen),
          _chip('⚠ ${report.warningTests}', _kOrange),
          _chip('❌ ${report.failedTests}', _kRed),
        ]),
      ]),
    );
  }

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _FinalReportCard extends StatelessWidget {
  final ValidationReport report;
  const _FinalReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _reportRow('Projetos auditados',        '${report.projectsAudited}'),
        _reportRow('Documentos encontrados',    '${report.documentsFound}'),
        _reportRow('Documentos indexados',      '${report.documentsIndexed}/${report.documentsFound}'),
        _reportRow('Ativos encontrados',        '${report.assetsFound}'),
        _reportRow('Ativos órfãos',             '${report.orphanAssets}',
            warn: report.orphanAssets > 0),
        const Divider(color: Colors.white12, height: 16),
        _reportRow('Personas auditadas',        '${report.personasAudited}'),
        _reportRow('Personas com aprendizado real', '${report.personasWithLearning}'),
        _reportRow('Personas sem aprendizado',  '${report.personasWithoutLearning}',
            warn: report.personasWithoutLearning > 0),
        const Divider(color: Colors.white12, height: 16),
        _reportRow('Oportunidades auditadas',   '${report.opportunitiesAudited}'),
        _reportRow('Recomendações auditadas',   '${report.recommendationsAudited}'),
        _reportRow('Scores auditados',          '${report.scoresAudited}'),
        _reportRow('Scores inválidos',          '${report.invalidScores}',
            warn: report.invalidScores > 0),
        const Divider(color: Colors.white12, height: 16),
        _reportRow('Regras quebradas',          '${report.brokenRules}',
            warn: report.brokenRules > 0),
        _reportRow('Problemas encontrados',     '${report.problemsFound}',
            warn: report.problemsFound > 0),
        const Divider(color: Colors.white12, height: 16),
        _reportRow('Inteligência (health score)', '${report.intelligenceScoreBefore}/100'),
        const SizedBox(height: 8),
        Text('Relatório gerado em ${report.runAt.toIso8601String().substring(0, 19).replaceAll("T", " ")}',
            style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ]),
    );
  }

  Widget _reportRow(String label, String value, {bool warn = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Text(value, style: TextStyle(
            color: warn ? _kOrange : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Atomic helpers
// ═══════════════════════════════════════════════════════════════════════════

Widget _sectionHeader(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    );

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: Text(text,
          style: const TextStyle(
              color: _kCyan, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
    );

Widget _debugRow(String label, String value, {bool highlight = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 160,
          child: Text(label, style: _kMono),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: highlight ? _kGold : Colors.white70,
                  fontSize: 11,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
        ),
      ]),
    );

Widget _monoText(String text) => Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kBorder),
      ),
      child: Text(text, style: _kMono.copyWith(height: 1.6)),
    );

Widget _graphNodeRow(String type, String name, String id) => Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _kPrimary.withOpacity(0.3)),
        ),
        child: Text(type, style: const TextStyle(color: _kPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12))),
      Text(id.substring(0, 8), style: _kMono),
    ]);

Widget _empty(String msg, String hint) => Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.search_off_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
          if (hint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(hint, style: const TextStyle(color: Colors.white24, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
