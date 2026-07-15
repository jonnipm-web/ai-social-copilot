import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/knowledge_graph.dart';
import '../../../data/models/persona_learning_profile.dart';
import '../../../data/models/project_intelligence_profile.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/project_intelligence_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

const _kBg      = Color(0xFF0A0A14);
const _kCard    = Color(0xFF12121E);
const _kBorder  = Color(0xFF1E1E30);
const _kPrimary = Color(0xFF7C4DFF);
const _kGreen   = Color(0xFF00E676);
const _kOrange  = Color(0xFFFF9100);
const _kRed     = Color(0xFFFF1744);
const _kGold    = Color(0xFFFFD700);
const _kCyan    = Color(0xFF00E5FF);

// ════════════════════════════════════════════════════════════════════════════
// AI Social Copilot OS — Home Command Center
// ════════════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _kBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('AI Social Copilot OS',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text('Command Center',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high_rounded, color: _kPrimary),
            tooltip: 'Melhorar Post',
            onPressed: () => context.push(AppConstants.routeGenerate),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white38),
            tooltip: 'Atualizar',
            onPressed: () {
              ref.invalidate(projectIntelligenceProfilesProvider);
              ref.invalidate(personaLearningProfilesProvider);
              ref.invalidate(knowledgeGraphProvider);
              ref.invalidate(ecosystemScoresProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: const [
            _ExecutiveCommandCard(),
            SizedBox(height: 16),
            _PriorityProjectsCard(),
            SizedBox(height: 16),
            _NextBestActionCard(),
            SizedBox(height: 16),
            _PersonasCard(),
            SizedBox(height: 16),
            _EcosystemIntelligenceCard(),
          ],
        ),
      ),
    );
  }
}

// ── Card 1: Executive Command Center ──────────────────────────────────────
class _ExecutiveCommandCard extends ConsumerWidget {
  const _ExecutiveCommandCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync  = ref.watch(projectsProvider);
    final healthAsync    = ref.watch(ecosystemHealthProvider);
    final actionsAsync   = ref.watch(actionQueueProvider);
    final labAsync       = ref.watch(opportunityLabProvider);
    final coverageAsync  = ref.watch(portfolioCoverageScoreProvider);
    final learningAsync  = ref.watch(avgLearningScoreProvider);

    final projectCount  = projectsAsync.valueOrNull?.length ?? 0;
    final health        = healthAsync.valueOrNull ?? 0;
    final pendingActions = (actionsAsync.valueOrNull ?? [])
        .where((a) => a.status == 'pending').length;
    final opportunities = (labAsync.valueOrNull ?? []).length;
    final coverage      = coverageAsync.valueOrNull ?? 0;
    final learning      = learningAsync.valueOrNull ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A0E40), Color(0xFF0E0E1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kPrimary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.hub_rounded, color: _kPrimary, size: 18),
            const SizedBox(width: 8),
            const Text('Executive Command Center',
                style: TextStyle(
                    color: _kPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.8)),
            const Spacer(),
            _HealthBadge(health: health),
          ]),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(
                  label: 'Projetos',
                  value: '$projectCount',
                  icon: Icons.rocket_launch_rounded,
                  color: _kPrimary),
              _MetricChip(
                  label: 'Oportunidades',
                  value: '$opportunities',
                  icon: Icons.science_rounded,
                  color: _kCyan),
              _MetricChip(
                  label: 'Ações Pendentes',
                  value: '$pendingActions',
                  icon: Icons.bolt_rounded,
                  color: pendingActions > 0 ? _kOrange : _kGreen),
              _MetricChip(
                  label: 'Knowledge',
                  value: '$coverage%',
                  icon: Icons.auto_stories_rounded,
                  color: _coverageColor(coverage)),
              _MetricChip(
                  label: 'Learning Score',
                  value: '$learning%',
                  icon: Icons.psychology_rounded,
                  color: _learningColor(learning)),
            ],
          ),
          const SizedBox(height: 12),
          // Quick navigation row
          Row(children: [
            _QuickAction(
                label: 'Decision Center',
                icon: Icons.speed_rounded,
                onTap: () => context.push(AppConstants.routeEcosystem)),
            const SizedBox(width: 8),
            _QuickAction(
                label: 'Briefing',
                icon: Icons.summarize_rounded,
                onTap: () => context.push(AppConstants.routeEcosystemBriefing)),
            const SizedBox(width: 8),
            _QuickAction(
                label: 'Oportunidades',
                icon: Icons.science_rounded,
                onTap: () => context.push(AppConstants.routeOpportunityLab)),
          ]),
        ],
      ),
    );
  }

  Color _coverageColor(int v) {
    if (v >= 60) return _kGreen;
    if (v >= 30) return _kOrange;
    return _kRed;
  }

  Color _learningColor(int v) {
    if (v >= 60) return _kCyan;
    if (v >= 30) return _kOrange;
    return Colors.white38;
  }
}

// ── Card 2: Priority Projects ──────────────────────────────────────────────
class _PriorityProjectsCard extends ConsumerWidget {
  const _PriorityProjectsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(projectIntelligenceProfilesProvider);
    final scoresAsync   = ref.watch(ecosystemScoresProvider);

    return _OsCard(
      title: 'Projetos Prioritários',
      icon: Icons.rocket_launch_rounded,
      iconColor: _kCyan,
      onSeeAll: () => context.push(AppConstants.routeProjects),
      child: profilesAsync.when(
        loading: () => const _CardLoader(),
        error:   (e, _) => _CardError('$e'),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyHint(
              'Nenhum projeto cadastrado.',
              action: 'Adicionar projeto',
              onTap: () => context.push(AppConstants.routeProjects),
            );
          }
          final scores = scoresAsync.valueOrNull ?? [];
          return Column(
            children: profiles.take(3).map((profile) {
              final score = scores
                  .where((s) => s.project.id == profile.project.id)
                  .toList();
              final ecoscore = score.isNotEmpty ? score.first.ecosystemScore : 0;
              final rec = score.isNotEmpty ? score.first.recommendation : '—';
              return _ProjectRow(
                  profile: profile,
                  ecosystemScore: ecoscore,
                  recommendation: rec,
                  onTap: () => context.push(AppConstants.routeProjects));
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Card 3: Next Best Action ───────────────────────────────────────────────
class _NextBestActionCard extends ConsumerWidget {
  const _NextBestActionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(priorityRecommendationsProvider);

    return _OsCard(
      title: 'Próxima Melhor Ação',
      icon: Icons.bolt_rounded,
      iconColor: _kGold,
      onSeeAll: () => context.push(AppConstants.routeActionEngine),
      child: recsAsync.when(
        loading: () => const _CardLoader(),
        error:   (e, _) => _CardError('$e'),
        data: (recs) {
          if (recs.isEmpty) {
            return _EmptyHint(
              'Sem recomendações disponíveis.',
              action: 'Ver Opportunity Lab',
              onTap: () => context.push(AppConstants.routeOpportunityLab),
            );
          }
          final top = recs.first;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kGold.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kGold.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(top.typeLabel,
                        style: const TextStyle(
                            color: _kGold, fontSize: 10)),
                  ),
                  const Spacer(),
                  Text('${top.confidence}% confiança',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ]),
                const SizedBox(height: 8),
                Text(top.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(top.reason,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12, height: 1.4)),
                const SizedBox(height: 8),
                Text('Impacto esperado: ${top.expectedImpact}',
                    style: const TextStyle(
                        color: _kGold, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Card 4: Personas ───────────────────────────────────────────────────────
class _PersonasCard extends ConsumerWidget {
  const _PersonasCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(personaLearningProfilesProvider);

    return _OsCard(
      title: 'Personas',
      icon: Icons.psychology_rounded,
      iconColor: _kPrimary,
      onSeeAll: () => context.push(AppConstants.routePersonas),
      child: profilesAsync.when(
        loading: () => const _CardLoader(),
        error:   (e, _) => _CardError('$e'),
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyHint(
              'Nenhuma persona criada.',
              action: 'Criar persona',
              onTap: () => context.push(AppConstants.routePersonaNew),
            );
          }
          return Column(
            children: profiles.take(4).map((p) =>
                _PersonaRow(profile: p)).toList(),
          );
        },
      ),
    );
  }
}

// ── Card 5: Ecosystem Intelligence ────────────────────────────────────────
class _EcosystemIntelligenceCard extends ConsumerWidget {
  const _EcosystemIntelligenceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graphAsync    = ref.watch(knowledgeGraphProvider);
    final labAsync      = ref.watch(opportunityLabProvider);
    final actionsAsync  = ref.watch(actionQueueProvider);
    final profilesAsync = ref.watch(projectIntelligenceProfilesProvider);

    final labCount    = (labAsync.valueOrNull ?? []).length;
    final actionCount = (actionsAsync.valueOrNull ?? []).length;

    return _OsCard(
      title: 'Inteligência do Ecossistema',
      icon: Icons.hub_rounded,
      iconColor: _kGreen,
      child: graphAsync.when(
        loading: () => const _CardLoader(),
        error:   (e, _) => _CardError('$e'),
        data: (graph) {
          final profileCount = profilesAsync.valueOrNull?.length ?? 0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats row
              Wrap(spacing: 8, runSpacing: 8, children: [
                _StatPill('$profileCount projetos',
                    Icons.rocket_launch_rounded, _kPrimary),
                _StatPill('$labCount oportunidades',
                    Icons.science_rounded, _kCyan),
                _StatPill('$actionCount ações',
                    Icons.bolt_rounded, _kOrange),
                _StatPill('${graph.edges.length} conexões',
                    Icons.share_rounded, _kGreen),
              ]),
              if (graph.edges.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Conexões identificadas:',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...graph.projectConnections.take(3).map((e) =>
                    _ConnectionRow(edge: e)),
                if (graph.personaConnections.isNotEmpty)
                  ...graph.personaConnections.take(2).map((e) =>
                      _ConnectionRow(edge: e)),
              ] else ...[
                const SizedBox(height: 12),
                const Text(
                  'Execute análises de mercado para descobrir conexões entre seus projetos.',
                  style: TextStyle(
                      color: Colors.white38, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _OsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final VoidCallback? onSeeAll;

  const _OsCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5)),
            const Spacer(),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: const Text('ver todos',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HealthBadge extends StatelessWidget {
  final int health;
  const _HealthBadge({required this.health});

  Color get _color {
    if (health >= 70) return _kGreen;
    if (health >= 45) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Text('Saúde $health/100',
          style: TextStyle(
              color: _color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricChip(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ]),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kPrimary.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: _kPrimary, size: 16),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final ProjectIntelligenceProfile profile;
  final int ecosystemScore;
  final String recommendation;
  final VoidCallback onTap;

  const _ProjectRow({
    required this.profile,
    required this.ecosystemScore,
    required this.recommendation,
    required this.onTap,
  });

  Color get _scoreColor {
    if (ecosystemScore >= 70) return _kGreen;
    if (ecosystemScore >= 45) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Text(profile.maturityEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.project.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(profile.maturityLabel,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10)),
                    const Text(' · ',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 10)),
                    Text(
                      '${profile.coverage.coverageEmoji} ${profile.coverage.score}% coverage',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$ecosystemScore',
                style: TextStyle(
                    color: _scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(recommendation,
                style: TextStyle(color: _scoreColor, fontSize: 9)),
          ]),
        ]),
      ),
    );
  }
}

class _PersonaRow extends StatelessWidget {
  final PersonaLearningProfile profile;
  const _PersonaRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Text(profile.learningEmoji,
            style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.persona.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${profile.trainingCount} treinamentos · ${profile.vocabularySize} palavras',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10),
                ),
              ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${profile.learningScore}%',
              style: TextStyle(
                  color: profile.learningScore >= 40
                      ? _kCyan
                      : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text(profile.learningLabel,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 9)),
        ]),
      ]),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  final GraphEdge edge;
  const _ConnectionRow({required this.edge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _kGreen.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border(
            left: BorderSide(color: _kGreen.withOpacity(0.4), width: 2)),
      ),
      child: Text(
        edge.fullDescription,
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(color: color, fontSize: 11)),
      ]),
    );
  }
}

class _CardLoader extends StatelessWidget {
  const _CardLoader();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2));
}

class _CardError extends StatelessWidget {
  final String message;
  const _CardError(this.message);

  @override
  Widget build(BuildContext context) =>
      Text('Erro: $message',
          style: const TextStyle(color: _kRed, fontSize: 11));
}

class _EmptyHint extends StatelessWidget {
  final String message;
  final String? action;
  final VoidCallback? onTap;

  const _EmptyHint(this.message, {this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message,
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        if (action != null && onTap != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Text(action!,
                style: const TextStyle(
                    color: _kPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
