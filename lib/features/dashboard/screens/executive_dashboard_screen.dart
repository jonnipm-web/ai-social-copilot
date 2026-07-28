import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/action_queue_item.dart';
import '../../../data/models/advisor_profile.dart';
import '../../../data/models/market_analysis.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../data/models/project.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/advisor_provider.dart';
import '../../../providers/feature_flag_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart' show showCopilotChat;

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

// ── Responsive Breakpoints ────────────────────────────────────────────────────
class _Bp {
  static bool isTablet(double w) => w >= 600;
  static bool isDesktop(double w) => w >= 1024;
  static bool isWide(double w) => w >= 1440;
}

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

String _fmtBRL(double v) {
  if (v <= 0) return 'Ainda não estimado';
  if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}k';
  return 'R\$ ${v.toStringAsFixed(0)}';
}

// ════════════════════════════════════════════════════════════════════════════
// Executive Dashboard V3 — Responsive Business OS
// ════════════════════════════════════════════════════════════════════════════
class ExecutiveDashboardScreen extends ConsumerWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync  = ref.watch(projectsProvider);
    final analysesAsync  = ref.watch(marketAnalysesProvider);
    final roiAsync       = ref.watch(roiSummaryProvider);
    final actionsAsync   = ref.watch(pendingActionsProvider);
    final flagsAsync     = ref.watch(featureFlagsProvider);
    final labAsync       = ref.watch(opportunityLabProvider);
    final advisorAsync   = ref.watch(advisorProfileProvider);
    final setupAsync     = ref.watch(advisorSetupProvider);

    final projects  = projectsAsync.value  ?? [];
    final analyses  = analysesAsync.value  ?? [];
    final actions   = actionsAsync.value   ?? [];
    final labItems  = labAsync.value       ?? [];
    final roiMap    = roiAsync.value       ?? {};
    final flags     = flagsAsync.value     ?? {};
    final advisor   = advisorAsync.value;
    final hasSetup  = setupAsync.value     ?? false;

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business OS',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('InsightValues · Painel Executivo',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white54),
            tooltip: 'Perguntar à IVE',
            onPressed: () => showCopilotChat(context, screenName: 'Business OS'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Recarregar',
            onPressed: () {
              ref.invalidate(projectsProvider);
              ref.invalidate(marketAnalysesProvider);
              ref.invalidate(roiSummaryProvider);
              ref.invalidate(pendingActionsProvider);
              ref.invalidate(opportunityLabProvider);
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          return _DashboardBody(
            projects:  projects,
            analyses:  analyses,
            actions:   actions,
            labItems:  labItems,
            roiMap:    roiMap,
            flags:     flags,
            advisor:   advisor,
            hasSetup:  hasSetup,
            isDesktop: _Bp.isDesktop(w),
            isTablet:  _Bp.isTablet(w),
            isWide:    _Bp.isWide(w),
          );
        },
      ),
    );
  }
}

// ── Dashboard Body ─────────────────────────────────────────────────────────────
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.projects,
    required this.analyses,
    required this.actions,
    required this.labItems,
    required this.roiMap,
    required this.flags,
    required this.advisor,
    required this.hasSetup,
    required this.isDesktop,
    required this.isTablet,
    required this.isWide,
  });

  final List<Project>            projects;
  final List<MarketAnalysis>     analyses;
  final List<ActionQueueItem>    actions;
  final List<OpportunityLabItem> labItems;
  final Map<String, double>      roiMap;
  final Map<String, bool>        flags;
  final AdvisorProfile?          advisor;
  final bool                     hasSetup;
  final bool isDesktop;
  final bool isTablet;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final maxW   = isWide ? 1400.0 : double.infinity;
    final hPad   = isDesktop ? 32.0 : 16.0;
    final bottom = MediaQuery.of(context).padding.bottom;

    final mainContent = _buildMain(context);
    final sideContent = _buildSidebar(context);

    Widget body;
    if (isDesktop) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: mainContent),
          const SizedBox(width: 20),
          SizedBox(width: 320, child: sideContent),
        ],
      );
    } else {
      body = Column(
        children: [
          mainContent,
          sideContent,
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24 + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: body,
        ),
      ),
    );
  }

  Widget _buildMain(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // IVE Profile Card
        _IveProfileCard(profile: advisor, hasSetup: hasSetup),
        const SizedBox(height: 16),

        // Executive Module Cards
        _ExecModuleGrid(
          projects:  projects,
          analyses:  analyses,
          actions:   actions,
          labItems:  labItems,
          isTablet:  isTablet,
          isDesktop: isDesktop,
        ),
        const SizedBox(height: 16),

        // Executive Recommendations
        _ExecutiveRecommendations(
          projects:  projects,
          analyses:  analyses,
          actions:   actions,
          roiMap:    roiMap,
        ),
        const SizedBox(height: 16),

        // Pending Actions
        _PendingActionsCard(actions: actions),
        const SizedBox(height: 16),

        // Module Shortcuts
        _ModuleGrid(flags: flags, analysisId: analyses.firstOrNull?.id),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final activeProjects = projects.where((p) => p.status == 'active' || p.status == 'executing').length;
    final revPot = roiMap['revenue_potential'] ?? 0;
    final roi    = roiMap['revenue'] ?? 0;
    final avgScore = _avgScore(analyses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Health KPIs
        _SidebarKpiCard(
          title: 'PORTFOLIO EXECUTIVO',
          items: [
            _KpiItem('Projetos Ativos',   '$activeProjects',         _kGreen),
            _KpiItem('Total de Projetos', '${projects.length}',      _kPrimary),
            _KpiItem('Análises MI',       '${analyses.length}',      _kCyan),
            _KpiItem('Score Médio',       avgScore > 0 ? '$avgScore' : '—', _scoreColor(avgScore)),
          ],
        ),
        const SizedBox(height: 12),

        // Revenue
        _SidebarKpiCard(
          title: 'FINANCEIRO',
          items: [
            _KpiItem('Receita Registrada', _fmtBRL(roi),    _kGold),
            _KpiItem('Potencial Mensal',   _fmtBRL(revPot), _kGreen),
          ],
        ),
        const SizedBox(height: 12),

        // Quick nav
        _QuickNavCard(),
      ],
    );
  }

  static int _avgScore(List<MarketAnalysis> analyses) {
    if (analyses.isEmpty) return 0;
    final sum = analyses.map((a) => a.opportunityScore).fold<int>(0, (s, v) => s + v);
    return (sum / analyses.length).round();
  }
}

// ── Executive Module Grid ─────────────────────────────────────────────────────
class _ExecModuleGrid extends StatelessWidget {
  const _ExecModuleGrid({
    required this.projects,
    required this.analyses,
    required this.actions,
    required this.labItems,
    required this.isTablet,
    required this.isDesktop,
  });

  final List<Project>            projects;
  final List<MarketAnalysis>     analyses;
  final List<ActionQueueItem>    actions;
  final List<OpportunityLabItem> labItems;
  final bool isTablet;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final cols = isDesktop ? 4 : isTablet ? 2 : 1;

    final activeProjects   = projects.where((p) => p.status == 'active' || p.status == 'executing').length;
    final ideaProjects     = projects.where((p) => p.status == 'idea').length;
    final noAnalysis       = projects.where((p) => analyses.every((a) => a.id != p.marketAnalysisId)).length;

    final highPriOpp       = labItems.where((l) => l.finalScore >= 70).length;
    final sentToEngine     = labItems.where((l) => l.status == 'approved').length;

    final pending          = actions.where((a) => a.status == 'pending').length;
    final executing        = actions.where((a) => a.status == 'executing').length;
    final blocked          = actions.where((a) => a.status == 'blocked').length;

    final cards = [
      _ExecModule(
        icon:  Icons.rocket_launch_rounded,
        color: _kPrimary,
        title: 'Projetos',
        items: [
          ('Total',          '${projects.length}'),
          ('Ativos',         '$activeProjects'),
          ('Em ideia',       '$ideaProjects'),
          ('Sem análise',    projects.isEmpty ? '–' : '$noAnalysis'),
        ],
        emptyMessage: 'Cadastre seu primeiro projeto para começar.',
        isEmpty: projects.isEmpty,
        route: AppConstants.routeProjects,
        cta: 'Ver Projetos',
      ),
      _ExecModule(
        icon:  Icons.analytics_rounded,
        color: _kCyan,
        title: 'Market Intelligence',
        items: [
          ('Análises',       '${analyses.length}'),
          ('Score médio',    analyses.isEmpty ? '–' : '${analyses.map((a) => a.opportunityScore).fold<int>(0, (s, v) => s + v) ~/ (analyses.isEmpty ? 1 : analyses.length)}/100'),
          ('Alta qualidade', '${analyses.where((a) => a.opportunityScore >= 75).length}'),
          ('Sem projeto',    analyses.isEmpty ? '–' : '–'),
        ],
        emptyMessage: 'Execute uma análise de mercado no Market Intelligence.',
        isEmpty: analyses.isEmpty,
        route: AppConstants.routeMarketIntelligence,
        cta: 'Analisar Mercado',
      ),
      _ExecModule(
        icon:  Icons.science_rounded,
        color: _kGreen,
        title: 'Oportunidades',
        items: [
          ('Total',           '${labItems.length}'),
          ('Alta prioridade', '$highPriOpp'),
          ('Aprovadas',       '$sentToEngine'),
          ('Pendentes',       '${labItems.where((l) => l.status == 'pending').length}'),
        ],
        emptyMessage: 'Gere oportunidades a partir das análises de mercado.',
        isEmpty: labItems.isEmpty,
        route: AppConstants.routeOpportunityLab,
        cta: 'Ver Oportunidades',
      ),
      _ExecModule(
        icon:  Icons.bolt_rounded,
        color: _kOrange,
        title: 'Action Engine',
        items: [
          ('Pendentes',  '$pending'),
          ('Em execução','$executing'),
          ('Bloqueadas', '$blocked'),
          ('Concluídas', '${actions.where((a) => a.status == 'done').length}'),
        ],
        emptyMessage: 'Aprove oportunidades para gerar ações executáveis.',
        isEmpty: actions.isEmpty,
        route: AppConstants.routeActionEngine,
        cta: 'Abrir Decisions',
      ),
    ];

    if (cols == 1) {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: c,
        )).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.05 : 1.3,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }
}

class _ExecModule extends StatelessWidget {
  const _ExecModule({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.isEmpty,
    required this.route,
    required this.cta,
  });

  final IconData           icon;
  final Color              color;
  final String             title;
  final List<(String, String)> items;
  final String             emptyMessage;
  final bool               isEmpty;
  final String             route;
  final String             cta;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 12),
                ],
              ),
              const SizedBox(height: 10),
              if (isEmpty)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color.withOpacity(0.2), size: 28),
                      const SizedBox(height: 6),
                      Text(emptyMessage,
                          style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              else ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) {
                      final (label, value) = item;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(label,
                                style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            Text(value,
                                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cta,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sidebar KPI Card ──────────────────────────────────────────────────────────
class _KpiItem {
  const _KpiItem(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color  color;
}

class _SidebarKpiCard extends StatelessWidget {
  const _SidebarKpiCard({required this.title, required this.items});
  final String        title;
  final List<_KpiItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white38, fontSize: 10,
                  letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                Text(item.value,
                    style: TextStyle(color: item.color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ── Quick Nav Card ────────────────────────────────────────────────────────────
class _QuickNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final navItems = [
      (Icons.hub_rounded,       'Decision Center',   AppConstants.routeEcosystem,         _kPrimary),
      (Icons.summarize_rounded, 'Briefing Semanal',  AppConstants.routeEcosystemBriefing,  _kCyan),
      (Icons.schedule_rounded,  'Alocação',          AppConstants.routeEcosystemResources,  _kOrange),
      (Icons.insights_rounded,  'ROI Tracker',       AppConstants.routeRoiTracker,          _kGold),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ACESSO RÁPIDO',
              style: TextStyle(color: Colors.white38, fontSize: 10,
                  letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...navItems.map((n) {
            final (icon, label, route, color) = n;
            return GestureDetector(
              onTap: () => context.push(route),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5), size: 16),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── IVE Profile Card ──────────────────────────────────────────────────────────
class _IveProfileCard extends StatelessWidget {
  const _IveProfileCard({required this.profile, required this.hasSetup});
  final AdvisorProfile? profile;
  final bool hasSetup;

  static const _avatars = {
    'Atlas': '🌐', 'Iris': '🔮', 'Mentor': '🎓', 'Nexus': '⚡',
  };

  @override
  Widget build(BuildContext context) {
    if (!hasSetup || profile == null) {
      return GestureDetector(
        onTap: () => context.push(AppConstants.routeAdvisorOnboarding),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kPrimary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🤖', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IVE',
                          style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Configure o Perfil IVE para análises personalizadas.',
                          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Configurar Perfil IVE',
                      style: TextStyle(color: _kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final avatar = _avatars[profile!.advisorName] ?? '🤖';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(avatar, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IVE — Perfil ${profile!.advisorName}',
                    style: const TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${profile!.advisorRole} · ${profile!.advisorStyle}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push(AppConstants.routeAdvisorOnboarding),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: const Tooltip(
                message: 'Editar Perfil IVE',
                child: Icon(Icons.edit_rounded, color: Colors.white38, size: 16),
              ),
            ),
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
    final totalMax = analyses.map((a) => a.revenueMonthlyMax).fold<double>(0, (s, v) => s + v);
    final totalMin = analyses.map((a) => a.revenueMonthlyMin).fold<double>(0, (s, v) => s + v);
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
                const Text('Receita Potencial Total',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  totalMin > 0
                      ? '${_fmtBRL(totalMin)} – ${_fmtBRL(totalMax)}/mês'
                      : '${_fmtBRL(totalMax)}/mês',
                  style: const TextStyle(color: _kGreen, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text('Baseado em ${analyses.length} análise${analyses.length != 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
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
  const _PendingActionsCard({required this.actions});
  final List<ActionQueueItem> actions;

  @override
  Widget build(BuildContext context) {
    final pending = actions.where((a) => a.status == 'pending').toList();
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
                child: Text('Prioridades da Semana',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => context.push(AppConstants.routeActionEngine),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Ver todas', style: TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nenhuma ação pendente. O Action Engine preencherá automaticamente.',
                style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
              ),
            )
          else
            ...pending.take(5).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.title,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (item.roiScore > 0)
                    Text('ROI: ${item.roiScore}',
                        style: const TextStyle(color: _kGold, fontSize: 10)),
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
      (Icons.hub_rounded,          'Ecosystem',     AppConstants.routeEcosystem,         _kPrimary, true),
      (Icons.analytics_rounded,    'Market Intel.', AppConstants.routeMarketIntelligence, _kCyan,    true),
      (Icons.science_rounded,      'Opp. Lab',      AppConstants.routeOpportunityLab,     _kGreen,   flags[FeatureFlag.opportunityLabEnabled] ?? false),
      (Icons.bolt_rounded,         'Actions',       AppConstants.routeActionEngine,       _kOrange,  flags[FeatureFlag.actionEngineEnabled] ?? false),
      (Icons.insights_rounded,     'ROI Tracker',   AppConstants.routeRoiTracker,         _kGold,    true),
      (Icons.rocket_launch_rounded,'Projetos',      AppConstants.routeProjects,           _kPink,    true),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MÓDULOS DO BUSINESS OS',
            style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
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
            return GestureDetector(
              onTap: active ? () => context.push(route) : null,
              child: MouseRegion(
                cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
                child: Tooltip(
                  message: active ? 'Abrir $label' : 'Módulo não disponível',
                  child: Container(
                    decoration: BoxDecoration(
                      color:        active ? color.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border:       Border.all(color: active ? color.withOpacity(0.25) : Colors.white12),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: active ? color : Colors.white24, size: 22),
                            const SizedBox(height: 5),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(label,
                                  style: TextStyle(
                                      color: active ? color : Colors.white24,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (!active)
                          const Positioned(top: 4, right: 4,
                              child: Icon(Icons.lock_rounded, color: Colors.white24, size: 10)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Executive Recommendations ─────────────────────────────────────────────────
class _Recommendation {
  const _Recommendation({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.confidence,
  });
  final IconData icon;
  final Color    color;
  final String   title;
  final String   body;
  final int      confidence;
}

class _ExecutiveRecommendations extends StatelessWidget {
  const _ExecutiveRecommendations({
    required this.projects,
    required this.analyses,
    required this.actions,
    required this.roiMap,
  });

  final List<Project>         projects;
  final List<MarketAnalysis>  analyses;
  final List<ActionQueueItem> actions;
  final Map<String, double>   roiMap;

  List<_Recommendation> _build() {
    final recs = <_Recommendation>[];

    if (projects.isEmpty) {
      recs.add(const _Recommendation(
        icon: Icons.add_business_rounded, color: _kPrimary, confidence: 100,
        title: 'Cadastre seu primeiro projeto',
        body: 'Acesse o Project Command Center e cadastre pelo menos um projeto para desbloquear análises e oportunidades.',
      ));
      return recs;
    }

    if (analyses.isEmpty) {
      recs.add(_Recommendation(
        icon: Icons.analytics_rounded, color: _kCyan, confidence: 95,
        title: 'Execute sua primeira análise de mercado',
        body: 'Vá ao Market Intelligence e analise o nicho do projeto "${projects.first.name}".',
      ));
    }

    final pending = actions.where((a) => a.status == 'pending').length;
    if (pending > 0) {
      recs.add(_Recommendation(
        icon: Icons.bolt_rounded, color: _kGold, confidence: 90,
        title: '$pending ação${pending > 1 ? "ões" : ""} aguardando aprovação',
        body: 'Revise e aprove as ações pendentes no Action Engine para começar a execução.',
      ));
    }

    final topAnalyses = analyses.where((a) => a.opportunityScore >= 75).toList()
      ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
    if (topAnalyses.isNotEmpty) {
      final top = topAnalyses.first;
      recs.add(_Recommendation(
        icon: Icons.star_rounded, color: _kGreen, confidence: top.opportunityScore,
        title: 'Oportunidade de alta pontuação: ${top.niche ?? top.input}',
        body: 'Score ${top.opportunityScore}/100. Acione o Opportunity Lab para converter em tarefas.',
      ));
    }

    if ((roiMap['revenue'] ?? 0) == 0 && projects.isNotEmpty) {
      recs.add(const _Recommendation(
        icon: Icons.payments_rounded, color: _kOrange, confidence: 75,
        title: 'Nenhuma receita registrada ainda',
        body: 'Adicione entradas no ROI Tracker para acompanhar o retorno real dos seus projetos.',
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
              Text('Recomendações Executivas',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                  decoration: BoxDecoration(color: r.color.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(r.icon, color: r.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(r.body,
                          style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text('${r.confidence}%',
                    style: TextStyle(color: r.color, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
