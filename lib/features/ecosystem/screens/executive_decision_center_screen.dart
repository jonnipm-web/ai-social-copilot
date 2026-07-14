import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/ecosystem_score.dart';
import '../../../data/models/priority_recommendation.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

// ── Colors ────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0A0A14);
const _kCard    = Color(0xFF12121E);
const _kBorder  = Color(0xFF1E1E30);
const _kPrimary = Color(0xFF7C4DFF);
const _kGold    = Color(0xFFFFD700);
const _kGreen   = Color(0xFF00E676);
const _kOrange  = Color(0xFFFF9100);
const _kRed     = Color(0xFFFF1744);
const _kCyan    = Color(0xFF00E5FF);

Color _scoreColor(int s) {
  if (s >= 70) return _kGreen;
  if (s >= 45) return _kOrange;
  if (s >= 25) return Colors.amber;
  return _kRed;
}

// ════════════════════════════════════════════════════════════════════════════
// Executive Decision Center Screen
// ════════════════════════════════════════════════════════════════════════════
class ExecutiveDecisionCenterScreen extends ConsumerStatefulWidget {
  const ExecutiveDecisionCenterScreen({super.key});

  @override
  ConsumerState<ExecutiveDecisionCenterScreen> createState() =>
      _ExecutiveDecisionCenterScreenState();
}

class _ExecutiveDecisionCenterScreenState
    extends ConsumerState<ExecutiveDecisionCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(ecosystemScoresProvider);
    final recsAsync   = ref.watch(priorityRecommendationsProvider);
    final healthAsync = ref.watch(ecosystemHealthProvider);

    return Scaffold(
      backgroundColor: _kBg,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeDashboard),
        ),
        title: const Text('Decision Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kPrimary,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'TOP 5'),
            Tab(text: 'ECOSSISTEMA'),
            Tab(text: 'RECOMENDAÇÕES'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_rounded, color: Colors.white54),
            tooltip: 'Alocação de Recursos',
            onPressed: () => context.push(AppConstants.routeEcosystemResources),
          ),
          IconButton(
            icon: const Icon(Icons.summarize_rounded, color: Colors.white54),
            tooltip: 'Briefing Semanal',
            onPressed: () => context.push(AppConstants.routeEcosystemBriefing),
          ),
        ],
      ),
      body: Column(
        children: [
          // Health banner
          healthAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (h) => _HealthBanner(health: h),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _Top5Tab(scoresAsync: scoresAsync),
                _EcosystemTab(scoresAsync: scoresAsync),
                _RecsTab(recsAsync: recsAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Health Banner ─────────────────────────────────────────────────────────
class _HealthBanner extends StatelessWidget {
  final int health;
  const _HealthBanner({required this.health});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(health);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: _kCard,
        border: Border(bottom: BorderSide(color: color.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text('$health',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saúde do Ecossistema',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(_healthLabel(health),
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          _HealthBar(value: health / 100, color: color),
        ],
      ),
    );
  }

  String _healthLabel(int h) {
    if (h >= 70) return 'Ecossistema saudável e em crescimento';
    if (h >= 45) return 'Ecossistema estável com oportunidades de melhoria';
    if (h >= 25) return 'Ecossistema com pontos de atenção';
    return 'Ecossistema requer revisão estratégica urgente';
  }
}

class _HealthBar extends StatelessWidget {
  final double value;
  final Color color;
  const _HealthBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80, height: 6,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    ),
  );
}

// ── Tab 1: TOP 5 ──────────────────────────────────────────────────────────
class _Top5Tab extends ConsumerWidget {
  final AsyncValue<List<EcosystemScore>> scoresAsync;
  const _Top5Tab({required this.scoresAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labAsync     = ref.watch(opportunityLabProvider);
    final actionsAsync = ref.watch(actionQueueProvider);

    return scoresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: _kRed))),
      data: (scores) {
        if (scores.isEmpty) {
          return const Center(
            child: Text('Nenhum projeto encontrado.\nAdicionetextos no Cofre e crie projetos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Top5Section(
              title: '🚀 TOP 5 PROJETOS',
              subtitle: 'Ranqueados por Ecosystem Score',
              children: scores.take(5).map((s) => _ProjectCard(score: s)).toList(),
            ),
            const SizedBox(height: 20),
            labAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (lab) {
                final top = List.of(lab)
                  ..sort((a, b) => b.finalScore.compareTo(a.finalScore));
                return _Top5Section(
                  title: '💡 TOP 5 OPORTUNIDADES',
                  subtitle: 'Maior potencial do Opportunity Lab',
                  children: top.take(5).map((l) => _SimpleCard(
                    title: l.title,
                    subtitle: l.opportunityType,
                    score: l.finalScore,
                    badge: l.status,
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            actionsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (actions) {
                // Quick wins: high impact, low effort
                final qw = actions.where((a) =>
                    a.status == 'pending' && a.impactScore >= 60 && a.effortScore <= 50)
                    .toList()
                  ..sort((a, b) =>
                      (b.impactScore - b.effortScore).compareTo(a.impactScore - a.effortScore));

                // Wastes: many pending + low impact
                final wastes = actions.where((a) =>
                    a.status == 'pending' && a.impactScore < 40 && a.effortScore >= 60)
                    .toList();

                // Risks (pending actions from projects with low ecosystem score)
                final riskProjects = scoresAsync.value
                    ?.where((s) => s.ecosystemScore < 30)
                    .map((s) => s.project.id)
                    .toSet() ?? {};
                final risks = actions.where((a) =>
                    a.projectId != null && riskProjects.contains(a.projectId))
                    .toList();

                return Column(
                  children: [
                    _Top5Section(
                      title: '⚡ TOP 5 GANHOS RÁPIDOS',
                      subtitle: 'Alto impacto, baixo esforço',
                      children: qw.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: 'Impacto ${a.impactScore} / Esforço ${a.effortScore}',
                        score: a.impactScore - a.effortScore + 50,
                        badge: a.actionType,
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    _Top5Section(
                      title: '⚠️ TOP 5 RISCOS',
                      subtitle: 'Ações em projetos de baixo score',
                      children: risks.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: a.status,
                        score: 100 - a.impactScore,
                        badge: 'risco',
                        scoreColor: _kRed,
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    _Top5Section(
                      title: '🗑️ TOP 5 DESPERDÍCIOS',
                      subtitle: 'Baixo impacto, alto esforço',
                      children: wastes.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: 'Impacto ${a.impactScore} / Esforço ${a.effortScore}',
                        score: a.impactScore,
                        badge: 'rever',
                        scoreColor: _kOrange,
                      )).toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Top5Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _Top5Section({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 10),
        if (children.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('Nenhum item ainda', style: TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          ...children,
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final EcosystemScore score;
  const _ProjectCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(score.ecosystemScore);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${score.ecosystemScore}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(score.project.name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${score.recommendationEmoji} ${score.recommendation}  •  ROI R\$${score.totalRoi.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Opp ${score.opportunityScore}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text('Fit ${score.strategicFit}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
              Text('Syn ${score.synergyScore}',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int score;
  final String badge;
  final Color? scoreColor;
  const _SimpleCard({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.badge,
    this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = scoreColor ?? _scoreColor(score);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('$score', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(badge, style: const TextStyle(color: Colors.white54, fontSize: 9)),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Ecosystem Scores ───────────────────────────────────────────────
class _EcosystemTab extends StatelessWidget {
  final AsyncValue<List<EcosystemScore>> scoresAsync;
  const _EcosystemTab({required this.scoresAsync});

  @override
  Widget build(BuildContext context) {
    return scoresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: _kRed))),
      data: (scores) {
        if (scores.isEmpty) {
          return const Center(
            child: Text('Adicione projetos para ver o Ecosystem Score.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: scores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _EcosystemCard(score: scores[i]),
        );
      },
    );
  }
}

class _EcosystemCard extends StatefulWidget {
  final EcosystemScore score;
  const _EcosystemCard({required this.score});

  @override
  State<_EcosystemCard> createState() => _EcosystemCardState();
}

class _EcosystemCardState extends State<_EcosystemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.score;
    final color = _scoreColor(s.ecosystemScore);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.project.name,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withOpacity(0.5)),
                        ),
                        child: Text('${s.ecosystemScore}',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('${s.recommendationEmoji} ${s.recommendation}',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _ScoreRow(label: 'Oportunidade', value: s.opportunityScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: 'Strategic Fit', value: s.strategicFit),
                  const SizedBox(height: 4),
                  _ScoreRow(label: 'Synergy', value: s.synergyScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: 'ROI', value: s.roiScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: 'Momentum', value: s.momentumScore),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${s.actionCount} ações  •  ${s.completionRate}% concluídas  •  R\$${s.totalRoi.toStringAsFixed(0)} ROI',
                        style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      const Spacer(),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white38, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.strengths.isNotEmpty) ...[
                    const Text('Pontos Fortes', style: TextStyle(color: _kGreen,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...s.strengths.map((st) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text('• $st', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )),
                    const SizedBox(height: 10),
                  ],
                  if (s.risks.isNotEmpty) ...[
                    const Text('Riscos', style: TextStyle(color: _kOrange,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...s.risks.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text('• $r', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )),
                    const SizedBox(height: 10),
                  ],
                  if (s.quickWins.isNotEmpty) ...[
                    const Text('Ganhos Rápidos', style: TextStyle(color: _kCyan,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...s.quickWins.map((q) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text('⚡ $q', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int value;
  const _ScoreRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor(value);
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 10))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── Tab 3: Recommendations ────────────────────────────────────────────────
class _RecsTab extends StatelessWidget {
  final AsyncValue<List<PriorityRecommendation>> recsAsync;
  const _RecsTab({required this.recsAsync});

  @override
  Widget build(BuildContext context) {
    return recsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: _kRed))),
      data: (recs) {
        if (recs.isEmpty) {
          return const Center(
            child: Text('Adicione projetos e análises para gerar recomendações.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: recs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RecCard(rec: recs[i]),
        );
      },
    );
  }
}

class _RecCard extends StatelessWidget {
  final PriorityRecommendation rec;
  const _RecCard({required this.rec});

  Color get _typeColor {
    switch (rec.type) {
      case RecommendationType.investProject:     return _kGold;
      case RecommendationType.executeOpportunity: return _kCyan;
      case RecommendationType.runAction:         return _kPrimary;
      case RecommendationType.pauseProject:      return _kOrange;
      case RecommendationType.mitigateRisk:      return _kRed;
      case RecommendationType.quickWin:          return _kGreen;
      case RecommendationType.waste:             return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: _typeColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(rec.typeLabel,
                  style: TextStyle(color: _typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('${rec.confidence}% confiança',
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 8),
          Text(rec.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Text(rec.reason,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 6),
          Text('Impacto esperado: ${rec.expectedImpact}',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text('Dados: ${rec.dataUsed}',
            style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}
