import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/competitor.dart';
import '../../../providers/market_analysis_provider.dart';

class CompetitorDiscoveryScreen extends ConsumerStatefulWidget {
  const CompetitorDiscoveryScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<CompetitorDiscoveryScreen> createState() =>
      _CompetitorDiscoveryScreenState();
}

class _CompetitorDiscoveryScreenState
    extends ConsumerState<CompetitorDiscoveryScreen> {
  bool _running = false;
  String? _error;

  Future<void> _discover() async {
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref
          .read(marketAnalysisServiceProvider)
          .discoverCompetitors(widget.analysisId, analysis.input);
      ref.invalidate(competitorsByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(competitorsByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Concorrentes', style: TextStyle(color: Colors.white)),
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Color(0xFFFF6B6B), strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded, color: Color(0xFFFF6B6B)),
            label: Text(
              _running ? 'Buscando...' : 'Descobrir',
              style: const TextStyle(color: Color(0xFFFF6B6B)),
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
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B6B))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (competitors) => competitors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhum concorrente ainda', style: TextStyle(color: Colors.white38)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _running ? null : _discover,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B6B),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Descobrir Concorrentes'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: competitors.length,
                      itemBuilder: (_, i) => _CompetitorCard(competitor: competitors[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard({required this.competitor});
  final Competitor competitor;

  Color get _typeColor {
    switch (competitor.type) {
      case 'direct': return const Color(0xFFFF6B6B);
      case 'indirect': return const Color(0xFFFFD93D);
      default: return const Color(0xFF6BCB77);
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
        border: Border.all(color: _typeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(competitor.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(competitor.url,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _typeColor.withOpacity(0.4)),
                ),
                child: Text(
                  competitor.type.toUpperCase(),
                  style: TextStyle(color: _typeColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ScoreItem(label: 'Simil.', value: competitor.similarityScore, color: const Color(0xFF4D96FF)),
              const SizedBox(width: 12),
              _ScoreItem(label: 'Autor.', value: competitor.authorityScore, color: const Color(0xFFFFD93D)),
              const SizedBox(width: 12),
              _ScoreItem(label: 'Relev.', value: competitor.relevanceScore, color: const Color(0xFF6BCB77)),
              const SizedBox(width: 12),
              _ScoreItem(label: 'Geral', value: competitor.overallScore, color: const Color(0xFFFF6B6B)),
            ],
          ),
          if (competitor.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(competitor.description,
                style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          if (competitor.strengths.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Pontos fortes:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            ...competitor.strengths.take(3).map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF6BCB77), size: 12),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  const _ScoreItem({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
