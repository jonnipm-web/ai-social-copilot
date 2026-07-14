import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/advisor_profile.dart';
import '../../../data/models/market_analysis.dart';
import '../../../data/models/project.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../providers/advisor_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

// ── Colors ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kCyan    = Color(0xFF00BCD4);
const _kGold    = Color(0xFFFFD700);
const _kPink    = Color(0xFFE91E63);

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

String _formatBRL(double v) {
  if (v <= 0) return 'R\$ 0';
  if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}k';
  return 'R\$ ${v.toStringAsFixed(0)}';
}

// ════════════════════════════════════════════════════════════════════════════
// Executive Dashboard V2 — M9
// ════════════════════════════════════════════════════════════════════════════
class ExecutiveDashboardScreen extends ConsumerWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisorAsync   = ref.watch(advisorProfileProvider);
    final projectsAsync  = ref.watch(projectsProvider);
    final analysesAsync  = ref.watch(marketAnalysesProvider);
    final roiAsync       = ref.watch(roiSummaryProvider);
    final actionsAsync   = ref.watch(pendingActionsProvider);
    final flagsAsync     = ref.watch(featureFlagsProvider);

    final advisor = advisorAsync.value;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business OS',
              style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (advisor != null)
              Text(
                '${advisor.advisorName} • ${advisor.advisorRole}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Recarregar',
            onPressed: () {
              ref.invalidate(projectsProvider);
              ref.invalidate(marketAnalysesProvider);
              ref.invalidate(roiSummaryProvider);
              ref.invalidate(pendingActionsProvider);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome banner
            if (advisor != null) _WelcomeBanner(advisor: advisor),
            if (advisor == null) _AdvisorCTA(),
            const SizedBox(height: 16),

            // KPI Grid
            _KpiGrid(
              projectCount:  projectsAsync.value?.length ?? 0,
              analysesCount: analysesAsync.value?.length ?? 0,
              roiGlobal: roiAsync.value?['revenue'] ?? 0,
              avgScore: _avgScore(analysesAsync.value),
            ),
            const SizedBox(height: 16),

            // Executive Recommendations (based on real data)
            _ExecutiveRecommendations(
              projects:  projectsAsync.value ?? [],
              analyses:  analysesAsync.value ?? [],
              actions:   actionsAsync.value ?? [],
              roiMap:    roiAsync.value ?? {},
            ),
            const SizedBox(height: 16),

            // Revenue Potential
            _RevenuePotentialBanner(analyses: analysesAsync.value ?? []),
            const SizedBox(height: 16),

            // Pending Actions
            _PendingActionsCard(
              actions: actionsAsync.value ?? [],
              isLoading: actionsAsync.isLoading,
            ),
            const SizedBox(height: 16),

            // Module shortcuts
            _ModuleGrid(
              flags: flagsAsync.value ?? {},
              analysisId: analysesAsync.value?.firstOrNull?.id,
            ),
            const SizedBox(height: 16),

            // Quick stats row
            _QuickStatsRow(
              projects: projectsAsync.value ?? [],
              roiSummary: roiAsync.value ?? {},
            ),
          ],
        ),
      ),
    );
  }

  static int _avgScore(List<MarketAnalysis>? analyses) {
    if (analyses == null || analyses.isEmpty) return 0;
    final sum = analyses
        .map((a) => a.opportunityScore)
        .fold<int>(0, (s, v) => s + v);
    return (sum / analyses.length).round();
  }
}

// ── Welcome Banner ─────────────────────────────────────────────────────────────
class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.advisor});
  final AdvisorProfile advisor;

  static const _avatars = {
    'Atlas':  '🌐',
    'Aurora': '🌅',
    'Mentor': '🎓',
    'Nexus':  '⚡',
  };

  @override
  Widget build(BuildContext context) {
    final emoji = _avatars[advisor.advisorName] ?? '🤖';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary.withOpacity(0.25), _kCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _kPrimary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _kPrimary.withOpacity(0.4)),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá! Sou ${advisor.advisorName}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${advisor.advisorRole} • Estilo ${advisor.advisorStyle}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Seu Business OS está ativo. Análises e decisões prontas.',
                  style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisorCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppConstants.routeAdvisorOnboarding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.psychology_rounded, color: _kPrimary, size: 32),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configure seu Personal AI Advisor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Personalize seu parceiro estratégico de negócios.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _kPrimary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── KPI Grid ──────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.projectCount,
    required this.analysesCount,
    required this.roiGlobal,
    required this.avgScore,
  });
  final int projectCount;
  final int analysesCount;
  final double roiGlobal;
  final int avgScore;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _KpiCard('Projetos',     '$projectCount',          _kPrimary, Icons.hub_rounded),
        _KpiCard('Análises MI',  '$analysesCount',         _kCyan,    Icons.analytics_rounded),
        _KpiCard('ROI Global',   _formatBRL(roiGlobal),   _kGreen,   Icons.insights_rounded),
        _KpiCard('Score Médio',  avgScore > 0 ? '$avgScore' : '–', _scoreColor(avgScore), Icons.star_rounded),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Revenue Potential ─────────────────────────────────────────────────────────
class _RevenuePotentialBanner extends StatelessWidget {
  const _RevenuePotentialBanner({required this.analyses});
  final List<MarketAnalysis> analyses;

  @override
  Widget build(BuildContext context) {
    if (analyses.isEmpty) return const SizedBox.shrink();

    final totalMin = analyses
        .map((a) => a.revenueMonthlyMin)
        .fold<double>(0, (s, v) => s + v);
    final totalMax = analyses
        .map((a) => a.revenueMonthlyMax)
        .fold<double>(0, (s, v) => s + v);

    if (totalMax <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: _kGreen, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receita Potencial Total',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  totalMin > 0
                      ? '${_formatBRL(totalMin)} – ${_formatBRL(totalMax)}/mês'
                      : '${_formatBRL(totalMax)}/mês',
                  style: const TextStyle(
                      color: _kGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Baseado em ${analyses.length} análise${analyses.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending Actions ───────────────────────────────────────────────────────────
class _PendingActionsCard extends StatelessWidget {
  const _PendingActionsCard({
    required this.actions,
    required this.isLoading,
  });
  final List<ActionQueueItem> actions;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: _kOrange, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Prioridades da Semana',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppConstants.routeActionEngine),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Ver todas',
                    style: TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (actions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Nenhuma ação pendente. O Action Engine preencherá automaticamente conforme você usa o sistema.',
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            )
          else
            ...actions.take(5).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.roiScore > 0)
                      Text(
                        'ROI: ${item.roiScore}',
                        style: const TextStyle(
                            color: _kGold, fontSize: 10),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Module Grid ───────────────────────────────────────────────────────────────
class _ModuleGrid extends StatelessWidget {
  const _ModuleGrid({required this.flags, this.analysisId});
  final Map<String, bool> flags;
  final String? analysisId;

  @override
  Widget build(BuildContext context) {
    final mods = [
      (
        Icons.hub_rounded,
        'Ecosystem',
        AppConstants.routeEcosystem,
        _kPrimary,
        true,
      ),
      (
        Icons.analytics_rounded,
        'Market Intel.',
        AppConstants.routeMarketIntelligence,
        _kCyan,
        true,
      ),
      (
        Icons.science_rounded,
        'Opp. Lab',
        AppConstants.routeOpportunityLab,
        _kGreen,
        flags[FeatureFlag.opportunityLabEnabled] ?? false,
      ),
      (
        Icons.bolt_rounded,
        'Action Engine',
        AppConstants.routeActionEngine,
        _kOrange,
        flags[FeatureFlag.actionEngineEnabled] ?? false,
      ),
      (
        Icons.insights_rounded,
        'ROI Tracker',
        AppConstants.routeRoiTracker,
        _kGold,
        true,
      ),
      (
        Icons.rocket_launch_rounded,
        'Projetos',
        AppConstants.routeProjects,
        _kPink,
        true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÓDULOS DO BUSINESS OS',
          style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          physics: const NeverScrollableScrollPhysics(),
          children: mods.map((m) {
            final (icon, label, route, color, active) = m;
            return _ModuleTile(
              icon:   icon,
              label:  label,
              color:  active ? color : Colors.white24,
              locked: !active,
              onTap: active
                  ? () => context.push(route)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.locked,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: locked ? Colors.white.withOpacity(0.02) : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: locked ? Colors.white12 : color.withOpacity(0.25)),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color, fontSize: 10, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (locked)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(Icons.lock_rounded,
                    color: Colors.white24, size: 10),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Stats ───────────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.projects, required this.roiSummary});
  final List<Project> projects;
  final Map<String, double> roiSummary;

  @override
  Widget build(BuildContext context) {
    final activeProjects = projects
        .where((p) => p.status == 'active' || p.status == 'executing')
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SNAPSHOT EXECUTIVO',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Stat('Projetos Ativos',       '$activeProjects',                                      _kGreen),
              _Stat('Estratégias (ROI)',      _fmt(roiSummary['opportunity_score']),                 _kPrimary),
              _Stat('Receita Potencial',      _formatBRL(roiSummary['revenue_potential'] ?? 0),      _kCyan),
              _Stat('Score de Oportunidade',  _fmt(roiSummary['avg_opportunity_score']),              _kGold),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double? v) => v != null && v > 0 ? v.round().toString() : '–';
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Executive Recommendations (real-data driven) ────────────────────────────
class _ExecutiveRecommendations extends StatelessWidget {
  const _ExecutiveRecommendations({
    required this.projects,
    required this.analyses,
    required this.actions,
    required this.roiMap,
  });

  final List<Project>        projects;
  final List<MarketAnalysis> analyses;
  final List<ActionQueueItem> actions;
  final Map<String, double>   roiMap;

  List<_Recommendation> _build() {
    final recs = <_Recommendation>[];

    // No advisor configured
    // (handled upstream — this widget is only rendered when data is available)

    // No projects
    if (projects.isEmpty) {
      recs.add(_Recommendation(
        icon: Icons.add_business_rounded,
        color: _kPrimary,
        title: 'Cadastre seu primeiro projeto',
        body: 'Acesse o Project Command Center e cadastre pelo menos um projeto para desbloquear análises e oportunidades.',
        confidence: 100,
      ));
      return recs;
    }

    // No market analyses
    if (analyses.isEmpty) {
      recs.add(_Recommendation(
        icon: Icons.analytics_rounded,
        color: _kCyan,
        title: 'Execute sua primeira análise de mercado',
        body: 'Vá ao Market Intelligence e analise o nicho ou URL do seu projeto "${projects.first.name}" para gerar oportunidades.',
        confidence: 95,
      ));
    }

    // Pending actions
    final pending = actions.where((a) => a.status == 'pending').length;
    if (pending > 0) {
      recs.add(_Recommendation(
        icon: Icons.bolt_rounded,
        color: _kGold,
        title: '$pending ação${pending > 1 ? "ões" : ""} aguardando aprovação',
        body: 'Revise e aprove as ações pendentes no Action Engine para começar a execução.',
        confidence: 90,
      ));
    }

    // High opportunity score analyses
    final topAnalyses = analyses
        .where((a) => a.opportunityScore >= 75)
        .toList()
      ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
    if (topAnalyses.isNotEmpty) {
      final top = topAnalyses.first;
      recs.add(_Recommendation(
        icon: Icons.star_rounded,
        color: _kGreen,
        title: 'Oportunidade de alta pontuação: ${top.niche ?? top.input}',
        body: 'Score ${top.opportunityScore}/100. Acione o Opportunity Lab para converter as ações recomendadas em tarefas executáveis.',
        confidence: top.opportunityScore,
      ));
    }

    // Executing actions
    final executing = actions.where((a) => a.status == 'executing').length;
    if (executing > 0) {
      recs.add(_Recommendation(
        icon: Icons.play_circle_rounded,
        color: _kCyan,
        title: '$executing ação${executing > 1 ? "ões" : ""} em execução',
        body: 'Acompanhe o progresso e registre o resultado no ROI Tracker ao concluir.',
        confidence: 85,
      ));
    }

    // Revenue potential
    final revPot = roiMap['revenue_potential'] ?? 0;
    if (revPot > 0) {
      recs.add(_Recommendation(
        icon: Icons.attach_money_rounded,
        color: _kGreen,
        title: 'Potencial de receita registrado: R\$ ${revPot.toStringAsFixed(0)}',
        body: 'Compare com a receita efetiva para calcular o ROI real dos seus projetos.',
        confidence: 80,
      ));
    }

    // No revenue recorded
    if ((roiMap['revenue'] ?? 0) == 0 && projects.isNotEmpty) {
      recs.add(_Recommendation(
        icon: Icons.payments_rounded,
        color: _kOrange,
        title: 'Nenhuma receita registrada ainda',
        body: 'Adicione entradas de receita no ROI Tracker para acompanhar o retorno real dos seus projetos.',
        confidence: 75,
      ));
    }

    return recs.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final recs = _build();
    if (recs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: _kGold, size: 18),
              SizedBox(width: 8),
              Text(
                'Recomendações Executivas',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...recs.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: r.color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(r.icon, color: r.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(r.body,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${r.confidence}%',
                      style: TextStyle(
                          color: r.color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _Recommendation {
  const _Recommendation({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.confidence,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final int confidence;
}
