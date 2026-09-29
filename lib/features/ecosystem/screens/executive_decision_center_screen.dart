import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ecosystem_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/decision_validation.dart';
import '../../../data/models/ecosystem_score.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/priority_recommendation.dart';
import '../../../providers/auto_bootstrap_provider.dart';
import '../../../providers/decision_validation_provider.dart';
import '../../../providers/ecosystem_intelligence_provider.dart';
import '../../../providers/ive_context_provider.dart';
import '../../../providers/opportunity_lab_provider.dart';
import '../../../providers/action_queue_provider.dart';
import '../../../data/models/ive_state.dart';
import '../../../providers/ive_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/context_copilot_widget.dart';
import '../../../shared/widgets/ive_detail_sheet.dart';
import '../../../shared/widgets/ive_explain_button.dart';
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
  if (s >= 80) return _kGreen;
  if (s >= 60) return const Color(0xFF00C853);
  if (s >= 40) return _kOrange;
  if (s >= 20) return Colors.amber;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ecosystemScoresProvider.future).then((scores) {
        if (!mounted) return;
        final risky = scores.where((s) => s.ecosystemScore < 40).toList();
        if (risky.isNotEmpty) {
          ref.read(iveProvider.notifier).showMessage(
            AppLocalizations.of(context)!.ecoIveCriticalProjects(risky.length),
            expression: IveExpression.thinking,
          );
        }
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoresAsync        = ref.watch(ecosystemScoresProvider);
    final healthAsync        = ref.watch(ecosystemHealthProvider);
    final needsBootstrapAsync = ref.watch(projectsNeedingBootstrapProvider);
    final bootstrapState     = ref.watch(autoBootstrapNotifierProvider);
    final l10n               = AppLocalizations.of(context)!;

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
        title: Text(l10n.ecoDecisionCenterTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _kPrimary,
          labelColor: _kPrimary,
          unselectedLabelColor: Colors.white38,
          tabs: [
            Tab(text: l10n.ecoTabTop5),
            Tab(text: l10n.ecoTabEcosystem),
            Tab(text: l10n.ecoTabRecommendations),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_rounded, color: Colors.white54),
            tooltip: l10n.ecoResourceAllocationTitle,
            onPressed: () => context.push(AppConstants.routeEcosystemResources),
          ),
          IconButton(
            icon: const Icon(Icons.summarize_rounded, color: Colors.white54),
            tooltip: l10n.ecoWeeklyBriefingTooltip,
            onPressed: () => context.push(AppConstants.routeEcosystemBriefing),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          // Health banner
          healthAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (h) => _HealthBanner(health: h),
          ),
          // Bootstrap banner
          needsBootstrapAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (projects) {
              if (projects.isEmpty && !bootstrapState.isRunning) {
                return const SizedBox.shrink();
              }
              return _BootstrapBanner(
                pendingCount: projects.length,
                bootstrapState: bootstrapState,
                onTap: () => context.push(AppConstants.routeIntelligenceDebug),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _Top5Tab(scoresAsync: scoresAsync),
                _EcosystemTab(scoresAsync: scoresAsync),
                const _RecsTab(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Bootstrap Banner ──────────────────────────────────────────────────────
class _BootstrapBanner extends StatelessWidget {
  final int pendingCount;
  final BootstrapState bootstrapState;
  final VoidCallback onTap;
  const _BootstrapBanner({
    required this.pendingCount,
    required this.bootstrapState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRunning = bootstrapState.isRunning;
    final label = isRunning
        ? bootstrapState.progressLabel
        : l10n.ecoBootstrapPending(pendingCount);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: _kOrange.withOpacity(0.12),
        child: Row(
          children: [
            if (isRunning)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(_kOrange),
                ),
              )
            else
              const Icon(Icons.bolt_rounded, color: _kOrange, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: _kOrange, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kOrange, size: 16),
          ],
        ),
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.ecoHealthTitle,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                Text(_healthNarrative(health, l10n),
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
                const SizedBox(height: 4),
                IveExplainButton(
                  question:   l10n.ecoIveAskHealth(health),
                  screenName: 'Decisões',
                  compact:    true,
                ),
              ],
            ),
          ),
          _HealthBar(value: health / 100, color: color),
        ],
      ),
    );
  }

  String _healthNarrative(int h, AppLocalizations l10n) {
    if (h >= 80) return l10n.ecoHealthNarrativeExcellent;
    if (h >= 60) return l10n.ecoHealthNarrativeHealthy;
    if (h >= 40) return l10n.ecoHealthNarrativeStable;
    if (h >= 20) return l10n.ecoHealthNarrativeValidating;
    return l10n.ecoHealthNarrativeReview;
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
    final l10n         = AppLocalizations.of(context)!;

    return scoresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text(l10n.ecoErrorGeneric('$e'), style: const TextStyle(color: _kRed))),
      data: (scores) {
        if (scores.isEmpty) {
          return Center(
            child: Text(l10n.ecoTop5Empty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)));
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            _Top5Section(
              title: l10n.ecoTop5ProjectsTitle,
              subtitle: l10n.ecoTop5ProjectsSubtitle,
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
                  title: l10n.ecoTop5OpportunitiesTitle,
                  subtitle: l10n.ecoTop5OpportunitiesSubtitle,
                  children: top.take(5).map((l) => _SimpleCard(
                    title: l.title,
                    subtitle: l.opportunityType,
                    score: l.finalScore,
                    badge: l.status,
                    onTap: () => IveDetailSheet.show(
                      context,
                      title: l.title,
                      emoji: '💡',
                      humanExplanation:
                          l10n.ecoOppExplanation(l.opportunityType, l.finalScore, l.status),
                      evidence: [
                        IveEvidence(emoji: '📊', label: l10n.ecoLabelType,       value: l.opportunityType),
                        IveEvidence(emoji: '🎯', label: l10n.ecoLabelFinalScore, value: '${l.finalScore}/100'),
                        IveEvidence(emoji: '📋', label: l10n.ecoLabelStatus,     value: l.status),
                      ],
                      suggestedActions: [
                        IveAction(
                          emoji: '💬',
                          label: l10n.ecoAskIveOpportunity,
                          // IVE-COMMERCIAL-TARGETED-REMEDIATION-04: mesmo
                          // padrão dos demais pontos de entrada -- sem isto,
                          // caía no CopilotContextData() vazio padrão.
                          onTap: () {
                            // IVE-COMMERCIAL-FOUNDATION-11: escopado pelo
                            // projectId da própria oportunidade, quando
                            // presente — antes, sempre pegava o projeto de
                            // maior score do sistema todo.
                            final ctx = ref.read(iveContextDataProvider(l.projectId)).valueOrNull;
                            final contextData = ctx != null
                                ? CopilotContextData.fromIveContext(ctx)
                                : const CopilotContextData();
                            showCopilotChat(
                              context,
                              screenName:     'Decisões',
                              contextData:    contextData,
                              initialMessage: l10n.ecoIveAskOpportunity(l.title, l.finalScore),
                              request: IveInteractionRequest(
                                projectId:        l.projectId,
                                sourceModule:     'ecosystem_decision_center',
                                sourceEntityType: 'opportunity',
                                sourceEntityId:   l.id,
                                operationType:    IveOperationType.ask,
                              ),
                            );
                          },
                        ),
                      ],
                      screenName: 'Decisões',
                      projectId:        l.projectId,
                      sourceEntityType: 'opportunity',
                      sourceEntityId:   l.id,
                    ),
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
                      title: l10n.ecoTop5QuickWinsTitle,
                      subtitle: l10n.ecoTop5QuickWinsSubtitle,
                      children: qw.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: l10n.ecoImpactEffort(a.impactScore, a.effortScore),
                        score: a.impactScore - a.effortScore + 50,
                        badge: a.actionType,
                        onTap: () => IveDetailSheet.show(
                          context,
                          title: a.title,
                          emoji: '⚡',
                          humanExplanation:
                              l10n.ecoQuickWinExplanation(a.impactScore, a.effortScore),
                          evidence: [
                            IveEvidence(emoji: '🎯', label: l10n.ecoLabelImpact, value: '${a.impactScore}/100'),
                            IveEvidence(emoji: '⚙️', label: l10n.ecoLabelEffort, value: '${a.effortScore}/100'),
                            IveEvidence(emoji: '📋', label: l10n.ecoLabelType,   value: a.actionType),
                          ],
                          screenName: 'Decisões',
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    _Top5Section(
                      title: l10n.ecoTop5RisksTitle,
                      subtitle: l10n.ecoTop5RisksSubtitle,
                      children: risks.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: a.status,
                        score: 100 - a.impactScore,
                        badge: l10n.ecoBadgeRisk,
                        scoreColor: _kRed,
                        onTap: () => IveDetailSheet.show(
                          context,
                          title: a.title,
                          emoji: '⚠️',
                          humanExplanation:
                              l10n.ecoRiskActionExplanation,
                          evidence: [
                            IveEvidence(emoji: '🎯', label: l10n.ecoLabelImpact, value: '${a.impactScore}/100'),
                            IveEvidence(emoji: '📋', label: l10n.ecoLabelStatus, value: a.status),
                            IveEvidence(emoji: '⚙️', label: l10n.ecoLabelType,   value: a.actionType),
                          ],
                          screenName: 'Decisões',
                        ),
                      )).toList(),
                    ),
                    const SizedBox(height: 20),
                    _Top5Section(
                      title: l10n.ecoTop5WastesTitle,
                      subtitle: l10n.ecoTop5WastesSubtitle,
                      children: wastes.take(5).map((a) => _SimpleCard(
                        title: a.title,
                        subtitle: l10n.ecoImpactEffort(a.impactScore, a.effortScore),
                        score: a.impactScore,
                        badge: l10n.ecoBadgeReview,
                        scoreColor: _kOrange,
                        onTap: () => IveDetailSheet.show(
                          context,
                          title: a.title,
                          emoji: '🗑️',
                          humanExplanation:
                              l10n.ecoWasteExplanation(a.impactScore, a.effortScore),
                          evidence: [
                            IveEvidence(emoji: '🎯', label: l10n.ecoLabelImpact, value: '${a.impactScore}/100'),
                            IveEvidence(emoji: '⚙️', label: l10n.ecoLabelEffort, value: '${a.effortScore}/100'),
                            IveEvidence(emoji: '📋', label: l10n.ecoLabelType,   value: a.actionType),
                          ],
                          screenName: 'Decisões',
                        ),
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
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(AppLocalizations.of(context)!.ecoNoItemsYet,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          )
        else
          ...children,
      ],
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final EcosystemScore score;
  const _ProjectCard({required this.score});

  void _showDetail(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    IveDetailSheet.show(
      context,
      title:            score.project.name,
      emoji:            score.recommendationEmoji,
      humanExplanation: l10n.ecoProjectExplanation(
        score.project.name,
        score.ecosystemScore,
        ecosystemVerdictLabel(score.recommendation, l10n),
      ),
      evidence: [
        IveEvidence(emoji: '🎯', label: l10n.ecoLabelOpportunity,  value: '${score.opportunityScore}/100'),
        IveEvidence(emoji: '🔗', label: l10n.ecoLabelStrategicFit, value: '${score.strategicFit}/100'),
        IveEvidence(emoji: '💰', label: l10n.ecoLabelRoiScore,     value: '${score.roiScore}/100'),
        IveEvidence(emoji: '⚡', label: l10n.ecoLabelMarket,       value: '${score.marketScore}/100'),
        IveEvidence(emoji: '🏃', label: l10n.ecoLabelExecution,    value: '${score.executionScore}/100'),
      ],
      expandedData: {
        l10n.ecoLabelMomentum:  '${score.momentumScore}/100',
        l10n.ecoLabelSynergy:   '${score.synergyScore}/100',
        l10n.ecoLabelTotalRoi:  'R\$${score.totalRoi.toStringAsFixed(0)}',
        l10n.ecoLabelEcosystem: '${score.ecosystemScore}/100',
      },
      suggestedActions: [
        IveAction(
          emoji:       '💬',
          label:       l10n.ecoAskIveImproveScore,
          description: l10n.ecoAskIveImproveScoreDesc,
          // IVE-COMMERCIAL-TARGETED-REMEDIATION-04: mesmo padrão dos demais
          // pontos de entrada -- sem isto, caía no CopilotContextData()
          // vazio padrão.
          onTap: () {
            // IVE-COMMERCIAL-FOUNDATION-11: escopado por score.project.id
            // (o projeto que este card/mensagem literalmente cita), não
            // mais o projeto de maior score do sistema todo.
            final ctx = ref.read(iveContextDataProvider(score.project.id)).valueOrNull;
            final contextData =
                ctx != null ? CopilotContextData.fromIveContext(ctx) : const CopilotContextData();
            showCopilotChat(
              context,
              screenName:     'Decisões',
              contextData:    contextData,
              initialMessage: l10n.ecoIveAskImproveProject(score.project.name, score.ecosystemScore),
              request: IveInteractionRequest(
                projectId:        score.project.id,
                sourceModule:     'ecosystem_decision_center',
                sourceEntityType: 'project',
                sourceEntityId:   score.project.id,
                operationType:    IveOperationType.ask,
              ),
            );
          },
        ),
      ],
      screenName: 'Decisões',
      projectId:        score.project.id,
      sourceEntityType: 'project',
      sourceEntityId:   score.project.id,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n  = AppLocalizations.of(context)!;
    final color = _scoreColor(score.ecosystemScore);
    return GestureDetector(
      onTap: () => _showDetail(context, ref),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text('${score.recommendationEmoji} ${ecosystemVerdictLabel(score.recommendation, l10n)}  •  ROI R\$${score.totalRoi.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(l10n.ecoShortMarket(score.marketScore),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(l10n.ecoShortFit(score.strategicFit),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(l10n.ecoShortExec(score.executionScore),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          IveExplainButton(
            question:         l10n.ecoIveAskProjectScore(score.project.name, score.ecosystemScore),
            screenName:       'Decisões',
            compact:          true,
            // IVE-COMMERCIAL-FOUNDATION-11 — antes, este botão perguntava
            // sobre ESTE projeto mas o grounding vinha do projeto de maior
            // score do sistema todo (podendo ser um projeto diferente).
            projectId:        score.project.id,
            sourceModule:     'ecosystem_decision_center',
            sourceEntityType: 'project',
            sourceEntityId:   score.project.id,
          ),
        ],
      ),
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
  final VoidCallback? onTap;
  const _SimpleCard({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.badge,
    this.scoreColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = scoreColor ?? _scoreColor(score);
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onTap != null ? color.withOpacity(0.25) : _kBorder),
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
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
          ],
        ],
      ),
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
    final l10n = AppLocalizations.of(context)!;
    return scoresAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text(l10n.ecoErrorGeneric('$e'), style: const TextStyle(color: _kRed))),
      data: (scores) {
        if (scores.isEmpty) {
          return Center(
            child: Text(l10n.ecoEcosystemEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)));
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
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
    final l10n = AppLocalizations.of(context)!;

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
                  Text('${s.recommendationEmoji} ${ecosystemVerdictLabel(s.recommendation, l10n)}',
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  _ScoreRow(label: l10n.ecoLabelMarket, value: s.marketScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: l10n.ecoLabelOpportunity, value: s.opportunityScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: l10n.ecoLabelStrategicFit, value: s.strategicFit),
                  const SizedBox(height: 4),
                  _ScoreRow(label: l10n.ecoLabelExecution, value: s.executionScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: 'ROI', value: s.roiScore),
                  const SizedBox(height: 4),
                  _ScoreRow(label: l10n.ecoLabelMomentum, value: s.momentumScore),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(l10n.ecoCardFooter(s.actionCount, s.completionRate, s.totalRoi.toStringAsFixed(0)),
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
                    Text(l10n.ecoStrengthsTitle, style: const TextStyle(color: _kGreen,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...s.strengths.map((st) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text('• $st', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )),
                    const SizedBox(height: 10),
                  ],
                  if (s.risks.isNotEmpty) ...[
                    Text(l10n.ecoRisksTitle, style: const TextStyle(color: _kOrange,
                        fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    ...s.risks.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 4),
                      child: Text('• $r', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )),
                    const SizedBox(height: 10),
                  ],
                  if (s.quickWins.isNotEmpty) ...[
                    Text(l10n.ecoQuickWinsTitle, style: const TextStyle(color: _kCyan,
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
class _RecsTab extends ConsumerWidget {
  const _RecsTab();

  static const _blockedTypes = {
    RecommendationType.investProject,
    RecommendationType.pauseProject,
    RecommendationType.executeOpportunity,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync       = ref.watch(priorityRecommendationsProvider);
    final validationAsync = ref.watch(decisionValidationMapProvider);
    final labAsync        = ref.watch(opportunityLabProvider);
    final l10n            = AppLocalizations.of(context)!;

    return recsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kPrimary)),
      error: (e, _) => Center(child: Text(l10n.ecoErrorGeneric('$e'), style: const TextStyle(color: _kRed))),
      data: (recs) {
        if (recs.isEmpty) {
          return Center(
            child: Text(l10n.ecoRecsEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54)));
        }

        final validationMap = validationAsync.value ?? {};
        final labItems      = labAsync.value ?? [];

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          itemCount: recs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final rec = recs[i];

            if (_blockedTypes.contains(rec.type)) {
              DecisionValidation? validation;
              if (rec.type == RecommendationType.executeOpportunity) {
                final matches = labItems.where((l) => l.id == rec.entityId);
                final labItem = matches.isEmpty ? null : matches.first;
                if (labItem?.projectId != null) {
                  validation = validationMap[labItem!.projectId!];
                }
              } else {
                validation = validationMap[rec.entityId];
              }

              if (validation != null && validation.isBlocked) {
                return _ValidationGateCard(rec: rec, validation: validation);
              }
            }

            return _RecCard(rec: rec);
          },
        );
      },
    );
  }
}

class _ValidationGateCard extends StatelessWidget {
  final PriorityRecommendation rec;
  final DecisionValidation validation;
  const _ValidationGateCard({required this.rec, required this.validation});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.ecoBlockedBadge,
                    style: const TextStyle(color: _kOrange, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(recommendationTypeLabel(rec.type, l10n),
                    style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(rec.title,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.white38)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOrange.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kOrange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ ${validation.blockMessage(l10n)}',
                    style: const TextStyle(
                        color: _kOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _GateMetricRow(label: l10n.ecoGateKnowledgeCoverage, value: validation.coverageLabel(l10n)),
                _GateMetricRow(label: l10n.ecoGateLearningScore, value: validation.learningLabel(l10n)),
                _GateMetricRow(label: l10n.ecoGateIntelligenceProfile, value: validation.profileLabel(l10n)),
                const Divider(color: Colors.white12, height: 16),
                _GateMetricRow(label: l10n.ecoGateDocuments, value: '${validation.documentCount}'),
                _GateMetricRow(label: l10n.ecoGateIndexing, value: validation.indexingStatus(l10n)),
                _GateMetricRow(label: l10n.ecoGateAssets, value: '${validation.assetCount}'),
                _GateMetricRow(label: l10n.ecoGateOpportunities, value: '${validation.opportunityCount}'),
                if (validation.blockReasons.isNotEmpty) ...[
                  const Divider(color: Colors.white12, height: 16),
                  Text(l10n.ecoGateBlockReasons,
                      style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  const SizedBox(height: 4),
                  ...validation.blockReasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• $r',
                            style: const TextStyle(color: Colors.white38, fontSize: 10)),
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GateMetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _GateMetricRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

class _RecCard extends ConsumerWidget {
  final PriorityRecommendation rec;
  const _RecCard({required this.rec});

  Color get _typeColor {
    switch (rec.type) {
      case RecommendationType.investProject:      return _kGold;
      case RecommendationType.executeOpportunity: return _kCyan;
      case RecommendationType.runAction:          return _kPrimary;
      case RecommendationType.pauseProject:       return _kOrange;
      case RecommendationType.mitigateRisk:       return _kRed;
      case RecommendationType.quickWin:           return _kGreen;
      case RecommendationType.waste:              return Colors.grey;
    }
  }

  String get _typeEmoji {
    switch (rec.type) {
      case RecommendationType.investProject:      return '💰';
      case RecommendationType.executeOpportunity: return '🚀';
      case RecommendationType.runAction:          return '⚡';
      case RecommendationType.pauseProject:       return '⏸️';
      case RecommendationType.mitigateRisk:       return '🛡️';
      case RecommendationType.quickWin:           return '✅';
      case RecommendationType.waste:              return '🗑️';
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    IveDetailSheet.show(
      context,
      title:            rec.title,
      emoji:            _typeEmoji,
      humanExplanation: '${rec.reason}\n\n${l10n.ecoExpectedImpact(rec.expectedImpact)}',
      evidence: [
        IveEvidence(emoji: '📊', label: l10n.ecoLabelType,       value: recommendationTypeLabel(rec.type, l10n)),
        IveEvidence(emoji: '🎯', label: l10n.ecoLabelConfidence, value: '${rec.confidence}%'),
        IveEvidence(emoji: '💡', label: l10n.ecoLabelDataUsed,   value: rec.dataUsed),
      ],
      suggestedActions: [
        IveAction(
          emoji: '💬',
          label: l10n.ecoAskIveRecommendation,
          // IVE-COMMERCIAL-TARGETED-REMEDIATION-04: mesmo padrão dos demais
          // pontos de entrada -- sem isto, caía no CopilotContextData()
          // vazio padrão.
          onTap: () {
            // IVE-COMMERCIAL-FOUNDATION-11: PriorityRecommendation não tem
            // um campo project_id próprio (apenas entityId/entityName
            // genéricos, cujo significado depende de `rec.type` — pode ser
            // um projeto, uma oportunidade ou uma ação). Sem uma forma
            // segura de derivar qual, mantém projectId: null (mesmo
            // comportamento ecosystem-wide de antes) em vez de arriscar
            // escopar para um projeto errado. Adicionar um project_id
            // real ao modelo de recomendação é trabalho de Fase D (ver
            // docs/commercial/COMMERCIAL_PRODUCT_ARCHITECTURE.md §11).
            final ctx = ref.read(iveContextDataProvider(null)).valueOrNull;
            final contextData =
                ctx != null ? CopilotContextData.fromIveContext(ctx) : const CopilotContextData();
            showCopilotChat(
              context,
              screenName:     'Decisões',
              contextData:    contextData,
              initialMessage: l10n.ecoIveAskRecommendation(rec.title),
              request: IveInteractionRequest(
                sourceModule:     'ecosystem_decision_center',
                sourceEntityType: 'recommendation',
                sourceEntityId:   rec.entityId,
                operationType:    IveOperationType.ask,
              ),
            );
          },
        ),
      ],
      screenName: 'Decisões',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => _showDetail(context, ref),
      child: Container(
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
                child: Text(recommendationTypeLabel(rec.type, l10n),
                  style: TextStyle(color: _typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(l10n.ecoConfidencePct(rec.confidence),
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 14),
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
          Text(l10n.ecoExpectedImpact(rec.expectedImpact),
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
          Text(l10n.ecoDataPrefix(rec.dataUsed),
            style: const TextStyle(color: Colors.white24, fontSize: 10)),
        ],
      ),
      ),
    );
  }
}
