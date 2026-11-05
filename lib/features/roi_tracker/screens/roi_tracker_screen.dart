import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/roi_metric.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../core/utils/snackbar_utils.dart' show extractErrorMessage;
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

// COMMERCIAL-V1-UX-RECONCILIATION (PT/EN commercial matrix) -- metric type
// display text now comes from l10n, keyed off the same stable 'value'
// string this list already uses for lookups/state. (R16: the dead PT-only
// 'label' fields were removed from _metricTypes.)
String _roiTypeLabel(AppLocalizations l10n, String type) {
  switch (type) {
    case 'revenue':
      return l10n.roiTrackerTypeRevenue;
    case 'investment':
      return l10n.roiTrackerTypeInvestment;
    case 'traffic':
      return l10n.roiTrackerTypeTraffic;
    case 'leads':
      return l10n.roiTrackerTypeLeads;
    case 'conversions':
      return l10n.roiTrackerTypeConversions;
    case 'opportunities':
      return l10n.roiTrackerTypeOpportunities;
    case 'revenue_potential':
      return l10n.roiTrackerTypeRevenuePotential;
    case 'revenue_estimated':
      return l10n.roiTrackerTypeRevenueEstimated;
    case 'hours_saved':
      return l10n.roiTrackerTypeHoursSaved;
    case 'strategies_executed':
      return l10n.roiTrackerTypeStrategiesExecuted;
    case 'campaigns_executed':
      return l10n.roiTrackerTypeCampaignsExecuted;
    case 'decisions_made':
      return l10n.roiTrackerTypeDecisionsMade;
    case 'opportunity_score':
      return l10n.roiTrackerTypeOpportunityScore;
    case 'avg_opportunity_score':
      return l10n.roiTrackerTypeAvgOpportunityScore;
    default:
      return l10n.roiTrackerTypeOther;
  }
}

class RoiTrackerScreen extends ConsumerStatefulWidget {
  const RoiTrackerScreen({super.key});

  @override
  ConsumerState<RoiTrackerScreen> createState() => _RoiTrackerScreenState();
}

class _RoiTrackerScreenState extends ConsumerState<RoiTrackerScreen> {
  bool _showForm = false;
  String _metricType = 'revenue';
  final _valueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedProjectId;
  bool _saving = false;

  static const _metricTypes = [
    // ── Originais ──────────────────────────────────────────────
    {
      'value': 'revenue',
      'icon': Icons.attach_money_rounded,
      'color': AppColors.positive
    },
    {
      'value': 'investment',
      'icon': Icons.savings_rounded,
      'color': AppColors.negative
    },
    {
      'value': 'traffic',
      'icon': Icons.trending_up_rounded,
      'color': AppColors.info
    },
    {
      'value': 'leads',
      'icon': Icons.people_alt_rounded,
      'color': AppColors.accent
    },
    {
      'value': 'conversions',
      'icon': Icons.check_circle_rounded,
      'color': AppColors.warning
    },
    {
      'value': 'other',
      'icon': Icons.category_rounded,
      'color': AppColors.info
    },
    // ── Fase 10A (Business OS) ─────────────────────────────────
    {
      'value': 'opportunities',
      'icon': Icons.lightbulb_rounded,
      'color': AppColors.gold
    },
    {
      'value': 'revenue_potential',
      'icon': Icons.bar_chart_rounded,
      'color': AppColors.info
    },
    {
      'value': 'revenue_estimated',
      'icon': Icons.calculate_rounded,
      'color': AppColors.positive
    },
    {
      'value': 'hours_saved',
      'icon': Icons.schedule_rounded,
      'color': AppColors.accent
    },
    {
      'value': 'strategies_executed',
      'icon': Icons.flag_rounded,
      'color': AppColors.accent
    },
    {
      'value': 'campaigns_executed',
      'icon': Icons.campaign_rounded,
      'color': AppColors.accent
    },
    {
      'value': 'decisions_made',
      'icon': Icons.psychology_rounded,
      'color': AppColors.warning
    },
    {
      'value': 'opportunity_score',
      'icon': Icons.analytics_rounded,
      'color': AppColors.info
    },
    {
      'value': 'avg_opportunity_score',
      'icon': Icons.star_rounded,
      'color': AppColors.warning
    },
  ];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _label(String type, AppLocalizations l10n) =>
      _roiTypeLabel(l10n, type);

  Color _color(String type) {
    return _metricTypes.firstWhere((m) => m['value'] == type,
        orElse: () => _metricTypes.last)['color'] as Color;
  }

  IconData _icon(String type) {
    return _metricTypes.firstWhere((m) => m['value'] == type,
        orElse: () => _metricTypes.last)['icon'] as IconData;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _valueCtrl.text.trim();
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.roiTrackerInvalidValue),
            backgroundColor: AppColors.warning),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(roiMetricsNotifierProvider.notifier).add(
            metricType: _metricType,
            metricValue: value,
            projectId: _selectedProjectId,
            notes: _notesCtrl.text.trim().isNotEmpty
                ? _notesCtrl.text.trim()
                : null,
          );
      _valueCtrl.clear();
      _notesCtrl.clear();
      setState(() {
        _showForm = false;
        _selectedProjectId = null;
        _metricType = 'revenue';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(extractErrorMessage(e, l10n)),
            backgroundColor: AppColors.negative),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asyncMetrics = ref.watch(roiMetricsNotifierProvider);
    final asyncSummary = ref.watch(roiSummaryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        backgroundColor: Colors.transparent,
        title: Text(l10n.roiTrackerTitle,
            style: const TextStyle(color: AppColors.ink)),
        iconTheme: const IconThemeData(color: AppColors.ink),
        actions: [
          IconButton(
            icon: Icon(
              _showForm ? Icons.close_rounded : Icons.add_rounded,
              color: AppColors.warning,
            ),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Executive Dashboard (M6 expansion)
            asyncSummary.when(
              loading: () => const SizedBox(
                  height: 100,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.warning))),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) =>
                  _ExecutiveDashboardSection(summary: summary, l10n: l10n),
            ),

            // Summary cards
            asyncSummary.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => _SummarySection(
                summary: summary,
                color: _color,
                icon: _icon,
                label: (t) => _label(t, l10n),
                l10n: l10n,
              ),
            ),

            // Form
            if (_showForm) _buildForm(l10n),

            // Metrics list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(l10n.roiTrackerRecordsTitle,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            asyncMetrics.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child:
                          CircularProgressIndicator(color: AppColors.warning))),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    l10n.iveChatErrorPrefix(extractErrorMessage(e, l10n)),
                    style: const TextStyle(color: AppColors.negative)),
              ),
              data: (metrics) => metrics.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(l10n.roiTrackerEmptyRecords,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.inkSubtle)),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: metrics.length,
                      itemBuilder: (_, i) => _MetricCard(
                        metric: metrics[i],
                        color: _color(metrics[i].metricType),
                        icon: _icon(metrics[i].metricType),
                        label: _label(metrics[i].metricType, l10n),
                        onDelete: () => ref
                            .read(roiMetricsNotifierProvider.notifier)
                            .delete(metrics[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.roiTrackerNewRecord,
              style: const TextStyle(
                  color: AppColors.warning, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Metric type
          Text(l10n.roiTrackerTypeLabel,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _metricTypes.map((m) {
              final isSelected = _metricType == m['value'];
              final color = m['color'] as Color;
              return GestureDetector(
                onTap: () => setState(() => _metricType = m['value'] as String),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.15)
                        : AppColors.ground,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: isSelected ? color : AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m['icon'] as IconData,
                          color: isSelected ? color : AppColors.inkSubtle, size: 14),
                      const SizedBox(width: 4),
                      Text(_roiTypeLabel(l10n, m['value'] as String),
                          style: TextStyle(
                            color: isSelected ? color : AppColors.inkMuted,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Project selector
          const SizedBox(height: 4),
          Consumer(builder: (context, ref, _) {
            final projectsAsync = ref.watch(projectsProvider);
            return projectsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (projects) => projects.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.roiTrackerProjectOptional,
                            style: const TextStyle(
                                color: AppColors.inkMuted, fontSize: 12)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String?>(
                          value: _selectedProjectId,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(
                              color: AppColors.ink, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.ground,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              borderSide:
                                  const BorderSide(color: AppColors.line),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l10n.roiTrackerProjectNone,
                                    style: const TextStyle(
                                        color: AppColors.inkMuted))),
                            ...projects.map((p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(p.name,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedProjectId = v),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
            );
          }),

          // Value
          TextField(
            controller: _valueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.ink, fontSize: 13),
            decoration: InputDecoration(
              labelText: l10n.roiTrackerValueLabel,
              labelStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.ground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.warning),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Notes
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: AppColors.ink, fontSize: 13),
            decoration: InputDecoration(
              labelText: l10n.roiTrackerNotesLabel,
              labelStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
              filled: true,
              fillColor: AppColors.ground,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.warning),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkMuted,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2))
                      : Text(l10n.commonSave,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.summary,
    required this.color,
    required this.icon,
    required this.label,
    required this.l10n,
  });

  final Map<String, double> summary;
  final Color Function(String) color;
  final IconData Function(String) icon;
  final String Function(String) label;
  final AppLocalizations l10n;

  String _fmt(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  double get _roi {
    final revenue = summary['revenue'] ?? 0;
    final investment = summary['investment'] ?? 0;
    if (investment == 0) return 0;
    return ((revenue - investment) / investment) * 100;
  }

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Text(l10n.roiTrackerSummaryTitle,
                  style: const TextStyle(
                      color: AppColors.warning, fontWeight: FontWeight.w600)),
              const Spacer(),
              if ((summary['investment'] ?? 0) > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roi >= 0
                        ? AppColors.positive.withOpacity(0.1)
                        : AppColors.negative.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: _roi >= 0
                          ? AppColors.positive
                          : AppColors.negative,
                    ),
                  ),
                  child: Text(
                    l10n.roiTrackerRoiPercent(_roi.toStringAsFixed(0)),
                    style: TextStyle(
                      color: _roi >= 0
                          ? AppColors.positive
                          : AppColors.negative,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.entries.map((e) {
              final c = color(e.key);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(icon(e.key), color: c, size: 18),
                    const SizedBox(height: 4),
                    Text(_fmt(e.value),
                        style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text(label(e.key),
                        style: const TextStyle(
                            color: AppColors.inkSubtle, fontSize: 10)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.color,
    required this.icon,
    required this.label,
    required this.onDelete,
  });

  final RoiMetric metric;
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onDelete;

  String _fmt(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(1)}K';
    return 'R\$ ${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                if (metric.notes != null && metric.notes!.isNotEmpty)
                  Text(metric.notes!,
                      style:
                          const TextStyle(color: AppColors.inkMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(_fmt(metric.metricValue),
              style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded,
                color: AppColors.inkSubtle, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── M6: Executive Dashboard Section ──────────────────────────────────────────
class _ExecutiveDashboardSection extends StatelessWidget {
  const _ExecutiveDashboardSection({required this.summary, required this.l10n});
  final Map<String, double> summary;
  final AppLocalizations l10n;

  String _fmtBRL(double v) {
    if (v <= 0) return 'R\$ 0';
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}k';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  String _fmt(double? v) => v != null && v > 0 ? v.round().toString() : '–';

  @override
  Widget build(BuildContext context) {
    final revenue = summary['revenue'] ?? 0;
    final revPotential = summary['revenue_potential'] ?? 0;
    final revEstimated = summary['revenue_estimated'] ?? 0;
    final hoursSaved = summary['hours_saved'] ?? 0;
    final strategies = summary['strategies_executed'] ?? 0;
    final campaigns = summary['campaigns_executed'] ?? 0;
    final decisions = summary['decisions_made'] ?? 0;
    final opportunities = summary['opportunities'] ?? 0;

    final hasData = revenue > 0 || revPotential > 0 || opportunities > 0;
    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, gradient: kIvSurfaceGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.positive.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  color: AppColors.positive, size: 18),
              const SizedBox(width: 8),
              Text(
                l10n.roiTrackerExecutiveDashboardTitle,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Revenue row
          if (revenue > 0 || revPotential > 0 || revEstimated > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.roiTrackerRevenueSectionTitle,
                    style: const TextStyle(
                        color: AppColors.inkSubtle,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (revenue > 0)
                      _ExecStat(l10n.roiTrackerRevenueRegistered,
                          _fmtBRL(revenue), AppColors.positive),
                    if (revPotential > 0)
                      _ExecStat(l10n.roiTrackerRevenuePotentialLabel,
                          _fmtBRL(revPotential), AppColors.info),
                    if (revEstimated > 0)
                      _ExecStat(l10n.roiTrackerRevenueEstimatedLabel,
                          _fmtBRL(revEstimated), AppColors.positive),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          // Activity row
          Text(l10n.roiTrackerActivitySectionTitle,
              style: const TextStyle(
                  color: AppColors.inkSubtle,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (opportunities > 0)
                _ExecStat(_roiTypeLabel(l10n, 'opportunities'),
                    _fmt(opportunities), AppColors.gold),
              if (strategies > 0)
                _ExecStat(_roiTypeLabel(l10n, 'strategies_executed'),
                    _fmt(strategies), AppColors.accent),
              if (campaigns > 0)
                _ExecStat(_roiTypeLabel(l10n, 'campaigns_executed'),
                    _fmt(campaigns), AppColors.accent),
              if (decisions > 0)
                _ExecStat(_roiTypeLabel(l10n, 'decisions_made'),
                    _fmt(decisions), AppColors.warning),
              if (hoursSaved > 0)
                _ExecStat(l10n.roiTrackerHoursSavedShort,
                    '${hoursSaved.round()}h', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecStat extends StatelessWidget {
  const _ExecStat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(color: AppColors.inkSubtle, fontSize: 10)),
        ],
      ),
    );
  }
}
