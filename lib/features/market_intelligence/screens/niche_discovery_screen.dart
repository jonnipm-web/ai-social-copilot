import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/niche_ranking.dart';
import '../../../providers/market_analysis_provider.dart';

class NicheDiscoveryScreen extends ConsumerStatefulWidget {
  const NicheDiscoveryScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<NicheDiscoveryScreen> createState() => _NicheDiscoveryScreenState();
}

class _NicheDiscoveryScreenState extends ConsumerState<NicheDiscoveryScreen> {
  bool _running = false;
  String? _error;

  Future<void> _discover() async {
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref.read(marketAnalysisServiceProvider).discoverNiches(widget.analysisId, analysis.input);
      ref.invalidate(nichesByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(nichesByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Nichos & Sub-nichos', style: TextStyle(color: Colors.white)),
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
                    child: CircularProgressIndicator(color: Color(0xFF4D96FF), strokeWidth: 2),
                  )
                : const Icon(Icons.hub_rounded, color: Color(0xFF4D96FF)),
            label: Text(
              _running ? 'Descobrindo...' : 'Descobrir',
              style: const TextStyle(color: Color(0xFF4D96FF)),
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
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF4D96FF))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (niches) => niches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hub_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhum nicho ainda', style: TextStyle(color: Colors.white38)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _running ? null : _discover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4D96FF),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Descobrir Nichos'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: niches.length,
                      itemBuilder: (_, i) => _NicheCard(niche: niches[i], rank: i + 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NicheCard extends StatelessWidget {
  const _NicheCard({required this.niche, required this.rank});
  final NicheRanking niche;
  final int rank;

  Color get _levelColor {
    switch (niche.level) {
      case 'niche': return const Color(0xFF4D96FF);
      case 'sub_niche': return const Color(0xFFAB83FF);
      default: return const Color(0xFF00BCD4);
    }
  }

  String get _levelLabel {
    switch (niche.level) {
      case 'niche': return 'Nicho';
      case 'sub_niche': return 'Sub-nicho';
      default: return 'Micro-nicho';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _levelColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _levelColor),
                ),
                child: Center(
                  child: Text('#$rank',
                      style: TextStyle(color: _levelColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(niche.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(_levelLabel, style: TextStyle(color: _levelColor, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${niche.overallScore}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Text('score', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (niche.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(niche.description,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          // Score grid
          Row(
            children: [
              _MiniBar(label: 'Potencial', value: niche.potentialScore, color: const Color(0xFF6BCB77)),
              const SizedBox(width: 8),
              _MiniBar(label: 'Crescimento', value: niche.growthScore, color: const Color(0xFF4D96FF)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MiniBar(label: 'Monetização', value: niche.monetizationScore, color: const Color(0xFFFFD93D)),
              const SizedBox(width: 8),
              _MiniBar(label: 'Tendência', value: niche.trendScore, color: const Color(0xFFAB83FF)),
            ],
          ),
          if (niche.keywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: niche.keywords.take(5).map(
                (k) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _levelColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _levelColor.withOpacity(0.3)),
                  ),
                  child: Text(k, style: TextStyle(color: _levelColor, fontSize: 11)),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              Text('$value', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
