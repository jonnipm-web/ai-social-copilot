import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/ai_enum_labels.dart';
import '../../../data/models/competitor.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/content_cluster.dart';
import '../../../data/models/gap_analysis.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/market_analysis.dart';
import '../../../data/models/niche_ranking.dart';
import '../../../data/models/opportunity.dart';
import '../../../data/models/revenue_plan.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/ive_context_provider.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../shared/widgets/context_copilot_widget.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import '../../../shared/widgets/translated_content_notice.dart';

// ── Colors ───────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF0F0F1A);
const _kCard    = Color(0xFF1A1A2E);
const _kPrimary = Color(0xFF6C63FF);
const _kGreen   = Color(0xFF4CAF50);
const _kOrange  = Color(0xFFFF9800);
const _kRed     = Color(0xFFF44336);
const _kGold    = Color(0xFFFFD700);
const _kCyan    = Color(0xFF00BCD4);
const _kPink    = Color(0xFFE91E63);

// ── Helpers ──────────────────────────────────────────────────────────────────
Color _scoreColor(int score) {
  if (score >= 80) return _kGreen;
  if (score >= 60) return _kOrange;
  return _kRed;
}

String _scoreLabel(AppLocalizations l10n, int score) {
  if (score >= 80) return l10n.miHubScoreLevelHigh;
  if (score >= 60) return l10n.miHubScoreLevelMedium;
  return l10n.miHubScoreLevelLow;
}

String _formatBRL(double value) {
  if (value <= 0) return 'N/A';
  if (value >= 1000000) return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return 'R\$ ${(value / 1000).toStringAsFixed(0)}k';
  return 'R\$ ${value.toStringAsFixed(0)}';
}

String _routeFor(String template, String id) =>
    template.replaceFirst(':id', id);

// ════════════════════════════════════════════════════════════════════════════
// Main Screen
// ════════════════════════════════════════════════════════════════════════════
class MarketIntelligenceHubScreen extends ConsumerStatefulWidget {
  const MarketIntelligenceHubScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<MarketIntelligenceHubScreen> createState() => _HubState();
}

class _HubState extends ConsumerState<MarketIntelligenceHubScreen> {
  bool _roiSaving = false;
  bool _roiSaved  = false;

  Future<void> _saveToRoi(
    MarketAnalysis analysis,
    List<Opportunity> opportunities,
    RevenuePlan? plan,
  ) async {
    setState(() => _roiSaving = true);
    // R16 — notes are persisted: build them in the CURRENT UI language.
    final noteL10n = AppLocalizations.of(context)!;
    try {
      final svc = ref.read(roiMetricServiceProvider);

      if (analysis.opportunityScore > 0) {
        await svc.create(
          metricType:  'opportunity_score',
          metricValue: analysis.opportunityScore.toDouble(),
          notes:       'Market Intelligence: ${analysis.input}',
        );
      }

      if (opportunities.isNotEmpty) {
        final avg = opportunities
                .map((o) => o.opportunityScore)
                .reduce((a, b) => a + b) /
            opportunities.length;
        await svc.create(
          metricType:  'avg_opportunity_score',
          metricValue: avg,
          notes:       noteL10n.uxMiRoiNoteOpportunities(
              '${opportunities.length}', analysis.input),
        );
      }

      final monthly = plan?.monthlyModerate ?? analysis.revenueMonthlyMax;
      if (monthly > 0) {
        await svc.create(
          metricType:  'revenue_potential',
          metricValue: monthly,
          notes:       'Market Intelligence: ${analysis.niche ?? analysis.input}',
        );
      }

      ref.invalidate(roiMetricsProvider);
      if (mounted) setState(() { _roiSaved = true; _roiSaving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _roiSaving = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.miHubRoiSaveError(extractErrorMessage(e, l10n))), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final analysisAsync      = ref.watch(marketAnalysisByIdProvider(widget.analysisId));
    final competitorsAsync   = ref.watch(competitorsByAnalysisProvider(widget.analysisId));
    final gapAsync           = ref.watch(gapAnalysisByAnalysisProvider(widget.analysisId));
    final opportunitiesAsync = ref.watch(opportunitiesByAnalysisProvider(widget.analysisId));
    final revenuePlanAsync   = ref.watch(revenuePlanByAnalysisProvider(widget.analysisId));
    // COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-02) — Niches and Content
    // Cluster previously had no dedicated Hub card at all (only the
    // generic icon+label nav tile), which is exactly the "giant low-
    // information card" the Owner flagged physically.
    final nichesAsync        = ref.watch(nichesByAnalysisProvider(widget.analysisId));
    final contentClusterAsync = ref.watch(contentClusterByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeMarketIntelligence),
        ),
        title: Text(
          l10n.miHubAppBarTitle,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // IVE-EXPERIENCE-V1-06 (Section 20) — first (and only, per mission
          // instruction to not blindly wire all six submodules) contextual
          // IVE entry point for Market Intelligence: the hub, which already
          // aggregates score/competitors/gap/opportunities/revenue for one
          // analysis — a cleaner bounded entry point than repeating this on
          // every submodule screen. Uses the analysis's own projectId when
          // it has one (MarketAnalysis.projectId already exists on the
          // model) rather than assuming project-agnostic.
          if (analysisAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white54),
              tooltip: l10n.miHubCompareWithIveTooltip,
              onPressed: () {
                final analysis = analysisAsync.value!;
                final ctx = ref.read(iveContextDataProvider(analysis.projectId)).valueOrNull;
                final contextData =
                    ctx != null ? CopilotContextData.fromIveContext(ctx) : const CopilotContextData();
                showCopilotChat(
                  context,
                  screenName: 'Market Intelligence', // canonical key
                  contextData: contextData,
                  initialMessage: l10n.miHubCompareInitialMessage(analysis.niche ?? analysis.input),
                  request: IveInteractionRequest(
                    projectId:        analysis.projectId,
                    sourceModule:     'market_intelligence',
                    sourceEntityType: 'market_analysis',
                    sourceEntityId:   analysis.id,
                    operationType:    IveOperationType.compare,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: l10n.miHubReloadTooltip,
            onPressed: () {
              setState(() => _roiSaved = false);
              ref.invalidate(marketAnalysisByIdProvider(widget.analysisId));
              ref.invalidate(competitorsByAnalysisProvider(widget.analysisId));
              ref.invalidate(gapAnalysisByAnalysisProvider(widget.analysisId));
              ref.invalidate(opportunitiesByAnalysisProvider(widget.analysisId));
              ref.invalidate(revenuePlanByAnalysisProvider(widget.analysisId));
              ref.invalidate(nichesByAnalysisProvider(widget.analysisId));
              ref.invalidate(contentClusterByAnalysisProvider(widget.analysisId));
            },
          ),
        ],
      ),
      body: analysisAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _kPrimary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: _kRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  l10n.miHubLoadError(extractErrorMessage(e, l10n)),
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (analysis) {
          final competitors = (competitorsAsync.value ?? <Competitor>[])
              .toList()
              ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
          final gap   = gapAsync.value;
          final opps  = (opportunitiesAsync.value ?? <Opportunity>[])
              .toList()
              ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
          final plan    = revenuePlanAsync.value;
          final niches  = nichesAsync.value ?? <NicheRanking>[];
          final cluster = contentClusterAsync.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TranslatedContentNotice(localizedFrom: analysis.localizedFrom),
                // M1 — Executive Score Card
                _ExecScoreCard(analysis: analysis),
                const SizedBox(height: 12),

                // M2 + M7 — Revenue Potential & Vale a Pena Investir?
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _RevenuePotentialCard(analysis: analysis, plan: plan)),
                      const SizedBox(width: 10),
                      Expanded(child: _InvestmentCard(analysis: analysis)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // M6 — Executive Priority Engine
                _PriorityActionsCard(analysis: analysis),
                const SizedBox(height: 12),

                // M3 — Competitor Discovery Visual
                _CompetitorRankingCard(
                  competitors: competitors,
                  isLoading:   competitorsAsync.isLoading,
                  analysisId:  widget.analysisId,
                ),
                const SizedBox(height: 12),

                // M4 — Gap Summary
                _GapSummaryCard(
                  gap:        gap,
                  isLoading:  gapAsync.isLoading,
                  analysisId: widget.analysisId,
                ),
                const SizedBox(height: 12),

                // M5 — Opportunities Panel
                _OpportunitiesCard(
                  opportunities: opps,
                  isLoading:     opportunitiesAsync.isLoading,
                  analysisId:    widget.analysisId,
                ),
                const SizedBox(height: 12),

                // COMMERCIAL-V1-PHYSICAL-QA-RECOVERY (PQ-02) — the 3
                // modules that previously had ONLY the generic icon+label
                // nav tile (no summary at all) now get the same
                // information-first card pattern as Competitors/Gap/
                // Opportunities above. The old _ModuleNavGrid is removed
                // entirely: every module now has its own card with a
                // real "view all"/navigate CTA, so a separate icon-grid
                // nav section was redundant chrome between real content.
                _NicheSummaryCard(
                  niches:     niches,
                  isLoading:  nichesAsync.isLoading,
                  analysisId: widget.analysisId,
                ),
                const SizedBox(height: 12),

                _ContentClusterSummaryCard(
                  cluster:    cluster,
                  isLoading:  contentClusterAsync.isLoading,
                  analysisId: widget.analysisId,
                ),
                const SizedBox(height: 12),

                _RevenuePlannerSummaryCard(
                  plan:       plan,
                  isLoading:  revenuePlanAsync.isLoading,
                  analysisId: widget.analysisId,
                ),
                const SizedBox(height: 12),

                // M8 — ROI Tracker Integration
                _RoiIntegrationCard(
                  analysis:      analysis,
                  opportunities: opps,
                  plan:          plan,
                  isSaving:      _roiSaving,
                  isSaved:       _roiSaved,
                  onSave: () => _saveToRoi(analysis, opps, plan),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M1 — Executive Score Card
// ════════════════════════════════════════════════════════════════════════════
class _ExecScoreCard extends StatelessWidget {
  const _ExecScoreCard({required this.analysis});
  final MarketAnalysis analysis;

  String _desc(AppLocalizations l10n) {
    final s = analysis.opportunityScore;
    if (s >= 80) return l10n.miHubDescHigh;
    if (s >= 60) return l10n.miHubDescMedium;
    return l10n.miHubDescLow;
  }

  String _rec(AppLocalizations l10n) {
    final s = analysis.opportunityScore;
    if (s >= 80) return l10n.miHubPriorityHigh;
    if (s >= 60) return l10n.miHubPriorityMedium;
    return l10n.miHubPriorityLow;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final score = analysis.opportunityScore;
    final color = _scoreColor(score);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_kCard, color.withOpacity(0.10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.miHubOpportunityScoreLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              if (analysis.niche != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kPrimary.withOpacity(0.35)),
                    ),
                    child: Text(
                      analysis.niche!,
                      style: const TextStyle(
                          color: _kPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // COMMERCIAL-V1-UX-RECONCILIATION (mobile overflow fix) — a fixed
          // horizontal Row(score, Spacer, context column) overflowed by
          // ~136px at a 390px viewport (confirmed by
          // test/features/market_intelligence/market_intelligence_scroll_test.dart's
          // RenderFlex assertion in debug/test mode; silently clipped
          // content in release since Flutter strips that assert there).
          // LayoutBuilder switches to a stacked Column below a breakpoint
          // instead of forcing the same horizontal layout into less
          // width — the score also shrinks so it never dominates a narrow
          // card on its own.
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              final scoreRow = Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: isNarrow ? 48 : 68,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/100',
                      style: TextStyle(
                        fontSize: isNarrow ? 16 : 20,
                        fontWeight: FontWeight.w300,
                        color: color.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],
              );
              final contextColumn = Column(
                crossAxisAlignment:
                    isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isNarrow ? double.infinity : 140),
                    child: Text(
                      analysis.input,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: isNarrow ? TextAlign.start : TextAlign.end,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _rec(l10n),
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    scoreRow,
                    const SizedBox(height: 10),
                    contextColumn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  scoreRow,
                  const Spacer(),
                  contextColumn,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ScoreBar(label: l10n.miHubScoreSeo,          score: analysis.scoreSeo),
              const SizedBox(width: 8),
              _ScoreBar(label: l10n.miHubScoreMonetization, score: analysis.scoreMonetization),
              const SizedBox(width: 8),
              _ScoreBar(label: l10n.miHubScoreCompetition,  score: analysis.scoreCompetition),
              const SizedBox(width: 8),
              _ScoreBar(label: l10n.miHubScoreGrowth,       score: analysis.scoreGrowth),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _desc(l10n),
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.score});
  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final c = _scoreColor(score);
    return Expanded(
      child: Column(
        children: [
          Text('$score',
              style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(c),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M2 — Revenue Potential Card
// ════════════════════════════════════════════════════════════════════════════
class _RevenuePotentialCard extends StatelessWidget {
  const _RevenuePotentialCard({required this.analysis, this.plan});
  final MarketAnalysis analysis;
  final RevenuePlan? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final minVal  = plan?.monthlyConservative ?? analysis.revenueMonthlyMin;
    final maxVal  = plan?.monthlyAggressive   ?? analysis.revenueMonthlyMax;
    final months  = analysis.monthsToRevenue;
    final conf    = plan != null ? 88 : analysis.revenueConfidence;
    final hasData = minVal > 0 || maxVal > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money_rounded, color: _kCyan, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.miHubRevenuePotentialTitle,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData) ...[
            const Icon(Icons.bar_chart_rounded, color: Colors.white24, size: 28),
            const SizedBox(height: 6),
            Text(
              l10n.miHubRevenueNoDataHint,
              style: const TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ] else ...[
            Text(
              minVal > 0
                  ? l10n.miHubRevenueRangeMonthly(_formatBRL(minVal), _formatBRL(maxVal))
                  : l10n.miHubRevenueSingleMonthly(_formatBRL(maxVal)),
              style: const TextStyle(
                  color: _kCyan, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
            ),
            if (plan != null) ...[
              const SizedBox(height: 4),
              Text(
                l10n.miHubRevenueAnnual(_formatBRL(plan!.annualModerate)),
                style: TextStyle(color: _kCyan.withOpacity(0.6), fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            _InfoRow2(icon: Icons.timer_rounded,   label: l10n.miHubLabelDeadline,   value: l10n.miHubMonthsValue(months)),
            const SizedBox(height: 6),
            _InfoRow2(icon: Icons.verified_rounded, label: l10n.miHubLabelConfidence, value: '$conf%'),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M7 — Vale a Pena Investir?
// ════════════════════════════════════════════════════════════════════════════
class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.analysis});
  final MarketAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final rec   = analysis.investmentRecommendation;
    final score = analysis.investmentScore;
    final just  = analysis.investmentJustification;
    final verdict = aiInvestmentVerdict(rec);
    final color = verdict == AiInvestmentVerdict.yes
        ? _kGreen
        : verdict == AiInvestmentVerdict.no ? _kRed : _kOrange;
    final icon  = verdict == AiInvestmentVerdict.yes
        ? Icons.thumb_up_alt_rounded
        : verdict == AiInvestmentVerdict.no
            ? Icons.thumb_down_alt_rounded
            : Icons.thumbs_up_down_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.miHubInvestmentTitle,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 8),
              Text(
                aiInvestmentRecommendationLabel(rec, l10n),
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.miHubInvestmentScoreLabel(score),
              style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          if (just.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              just,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11, height: 1.5),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M6 — Executive Priority Engine
// ════════════════════════════════════════════════════════════════════════════
class _PriorityActionsCard extends StatelessWidget {
  const _PriorityActionsCard({required this.analysis});
  final MarketAnalysis analysis;

  Color _impactColor(String v) {
    final level = aiLevel(v);
    if (level == AiLevel.high || level == AiLevel.critical) return _kGreen;
    if (level == AiLevel.medium) return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = analysis.priorityActions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.miHubNextActionsTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...actions.asMap().entries.map((e) {
            final action   = e.value;
            final name     = action['action']       as String? ?? '';
            final impact   = action['impact']       as String? ?? 'Médio';
            final effort   = action['effort']       as String? ?? 'Médio';
            final roi      = action['roi_expected'] as String? ?? '';
            final priority = action['priority']     as int?    ?? (e.key + 1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kPrimary.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kPrimary.withOpacity(0.4)),
                    ),
                    child: Text(
                      '$priority',
                      style: const TextStyle(
                          color: _kPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _Badge(l10n.miHubBadgeImpact(aiLevelLabel(impact, l10n)), _impactColor(impact)),
                            _Badge(l10n.miHubBadgeEffort(aiLevelLabel(effort, l10n)),  Colors.white38),
                            if (roi.isNotEmpty) _Badge(l10n.miHubBadgeRoi(roi), _kCyan),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M3 — Competitor Discovery Visual
// ════════════════════════════════════════════════════════════════════════════
class _CompetitorRankingCard extends StatelessWidget {
  const _CompetitorRankingCard({
    required this.competitors,
    required this.isLoading,
    required this.analysisId,
  });
  final List<Competitor> competitors;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final top   = competitors.take(5).toList();
    final route = _routeFor(
        AppConstants.routeMarketIntelligenceCompetitors, analysisId);

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
              const Icon(Icons.people_alt_rounded, color: _kOrange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubCompetitorsTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubCompetitorsViewAll,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (top.isEmpty)
            _EmptyState(
              icon:        Icons.manage_search_rounded,
              message:     l10n.miHubCompetitorsEmptyMessage,
              buttonLabel: l10n.miHubCompetitorsEmptyCta,
              onTap:       () => context.push(route),
            )
          else ...[
            Row(
              children: [
                Expanded(flex: 4, child: _TH(l10n.miHubThCompetitor)),
                Expanded(flex: 2, child: _TH(l10n.miHubThSimilarity)),
                Expanded(flex: 2, child: _TH(l10n.miHubThAuthority)),
                Expanded(flex: 2, child: _TH(l10n.miHubThScore)),
              ],
            ),
            const Divider(color: Colors.white12, height: 14),
            ...top.asMap().entries.map((e) {
              final idx = e.key;
              final c   = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            margin: const EdgeInsets.only(right: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: idx == 0
                                  ? _kGold.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: idx == 0 ? _kGold : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (c.url.isNotEmpty)
                                  Text(
                                    c.url,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: _ScoreTxt(c.similarityScore)),
                    Expanded(flex: 2, child: _ScoreTxt(c.authorityScore)),
                    Expanded(flex: 2, child: _ScoreTxt(c.overallScore)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => context.push(route),
              icon:  const Icon(Icons.search_rounded, size: 14),
              label: Text(l10n.miHubAnalyzeCompetitorCta, style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOrange,
                side: const BorderSide(color: _kOrange, width: 0.8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M4 — Gap Summary
// ════════════════════════════════════════════════════════════════════════════
class _GapSummaryCard extends StatelessWidget {
  const _GapSummaryCard({
    required this.gap,
    required this.isLoading,
    required this.analysisId,
  });
  final GapAnalysis? gap;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final route =
        _routeFor(AppConstants.routeMarketIntelligenceGaps, analysisId);

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
              const Icon(Icons.find_in_page_rounded, color: _kGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubGapSummaryTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubGapDetailCta,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (gap == null)
            _EmptyState(
              icon:        Icons.analytics_outlined,
              message:     l10n.miHubGapEmptyMessage,
              buttonLabel: l10n.miHubGapEmptyCta,
              onTap:       () => context.push(route),
            )
          else ...[
            _GapRow(Icons.search_rounded,         l10n.miHubGapSeo,          gap!.seoGaps,          _kCyan),
            _GapRow(Icons.article_rounded,        l10n.miHubGapContent,      gap!.contentGaps,      _kOrange),
            _GapRow(Icons.verified_user_rounded,  l10n.miHubGapAuthority,    gap!.authorityGaps,    _kPrimary),
            _GapRow(Icons.attach_money_rounded,   l10n.miHubGapMonetization, gap!.monetizationGaps, _kGreen),
            _GapRow(Icons.inventory_2_rounded,    l10n.miHubGapProduct,      gap!.productGaps,      _kGold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.miHubGapTotal(gap!.totalGaps),
                style: const TextStyle(
                    color: _kGold, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow(this.icon, this.label, this.items, this.color);
  final IconData icon;
  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      items.first,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M5 — Opportunities Panel
// ════════════════════════════════════════════════════════════════════════════
class _OpportunitiesCard extends StatelessWidget {
  const _OpportunitiesCard({
    required this.opportunities,
    required this.isLoading,
    required this.analysisId,
  });
  final List<Opportunity> opportunities;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final top   = opportunities.take(3).toList();
    final route = _routeFor(
        AppConstants.routeMarketIntelligenceOpportunities, analysisId);

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
              const Icon(Icons.lightbulb_rounded, color: _kGold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubOpportunitiesTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubOpportunitiesViewAll,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (top.isEmpty)
            _EmptyState(
              icon:        Icons.lightbulb_outline_rounded,
              message:     l10n.miHubOpportunitiesEmptyMessage,
              buttonLabel: l10n.miHubOpportunitiesEmptyCta,
              onTap:       () => context.push(route),
            )
          else
            ...top.map((o) {
              final c = _scoreColor(o.opportunityScore);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kGold.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${o.opportunityScore}',
                                style: TextStyle(
                                    color: c,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (o.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          o.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (o.timeframe.isNotEmpty) _Badge(aiTimeframeLabel(o.timeframe, l10n), _kCyan),
                          if (o.effort.isNotEmpty)
                            _Badge(l10n.miHubOppEffortBadge(aiLevelLabel(o.effort, l10n)), Colors.white38),
                          _Badge(
                            l10n.miHubOppRevenueBadge(_scoreLabel(l10n, o.monetizationScore)),
                            _kGreen,
                          ),
                          _Badge(
                            l10n.miHubOppDifficultyBadge(_scoreLabel(l10n, 100 - o.difficultyScore)),
                            _kOrange,
                          ),
                        ],
                      ),
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

// ════════════════════════════════════════════════════════════════════════════
// Niche Summary — previously had no dedicated card, only the removed
// generic icon+label nav tile (COMMERCIAL-V1-PHYSICAL-QA-RECOVERY PQ-02).
// ════════════════════════════════════════════════════════════════════════════
class _NicheSummaryCard extends StatelessWidget {
  const _NicheSummaryCard({
    required this.niches,
    required this.isLoading,
    required this.analysisId,
  });
  final List<NicheRanking> niches;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context)!;
    final route  = _routeFor(AppConstants.routeMarketIntelligenceNiches, analysisId);
    final sorted = niches.toList()..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    final best   = sorted.isEmpty ? null : sorted.first;

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
              const Icon(Icons.trending_up_rounded, color: _kCyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubNichesSummaryTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubNichesViewAll,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (best == null)
            _EmptyState(
              icon:        Icons.trending_up_rounded,
              message:     l10n.miHubNichesEmptyMessage,
              buttonLabel: l10n.miHubNichesEmptyCta,
              onTap:       () => context.push(route),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kCyan.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(best.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(l10n.miHubNichesBestCandidateLabel,
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ScoreTxt(best.overallScore),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.miHubNichesCount(niches.length),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Content Cluster Summary — previously had no dedicated card
// (COMMERCIAL-V1-PHYSICAL-QA-RECOVERY PQ-02).
// ════════════════════════════════════════════════════════════════════════════
class _ContentClusterSummaryCard extends StatelessWidget {
  const _ContentClusterSummaryCard({
    required this.cluster,
    required this.isLoading,
    required this.analysisId,
  });
  final ContentCluster? cluster;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final route = _routeFor(AppConstants.routeMarketIntelligenceCluster, analysisId);

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
              const Icon(Icons.account_tree_rounded, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubClusterSummaryTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubClusterViewAll,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (cluster == null)
            _EmptyState(
              icon:        Icons.account_tree_rounded,
              message:     l10n.miHubClusterEmptyMessage,
              buttonLabel: l10n.miHubClusterEmptyCta,
              onTap:       () => context.push(route),
            )
          else ...[
            Text(
              cluster!.mainKeyword,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(l10n.miHubClusterCountBadge(cluster!.clusters.length), _kPrimary),
                _Badge(l10n.miHubClusterArticlesBadge(cluster!.articles.length), _kCyan),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Revenue Planner Summary — previously had no dedicated card; distinct
// from _RevenuePotentialCard above, which frames "is this worth
// investing in" using the market analysis's own projection, not the
// Revenue Planner module's persisted plan specifically
// (COMMERCIAL-V1-PHYSICAL-QA-RECOVERY PQ-02).
// ════════════════════════════════════════════════════════════════════════════
class _RevenuePlannerSummaryCard extends StatelessWidget {
  const _RevenuePlannerSummaryCard({
    required this.plan,
    required this.isLoading,
    required this.analysisId,
  });
  final RevenuePlan? plan;
  final bool isLoading;
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context)!;
    final route = _routeFor(AppConstants.routeMarketIntelligenceRevenue, analysisId);

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
              const Icon(Icons.bar_chart_rounded, color: _kPink, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.miHubRevenuePlannerSummaryTitle,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(l10n.miHubRevenuePlannerViewAll,
                    style: const TextStyle(color: _kPrimary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (plan == null)
            _EmptyState(
              icon:        Icons.bar_chart_rounded,
              message:     l10n.miHubRevenuePlannerEmptyMessage,
              buttonLabel: l10n.miHubRevenuePlannerEmptyCta,
              onTap:       () => context.push(route),
            )
          else ...[
            Text(
              l10n.miHubRevenuePlannerMonthly(_formatBRL(plan!.monthlyModerate)),
              style: const TextStyle(color: _kPink, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(l10n.miHubRevenueMilestonesBadge(plan!.milestones.length), _kPink),
                _Badge(l10n.miHubRevenueSourcesBadge(plan!.revenueSources.length), _kCyan),
              ],
            ),
            if (plan!.milestones.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow2(
                icon:  Icons.flag_rounded,
                label: l10n.miHubRevenueNextMilestoneLabel,
                value: plan!.milestones.first['title']?.toString() ?? '',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// M8 — ROI Tracker Integration
// ════════════════════════════════════════════════════════════════════════════
class _RoiIntegrationCard extends StatelessWidget {
  const _RoiIntegrationCard({
    required this.analysis,
    required this.opportunities,
    required this.plan,
    required this.isSaving,
    required this.isSaved,
    required this.onSave,
  });
  final MarketAnalysis analysis;
  final List<Opportunity> opportunities;
  final RevenuePlan? plan;
  final bool isSaving;
  final bool isSaved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final avgScore = opportunities.isEmpty
        ? 0.0
        : opportunities
                .map((o) => o.opportunityScore)
                .reduce((a, b) => a + b) /
            opportunities.length;
    final revenue = plan?.monthlyModerate ?? analysis.revenueMonthlyMax;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: _kGreen, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.miHubRoiTrackerTitle,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _RoiStat(
                l10n.miHubRoiOpportunityScoreLabel,
                '${analysis.opportunityScore}/100',
                _scoreColor(analysis.opportunityScore),
              ),
              _RoiStat(l10n.miHubRoiOpportunitiesLabel, '${opportunities.length}', _kGold),
              if (avgScore > 0)
                _RoiStat(l10n.miHubRoiAvgScoreLabel, '${avgScore.round()}', _kCyan),
              if (revenue > 0)
                _RoiStat(l10n.miHubRoiRevenueLabel, _formatBRL(revenue), _kGreen),
            ],
          ),
          const SizedBox(height: 16),
          if (isSaved)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    l10n.miHubRoiSavedMessage,
                    style: const TextStyle(
                        color: _kGreen, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_chart_rounded, size: 18),
                label: Text(
                  isSaving ? l10n.miHubRoiSavingCta : l10n.miHubRoiSaveCta,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kGreen.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Shared helper widgets
// ════════════════════════════════════════════════════════════════════════════
class _InfoRow2 extends StatelessWidget {
  const _InfoRow2({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white38),
        const SizedBox(width: 4),
        Flexible(
          child: Text('$label: ',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ),
        Flexible(
          child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _TH extends StatelessWidget {
  const _TH(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600));
  }
}

class _ScoreTxt extends StatelessWidget {
  const _ScoreTxt(this.score);
  final int score;

  @override
  Widget build(BuildContext context) {
    return Text('$score',
        style: TextStyle(
            color: _scoreColor(score), fontSize: 12, fontWeight: FontWeight.w600));
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });
  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: Colors.white24, size: 32),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onTap,
            child: Text(buttonLabel,
                style: const TextStyle(color: _kPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _RoiStat extends StatelessWidget {
  const _RoiStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
