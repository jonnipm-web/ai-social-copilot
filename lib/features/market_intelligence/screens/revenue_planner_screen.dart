import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/market_analysis_provider.dart';

class RevenuePlannerScreen extends ConsumerStatefulWidget {
  const RevenuePlannerScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<RevenuePlannerScreen> createState() => _RevenuePlannerScreenState();
}

class _RevenuePlannerScreenState extends ConsumerState<RevenuePlannerScreen> {
  bool _running = false;
  String? _error;
  final _projectCtrl = TextEditingController();

  @override
  void dispose() {
    _projectCtrl.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final name = _projectCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o nome do projeto'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref.read(marketAnalysisServiceProvider).buildRevenuePlan(widget.analysisId, analysis.input, name);
      ref.invalidate(revenuePlanByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _fmt(double v) {
    if (v >= 1000000) return 'R\$ ${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return 'R\$ ${(v / 1000).toStringAsFixed(0)}K';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final asyncPlan = ref.watch(revenuePlanByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Revenue Planner', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', widget.analysisId),
          ),
        ),
      ),
      body: asyncPlan.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4))),
        error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (plan) => plan == null
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.attach_money_outlined, color: Colors.white24, size: 64),
                    const SizedBox(height: 16),
                    const Text('Nenhum plano de receita ainda', style: TextStyle(color: Colors.white38)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _projectCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nome do projeto',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF1A1A2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF333355)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _running ? null : _build,
                        icon: _running
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.calculate_rounded),
                        label: Text(_running ? 'Calculando...' : 'Gerar Revenue Plan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00BCD4),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project name
                    Text(
                      plan.projectName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Scenario cards
                    _ScenarioCard(
                      label: 'Conservador',
                      monthly: plan.monthlyConservative,
                      annual: plan.annualConservative,
                      color: const Color(0xFF6BCB77),
                      icon: Icons.trending_flat_rounded,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 10),
                    _ScenarioCard(
                      label: 'Moderado',
                      monthly: plan.monthlyModerate,
                      annual: plan.annualModerate,
                      color: const Color(0xFF00BCD4),
                      icon: Icons.trending_up_rounded,
                      fmt: _fmt,
                    ),
                    const SizedBox(height: 10),
                    _ScenarioCard(
                      label: 'Agressivo',
                      monthly: plan.monthlyAggressive,
                      annual: plan.annualAggressive,
                      color: const Color(0xFFFF6B6B),
                      icon: Icons.rocket_launch_rounded,
                      fmt: _fmt,
                    ),

                    // Revenue sources
                    if (plan.revenueSources.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Fontes de Receita',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...plan.revenueSources.map(
                        (s) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF333355)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.attach_money_rounded, color: Color(0xFFFFD93D), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['name']?.toString() ?? '',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    if (s['description'] != null)
                                      Text(s['description'].toString(),
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              if (s['percentage'] != null)
                                Text('${s['percentage']}%',
                                    style: const TextStyle(color: Color(0xFFFFD93D), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Milestones
                    if (plan.milestones.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Marcos de Receita',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...plan.milestones.asMap().entries.map(
                        (e) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00BCD4).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${e.key + 1}',
                                      style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.value['title']?.toString() ?? '',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                    if (e.value['target'] != null)
                                      Text('Meta: ${_fmt((e.value['target'] as num).toDouble())}',
                                          style: const TextStyle(color: Color(0xFF00BCD4), fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Assumptions
                    if (plan.assumptions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text('Premissas',
                          style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...plan.assumptions.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Colors.white38)),
                              Expanded(child: Text(a, style: const TextStyle(color: Colors.white38, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.label,
    required this.monthly,
    required this.annual,
    required this.color,
    required this.icon,
    required this.fmt,
  });

  final String label;
  final double monthly;
  final double annual;
  final Color color;
  final IconData icon;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Mensal: ${fmt(monthly)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Anual', style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
              Text(fmt(annual), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
