import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/roi_metric.dart';
import '../../../providers/roi_metric_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

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
    {'value': 'revenue',                'label': 'Receita',              'icon': Icons.attach_money_rounded,   'color': Color(0xFF6BCB77)},
    {'value': 'investment',             'label': 'Investimento',         'icon': Icons.savings_rounded,         'color': Color(0xFFFF6B6B)},
    {'value': 'traffic',                'label': 'Tráfego',              'icon': Icons.trending_up_rounded,     'color': Color(0xFF4D96FF)},
    {'value': 'leads',                  'label': 'Leads',                'icon': Icons.people_alt_rounded,      'color': Color(0xFFAB83FF)},
    {'value': 'conversions',            'label': 'Conversões',           'icon': Icons.check_circle_rounded,    'color': Color(0xFFFFD93D)},
    {'value': 'other',                  'label': 'Outro',                'icon': Icons.category_rounded,        'color': Color(0xFF00BCD4)},
    // ── Fase 10A (Business OS) ─────────────────────────────────
    {'value': 'opportunities',          'label': 'Oportunidades',        'icon': Icons.lightbulb_rounded,       'color': Color(0xFFFFD700)},
    {'value': 'revenue_potential',      'label': 'Receita Potencial',    'icon': Icons.bar_chart_rounded,       'color': Color(0xFF00BCD4)},
    {'value': 'revenue_estimated',      'label': 'Receita Estimada',     'icon': Icons.calculate_rounded,       'color': Color(0xFF4CAF50)},
    {'value': 'hours_saved',            'label': 'Horas Economizadas',   'icon': Icons.schedule_rounded,        'color': Color(0xFF9C27B0)},
    {'value': 'strategies_executed',    'label': 'Estratégias',          'icon': Icons.flag_rounded,            'color': Color(0xFF6C63FF)},
    {'value': 'campaigns_executed',     'label': 'Campanhas',            'icon': Icons.campaign_rounded,        'color': Color(0xFFE91E63)},
    {'value': 'decisions_made',         'label': 'Decisões',             'icon': Icons.psychology_rounded,      'color': Color(0xFFFF9800)},
    {'value': 'opportunity_score',      'label': 'Score MI',             'icon': Icons.analytics_rounded,       'color': Color(0xFF4D96FF)},
    {'value': 'avg_opportunity_score',  'label': 'Score Médio',          'icon': Icons.star_rounded,            'color': Color(0xFFFFD93D)},
  ];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _label(String type) {
    return _metricTypes.firstWhere((m) => m['value'] == type, orElse: () => _metricTypes.last)['label'] as String;
  }

  Color _color(String type) {
    return _metricTypes.firstWhere((m) => m['value'] == type, orElse: () => _metricTypes.last)['color'] as Color;
  }

  IconData _icon(String type) {
    return _metricTypes.firstWhere((m) => m['value'] == type, orElse: () => _metricTypes.last)['icon'] as IconData;
  }

  Future<void> _save() async {
    final raw = _valueCtrl.text.trim();
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor numérico válido'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(roiMetricsNotifierProvider.notifier).add(
        metricType: _metricType,
        metricValue: value,
        projectId: _selectedProjectId,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      );
      _valueCtrl.clear();
      _notesCtrl.clear();
      setState(() { _showForm = false; _selectedProjectId = null; _metricType = 'revenue'; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMetrics = ref.watch(roiMetricsNotifierProvider);
    final asyncSummary = ref.watch(roiSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
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
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('ROI Tracker', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _showForm ? Icons.close_rounded : Icons.add_rounded,
              color: const Color(0xFFFFD93D),
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
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD93D)))),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => _ExecutiveDashboardSection(summary: summary),
            ),

            // Summary cards
            asyncSummary.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => _SummarySection(summary: summary, color: _color, icon: _icon, label: _label),
            ),

            // Form
            if (_showForm)
              _buildForm(),

            // Metrics list
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: const Text('Registros', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            asyncMetrics.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFFFD93D)))),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (metrics) => metrics.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Nenhum registro ainda.\nToque em + para adicionar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38)),
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
                        label: _label(metrics[i].metricType),
                        onDelete: () => ref.read(roiMetricsNotifierProvider.notifier).delete(metrics[i].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD93D).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Novo Registro', style: TextStyle(color: Color(0xFFFFD93D), fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Metric type
          const Text('Tipo', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.15) : const Color(0xFF0F0F1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? color : const Color(0xFF333355)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(m['icon'] as IconData, color: isSelected ? color : Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(m['label'] as String,
                          style: TextStyle(
                            color: isSelected ? color : Colors.white54,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Value
          TextField(
            controller: _valueCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Valor *',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0F0F1A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333355)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFFD93D)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Notes
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Observações (opcional)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF0F0F1A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF333355)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFFD93D)),
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
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Color(0xFF333355)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD93D),
                    foregroundColor: Colors.black,
                  ),
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
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
  const _SummarySection({required this.summary, required this.color, required this.icon, required this.label});

  final Map<String, double> summary;
  final Color Function(String) color;
  final IconData Function(String) icon;
  final String Function(String) label;

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
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD93D).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFFFFD93D), size: 18),
              const SizedBox(width: 8),
              const Text('Resumo ROI', style: TextStyle(color: Color(0xFFFFD93D), fontWeight: FontWeight.bold)),
              const Spacer(),
              if ((summary['investment'] ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _roi >= 0
                        ? const Color(0xFF6BCB77).withOpacity(0.1)
                        : const Color(0xFFFF6B6B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _roi >= 0 ? const Color(0xFF6BCB77) : const Color(0xFFFF6B6B),
                    ),
                  ),
                  child: Text(
                    'ROI: ${_roi.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _roi >= 0 ? const Color(0xFF6BCB77) : const Color(0xFFFF6B6B),
                      fontWeight: FontWeight.bold,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(icon(e.key), color: c, size: 18),
                    const SizedBox(height: 4),
                    Text(_fmt(e.value), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(label(e.key), style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                if (metric.notes != null && metric.notes!.isNotEmpty)
                  Text(metric.notes!, style: const TextStyle(color: Colors.white54, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(_fmt(metric.metricValue),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded, color: Colors.white24, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── M6: Executive Dashboard Section ──────────────────────────────────────────
class _ExecutiveDashboardSection extends StatelessWidget {
  const _ExecutiveDashboardSection({required this.summary});
  final Map<String, double> summary;

  String _fmtBRL(double v) {
    if (v <= 0) return 'R\$ 0';
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}k';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  String _fmt(double? v) => v != null && v > 0 ? v.round().toString() : '–';

  @override
  Widget build(BuildContext context) {
    final revenue           = summary['revenue']             ?? 0;
    final revPotential      = summary['revenue_potential']   ?? 0;
    final revEstimated      = summary['revenue_estimated']   ?? 0;
    final hoursSaved        = summary['hours_saved']         ?? 0;
    final strategies        = summary['strategies_executed'] ?? 0;
    final campaigns         = summary['campaigns_executed']  ?? 0;
    final decisions         = summary['decisions_made']      ?? 0;
    final opportunities     = summary['opportunities']       ?? 0;

    final hasData = revenue > 0 || revPotential > 0 || opportunities > 0;
    if (!hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Color(0xFF4CAF50), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Dashboard Executivo',
                style: TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Revenue row
          if (revenue > 0 || revPotential > 0 || revEstimated > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RECEITA',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (revenue > 0)
                      _ExecStat('Registrada',  _fmtBRL(revenue),      const Color(0xFF6BCB77)),
                    if (revPotential > 0)
                      _ExecStat('Potencial',   _fmtBRL(revPotential), const Color(0xFF00BCD4)),
                    if (revEstimated > 0)
                      _ExecStat('Estimada',    _fmtBRL(revEstimated), const Color(0xFF4CAF50)),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          // Activity row
          const Text('ATIVIDADE',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              if (opportunities > 0)
                _ExecStat('Oportunidades',    _fmt(opportunities), const Color(0xFFFFD700)),
              if (strategies > 0)
                _ExecStat('Estratégias',      _fmt(strategies),    const Color(0xFF6C63FF)),
              if (campaigns > 0)
                _ExecStat('Campanhas',        _fmt(campaigns),     const Color(0xFFE91E63)),
              if (decisions > 0)
                _ExecStat('Decisões',         _fmt(decisions),     const Color(0xFFFF9800)),
              if (hoursSaved > 0)
                _ExecStat('Horas Econ.',      '${hoursSaved.round()}h', const Color(0xFF9C27B0)),
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
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
