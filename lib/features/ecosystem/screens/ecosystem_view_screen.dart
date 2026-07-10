import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/project.dart';
import '../../../data/models/market_analysis.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/market_analysis_provider.dart';
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

Color _scoreColor(int s) {
  if (s >= 80) return _kGreen;
  if (s >= 60) return _kOrange;
  return _kRed;
}

// ════════════════════════════════════════════════════════════════════════════
// Ecosystem View Screen (M3)
// ════════════════════════════════════════════════════════════════════════════
class EcosystemViewScreen extends ConsumerWidget {
  const EcosystemViewScreen({super.key});

  static const List<String> _projectTypes = [
    'Blog', 'SaaS', 'App', 'Livro', 'Curso', 'E-commerce',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync  = ref.watch(projectsProvider);
    final analysesAsync  = ref.watch(marketAnalysesProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeDashboard),
        ),
        title: const Text(
          'Ecosystem View',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: _kPrimary),
            tooltip: 'Novo Projeto',
            onPressed: () => context.go(AppConstants.routeProjects),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: projectsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: Colors.white54)),
        ),
        data: (projects) {
          final analyses = analysesAsync.value ?? <MarketAnalysis>[];

          if (projects.isEmpty) {
            return _EmptyEcosystem(onTap: () => context.go(AppConstants.routeProjects));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Summary row
                _EcosystemSummaryRow(projects: projects, analyses: analyses.cast<MarketAnalysis>()),
                const SizedBox(height: 20),

                // Project type filter chips (visual only for now)
                const Text(
                  'SEUS PROJETOS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),

                // Project cards
                ...projects.map((p) {
                  final analysis = analyses
                      .where((a) => a.input.contains(p.name) ||
                          (p.marketAnalysisId != null && a.id == p.marketAnalysisId))
                      .firstOrNull;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProjectCard(
                      project:  p,
                      analysis: analysis,
                      onTap: () => context.go(AppConstants.routeProjects),
                      onMarketTap: analysis != null
                          ? () => context.push(
                                AppConstants.routeMarketIntelligenceHub
                                    .replaceFirst(':id', analysis.id),
                              )
                          : null,
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────────
class _EcosystemSummaryRow extends StatelessWidget {
  const _EcosystemSummaryRow({required this.projects, required this.analyses});
  final List<Project> projects;
  final List<MarketAnalysis> analyses;

  @override
  Widget build(BuildContext context) {
    final avgScore = analyses.isEmpty
        ? 0
        : (analyses
                    .map((a) => a.opportunityScore)
                    .fold<int>(0, (s, v) => s + v) /
                analyses.length)
            .round();

    return Row(
      children: [
        _StatChip('Projetos',        '${projects.length}',  _kPrimary),
        const SizedBox(width: 10),
        _StatChip('Análises',        '${analyses.length}',  _kCyan),
        const SizedBox(width: 10),
        _StatChip('Score Médio',     '$avgScore',            _scoreColor(avgScore)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Project Card ──────────────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.analysis,
    required this.onTap,
    this.onMarketTap,
  });
  final Project project;
  final MarketAnalysis? analysis;
  final VoidCallback onTap;
  final VoidCallback? onMarketTap;

  @override
  Widget build(BuildContext context) {
    final score = analysis?.opportunityScore ?? 0;
    final color = _scoreColor(score);
    final typeColor = _typeColor(project.type ?? 'projeto');

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (project.type ?? 'Projeto').toUpperCase(),
                    style: TextStyle(
                        color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (score > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$score',
                      style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            if (project.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                project.description!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (project.type.isNotEmpty)
                  _InfoBadge(Icons.category_rounded, project.type, _kPrimary),
                const SizedBox(width: 8),
                _InfoBadge(Icons.radio_button_checked_rounded,
                    project.status, _kGreen),
                const Spacer(),
                if (onMarketTap != null)
                  TextButton.icon(
                    onPressed: onMarketTap,
                    icon: const Icon(Icons.analytics_rounded, size: 13),
                    label: const Text('Intel.', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: _kCyan,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _typeColor(String type) {
    const m = {
      'blog': Color(0xFF4CAF50),
      'saas': Color(0xFF6C63FF),
      'app': Color(0xFF00BCD4),
      'livro': Color(0xFFFFD700),
      'curso': Color(0xFFFF9800),
      'e-commerce': Color(0xFFE91E63),
    };
    return m[type.toLowerCase()] ?? const Color(0xFF6C63FF);
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyEcosystem extends StatelessWidget {
  const _EmptyEcosystem({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hub_rounded, color: Colors.white24, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Seu Ecossistema está vazio',
              style: TextStyle(
                  color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Crie projetos no Project Command Center para visualizar seu ecossistema de negócios.',
              style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar Primeiro Projeto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
