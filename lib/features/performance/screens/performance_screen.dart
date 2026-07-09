import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/performance_metrics.dart';
import '../../../providers/performance_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

const _bgColor = Color(0xFF0F0F1A);
const _cardColor = Color(0xFF1A1A2E);
const _primaryColor = Color(0xFF6C63FF);

IconData _platformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'instagram':
      return Icons.camera_alt;
    case 'facebook':
      return Icons.facebook;
    case 'linkedin':
      return Icons.business;
    case 'youtube':
      return Icons.play_arrow;
    case 'tiktok':
      return Icons.music_note;
    case 'twitter':
      return Icons.alternate_email;
    case 'email':
      return Icons.email;
    case 'google':
      return Icons.search;
    case 'blog':
      return Icons.article;
    case 'hotmart':
      return Icons.storefront;
    case 'shopify':
      return Icons.shopping_bag;
    case 'amazon':
      return Icons.local_shipping;
    default:
      return Icons.bar_chart;
  }
}

Color _scoreColor(double score) {
  if (score >= 75) return const Color(0xFF4CAF50);
  if (score >= 50) return const Color(0xFFFFB74D);
  if (score >= 25) return const Color(0xFFFF7043);
  return const Color(0xFFEF5350);
}

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(performanceMetricsProvider);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: const Text(
          'Performance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        onPressed: () => _openAddMetricSheet(context),
        child: const Icon(Icons.add),
      ),
      body: metricsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar métricas:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
                onPressed: () => ref.invalidate(performanceMetricsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (metrics) {
          if (metrics.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 72, color: _primaryColor.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma métrica registrada ainda.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toque no + para adicionar uma entrada.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: metrics.length,
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _MetricCard(
                metric: metric,
                onDelete: () => _deleteMetric(metric),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteMetric(PerformanceMetrics metric) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        title: const Text('Excluir métrica', style: TextStyle(color: Colors.white)),
        content: Text(
          'Deseja excluir a métrica de ${metric.platform}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(performanceNotifierProvider.notifier).delete(metric.id);
        ref.invalidate(performanceMetricsProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Métrica excluída com sucesso.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openAddMetricSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMetricSheet(
        onSaved: () {
          ref.invalidate(performanceMetricsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Métrica adicionada com sucesso!'),
              backgroundColor: _primaryColor,
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final PerformanceMetrics metric;
  final VoidCallback onDelete;

  const _MetricCard({required this.metric, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final score = metric.performanceScore.clamp(0.0, 100.0);
    final scoreColor = _scoreColor(score);

    final impressions = metric.impressions;
    final clicks = metric.clicks;
    final engRate = impressions > 0
        ? ((metric.likes + metric.comments + metric.shares) / impressions * 100)
        : 0.0;
    final convRate = impressions > 0 ? (metric.leads / impressions * 100) : 0.0;

    final dateStr = '${metric.createdAt.day.toString().padLeft(2, '0')}/'
        '${metric.createdAt.month.toString().padLeft(2, '0')}/'
        '${metric.createdAt.year}';

    return Dismissible(
      key: ValueKey(metric.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: GestureDetector(
        onLongPress: () => _showContextMenu(context),
        child: Card(
          color: _cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _platformIcon(metric.platform),
                        color: _primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.platform,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MetricChip(label: 'Impressões', value: _formatNumber(impressions)),
                    const SizedBox(width: 8),
                    _MetricChip(label: 'Cliques', value: _formatNumber(clicks)),
                    const SizedBox(width: 8),
                    _MetricChip(label: 'Eng%', value: '${engRate.toStringAsFixed(1)}%'),
                    const SizedBox(width: 8),
                    _MetricChip(label: 'Conv%', value: '${convRate.toStringAsFixed(2)}%'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Score',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: score / 100,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${score.toStringAsFixed(0)}/100',
                      style: TextStyle(color: scoreColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (metric.notes != null && metric.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    metric.notes!,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Excluir métrica', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMetricSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const _AddMetricSheet({required this.onSaved});

  @override
  ConsumerState<_AddMetricSheet> createState() => _AddMetricSheetState();
}

class _AddMetricSheetState extends ConsumerState<_AddMetricSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  String? _selectedPlatform;

  final _impressoesCtrl = TextEditingController();
  final _cliquesCtrl = TextEditingController();
  final _curtidasCtrl = TextEditingController();
  final _comentariosCtrl = TextEditingController();
  final _compartilhamentosCtrl = TextEditingController();
  final _salvamentosCtrl = TextEditingController();
  final _leadsCtrl = TextEditingController();
  final _vendasCtrl = TextEditingController();
  final _receitaCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  @override
  void dispose() {
    _impressoesCtrl.dispose();
    _cliquesCtrl.dispose();
    _curtidasCtrl.dispose();
    _comentariosCtrl.dispose();
    _compartilhamentosCtrl.dispose();
    _salvamentosCtrl.dispose();
    _leadsCtrl.dispose();
    _vendasCtrl.dispose();
    _receitaCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  int _parseInt(TextEditingController ctrl) =>
      int.tryParse(ctrl.text.trim()) ?? 0;

  double _parseDouble(TextEditingController ctrl) =>
      double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 0.0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlatform == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione uma plataforma.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final metrics = PerformanceMetrics(
            id:             '',
            userId:         '',
            platform:       _selectedPlatform!,
            impressions:    _parseInt(_impressoesCtrl),
            clicks:         _parseInt(_cliquesCtrl),
            likes:          _parseInt(_curtidasCtrl),
            comments:       _parseInt(_comentariosCtrl),
            shares:         _parseInt(_compartilhamentosCtrl),
            saves:          _parseInt(_salvamentosCtrl),
            leads:          _parseInt(_leadsCtrl),
            sales:          _parseInt(_vendasCtrl),
            revenue:        _parseDouble(_receitaCtrl),
            notes:          _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
            createdAt:      DateTime.now(),
            updatedAt:      DateTime.now(),
          );
      await ref.read(performanceNotifierProvider.notifier).create(metrics);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nova Métrica',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Platform dropdown
              DropdownButtonFormField<String>(
                value: _selectedPlatform,
                dropdownColor: _bgColor,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Plataforma'),
                items: PerformanceMetrics.platforms.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Row(
                      children: [
                        Icon(_platformIcon(p), color: _primaryColor, size: 18),
                        const SizedBox(width: 8),
                        Text(p, style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedPlatform = v),
                validator: (v) => v == null ? 'Selecione uma plataforma' : null,
              ),
              const SizedBox(height: 12),

              // Int fields — 2 columns
              _intRow('Impressões', _impressoesCtrl, 'Cliques', _cliquesCtrl),
              const SizedBox(height: 12),
              _intRow('Curtidas', _curtidasCtrl, 'Comentários', _comentariosCtrl),
              const SizedBox(height: 12),
              _intRow('Compartilhamentos', _compartilhamentosCtrl, 'Salvamentos', _salvamentosCtrl),
              const SizedBox(height: 12),
              _intRow('Leads', _leadsCtrl, 'Vendas', _vendasCtrl),
              const SizedBox(height: 12),

              // Revenue
              TextFormField(
                controller: _receitaCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Receita (R\$)'),
              ),
              const SizedBox(height: 12),

              // Notes
              TextFormField(
                controller: _notasCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: _inputDecoration('Notas (opcional)'),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Salvar',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intRow(
    String label1,
    TextEditingController ctrl1,
    String label2,
    TextEditingController ctrl2,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: ctrl1,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextFormField(
            controller: ctrl2,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration(label2),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
