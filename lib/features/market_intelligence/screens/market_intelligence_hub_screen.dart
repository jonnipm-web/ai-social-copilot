import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/competitor.dart';
import '../../../data/models/gap_analysis.dart';
import '../../../data/models/market_analysis.dart';
import '../../../data/models/opportunity.dart';
import '../../../data/models/revenue_plan.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../providers/roi_metric_provider.dart';

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

String _scoreLabel(int score) {
  if (score >= 80) return 'Alto';
  if (score >= 60) return 'Médio';
  return 'Baixo';
}

String _formatBRL(double value) {
  if (value <= 0) return 'N/A';
  if (value >= 1000000) return 'R\$ ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return 'R\$ ${(value / 1000).toStringAsFixed(0)}k';
  return 'R\$ ${value.toStringAsFixed(0)}';
}

String _routeFor(String template, String id) =>
    template.replaceFirst(':id', id);

// ── Module descriptor ─────────────────────────────────────────────────────────
class _Mod {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _Mod(this.icon, this.label, this.route, this.color);
}

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
          notes:       '${opportunities.length} oportunidades — ${analysis.input}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao registrar: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analysisAsync      = ref.watch(marketAnalysisByIdProvider(widget.analysisId));
    final competitorsAsync   = ref.watch(competitorsByAnalysisProvider(widget.analysisId));
    final gapAsync           = ref.watch(gapAnalysisByAnalysisProvider(widget.analysisId));
    final opportunitiesAsync = ref.watch(opportunitiesByAnalysisProvider(widget.analysisId));
    final revenuePlanAsync   = ref.watch(revenuePlanByAnalysisProvider(widget.analysisId));

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
        title: const Text(
          'Inteligência de Mercado',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Recarregar dados',
            onPressed: () {
              setState(() => _roiSaved = false);
              ref.invalidate(marketAnalysisByIdProvider(widget.analysisId));
              ref.invalidate(competitorsByAnalysisProvider(widget.analysisId));
              ref.invalidate(gapAnalysisByAnalysisProvider(widget.analysisId));
              ref.invalidate(opportunitiesByAnalysisProvider(widget.analysisId));
              ref.invalidate(revenuePlanByAnalysisProvider(widget.analysisId));
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
                  'Erro ao carregar análise:\n$e',
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (analysis) {
          final competitors = [...(competitorsAsync.value ?? [])]
            ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
          final gap   = gapAsync.value;
          final opps  = [...(opportunitiesAsync.value ?? [])]
            ..sort((a, b) => b.opportunityScore.compareTo(a.opportunityScore));
          final plan  = revenuePlanAsync.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Module navigation grid
                _ModuleNavGrid(analysisId: widget.analysisId),
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

  String _desc() {
    final s = analysis.opportunityScore;
    if (s >= 80) {
      return 'Alto potencial de crescimento. Monetização forte. Concorrência administrável.';
    }
    if (s >= 60) {
      return 'Potencial moderado. Mercado em crescimento. Avalie seus diferenciais.';
    }
    return 'Potencial limitado. Mercado saturado ou monetização fraca. Considere pivotar.';
  }

  String _rec() {
    final s = analysis.opportunityScore;
    if (s >= 80) return '🚀  Prioridade Alta';
    if (s >= 60) return '⚡  Prioridade Média';
    return '⚠️  Baixa Prioridade';
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'OPPORTUNITY SCORE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '/100',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: color.withOpacity(0.55),
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      analysis.input,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      textAlign: TextAlign.end,
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
                      _rec(),
                      style: TextStyle(
                          color: color, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _ScoreBar(label: 'SEO',          score: analysis.scoreSeo),
              const SizedBox(width: 8),
              _ScoreBar(label: 'Monetização',  score: analysis.scoreMonetization),
              const SizedBox(width: 8),
              _ScoreBar(label: 'Concorrência', score: analysis.scoreCompetition),
              const SizedBox(width: 8),
              _ScoreBar(label: 'Crescimento',  score: analysis.scoreGrowth),
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
              _desc(),
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
              const Flexible(
                child: Text(
                  'Revenue Potential',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData) ...[
            const Icon(Icons.bar_chart_rounded, color: Colors.white24, size: 28),
            const SizedBox(height: 6),
            const Text(
              'Execute o Revenue Planner para estimativas detalhadas.',
              style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
            ),
          ] else ...[
            Text(
              minVal > 0
                  ? '${_formatBRL(minVal)} – ${_formatBRL(maxVal)}/mês'
                  : '${_formatBRL(maxVal)}/mês',
              style: const TextStyle(
                  color: _kCyan, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2),
            ),
            if (plan != null) ...[
              const SizedBox(height: 4),
              Text(
                'Anual: ${_formatBRL(plan!.annualModerate)}',
                style: TextStyle(color: _kCyan.withOpacity(0.6), fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            _InfoRow2(icon: Icons.timer_rounded,   label: 'Prazo',     value: '$months meses'),
            const SizedBox(height: 6),
            _InfoRow2(icon: Icons.verified_rounded, label: 'Confiança', value: '$conf%'),
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
    final rec   = analysis.investmentRecommendation;
    final score = analysis.investmentScore;
    final just  = analysis.investmentJustification;
    final color = rec == 'SIM' ? _kGreen : rec == 'NÃO' ? _kRed : _kOrange;
    final icon  = rec == 'SIM'
        ? Icons.thumb_up_alt_rounded
        : rec == 'NÃO'
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
          const Text(
            'Vale a Pena Investir?',
            style: TextStyle(
                color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 8),
              Text(
                rec,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Score: $score/100',
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
    final lower = v.toLowerCase();
    if (lower == 'alto') return _kGreen;
    if (lower == 'médio' || lower == 'medio') return _kOrange;
    return _kRed;
  }

  @override
  Widget build(BuildContext context) {
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
              const Flexible(
                child: Text(
                  'Próximas Ações Recomendadas',
                  style: TextStyle(
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
                            _Badge('Impacto: $impact', _impactColor(impact)),
                            _Badge('Esforço: $effort',  Colors.white38),
                            if (roi.isNotEmpty) _Badge('ROI: $roi', _kCyan),
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
              const Expanded(
                child: Text(
                  'Principais Concorrentes',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Ver todos',
                    style: TextStyle(color: _kPrimary, fontSize: 12)),
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
              message:     'Concorrentes ainda não descobertos.',
              buttonLabel: 'Descobrir Concorrentes',
              onTap:       () => context.push(route),
            )
          else ...[
            const Row(
              children: [
                Expanded(flex: 4, child: _TH('Concorrente')),
                Expanded(flex: 2, child: _TH('Similar.')),
                Expanded(flex: 2, child: _TH('Autoridade')),
                Expanded(flex: 2, child: _TH('Score')),
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
              label: const Text('Analisar Concorrente', style: TextStyle(fontSize: 12)),
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
              const Expanded(
                child: Text(
                  'Resumo dos Gaps',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
                style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Detalhar',
                    style: TextStyle(color: _kPrimary, fontSize: 12)),
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
              message:     'Gap Analysis ainda não executada.',
              buttonLabel: 'Executar Gap Analysis',
              onTap:       () => context.push(route),
            )
          else ...[
            _GapRow(Icons.search_rounded,         'SEO Gap',           gap!.seoGaps,          _kCyan),
            _GapRow(Icons.article_rounded,        'Content Gap',       gap!.contentGaps,      _kOrange),
            _GapRow(Icons.verified_user_rounded,  'Authority Gap',     gap!.authorityGaps,    _kPrimary),
            _GapRow(Icons.attach_money_rounded,   'Monetization Gap',  gap!.monetizationGaps, _kGreen),
            _GapRow(Icons.inventory_2_rounded,    'Product Gap',       gap!.productGaps,      _kGold),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total: ${gap!.totalGaps} gaps identificados',
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
              const Expanded(
                child: Text(
                  'Oportunidades Detectadas',
                  style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => context.push(route),
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
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
              ),
            )
          else if (top.isEmpty)
            _EmptyState(
              icon:        Icons.lightbulb_outline_rounded,
              message:     'Oportunidades ainda não mapeadas.',
              buttonLabel: 'Descobrir Oportunidades',
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
                          if (o.timeframe.isNotEmpty) _Badge(o.timeframe, _kCyan),
                          if (o.effort.isNotEmpty)
                            _Badge('Esforço: ${o.effort}', Colors.white38),
                          _Badge(
                            'Receita: ${_scoreLabel(o.monetizationScore)}',
                            _kGreen,
                          ),
                          _Badge(
                            'Dificuldade: ${_scoreLabel(100 - o.difficultyScore)}',
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
// Module Navigation Grid
// ════════════════════════════════════════════════════════════════════════════
class _ModuleNavGrid extends StatelessWidget {
  const _ModuleNavGrid({required this.analysisId});
  final String analysisId;

  @override
  Widget build(BuildContext context) {
    final id   = analysisId;
    final mods = [
      _Mod(Icons.people_alt_rounded,   'Concorrentes',    _routeFor(AppConstants.routeMarketIntelligenceCompetitors,  id), _kOrange),
      _Mod(Icons.find_in_page_rounded, 'Gap Analysis',    _routeFor(AppConstants.routeMarketIntelligenceGaps,         id), _kGold),
      _Mod(Icons.lightbulb_rounded,    'Oportunidades',   _routeFor(AppConstants.routeMarketIntelligenceOpportunities,id), _kGreen),
      _Mod(Icons.trending_up_rounded,  'Nichos',          _routeFor(AppConstants.routeMarketIntelligenceNiches,       id), _kCyan),
      _Mod(Icons.account_tree_rounded, 'Content Cluster', _routeFor(AppConstants.routeMarketIntelligenceCluster,      id), _kPrimary),
      _Mod(Icons.bar_chart_rounded,    'Revenue Planner', _routeFor(AppConstants.routeMarketIntelligenceRevenue,      id), _kPink),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÓDULOS DE ANÁLISE',
          style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount:   3,
          crossAxisSpacing: 8,
          mainAxisSpacing:  8,
          shrinkWrap:       true,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          children: mods
              .map((m) => _CompactTile(
                    icon:  m.icon,
                    label: m.label,
                    color: m.color,
                    onTap: () => context.push(m.route),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _CompactTile extends StatelessWidget {
  const _CompactTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
              const Text(
                'ROI Tracker',
                style: TextStyle(
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
                'Opportunity Score',
                '${analysis.opportunityScore}/100',
                _scoreColor(analysis.opportunityScore),
              ),
              _RoiStat('Oportunidades', '${opportunities.length}', _kGold),
              if (avgScore > 0)
                _RoiStat('Score Médio', '${avgScore.round()}', _kCyan),
              if (revenue > 0)
                _RoiStat('Revenue/mês', _formatBRL(revenue), _kGreen),
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
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Dados registrados no ROI Tracker!',
                    style: TextStyle(
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
                  isSaving ? 'Registrando...' : 'Registrar no ROI Tracker',
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
        Text('$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Flexible(
          child: Text(value,
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
