import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/opportunity.dart';
import '../../../providers/market_analysis_provider.dart';

class OpportunityDiscoveryScreen extends ConsumerStatefulWidget {
  const OpportunityDiscoveryScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<OpportunityDiscoveryScreen> createState() =>
      _OpportunityDiscoveryScreenState();
}

class _OpportunityDiscoveryScreenState
    extends ConsumerState<OpportunityDiscoveryScreen> {
  bool _running = false;
  String? _error;

  Future<void> _discover() async {
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref.read(marketAnalysisServiceProvider).discoverOpportunities(widget.analysisId, analysis.input);
      ref.invalidate(opportunitiesByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(opportunitiesByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Oportunidades', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', widget.analysisId),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _discover,
            icon: _running
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: Color(0xFF6BCB77), strokeWidth: 2),
                  )
                : const Icon(Icons.star_rounded, color: Color(0xFF6BCB77)),
            label: Text(
              _running ? 'Buscando...' : 'Descobrir',
              style: const TextStyle(color: Color(0xFF6BCB77)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          Expanded(
            child: asyncList.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6BCB77))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (opportunities) => opportunities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_outline_rounded, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhuma oportunidade ainda', style: TextStyle(color: Colors.white38)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _running ? null : _discover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6BCB77),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Descobrir Oportunidades'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: opportunities.length,
                      itemBuilder: (_, i) => _OpportunityCard(opportunity: opportunities[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity});
  final Opportunity opportunity;

  Color get _scoreColor {
    final s = opportunity.opportunityScore;
    if (s >= 80) return const Color(0xFF6BCB77);
    if (s >= 60) return const Color(0xFF00BCD4);
    if (s >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _scoreColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(opportunity.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _scoreColor),
                ),
                child: Text(
                  '${opportunity.opportunityScore}',
                  style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          if (opportunity.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(opportunity.description,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MiniScore(label: 'Mercado', value: opportunity.marketScore, color: const Color(0xFF4D96FF)),
              _MiniScore(label: 'Crescimento', value: opportunity.growthScore, color: const Color(0xFF6BCB77)),
              _MiniScore(label: 'Monetização', value: opportunity.monetizationScore, color: const Color(0xFFFFD93D)),
              _MiniScore(label: 'Dificuldade', value: opportunity.difficultyScore, color: const Color(0xFFFF6B6B)),
            ],
          ),
          if (opportunity.timeframe.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(opportunity.timeframe, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                if (opportunity.effort.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.fitness_center_rounded, color: Colors.white38, size: 14),
                  const SizedBox(width: 4),
                  Text(opportunity.effort, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
