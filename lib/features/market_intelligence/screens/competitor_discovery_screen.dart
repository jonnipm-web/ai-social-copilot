import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/competitor.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/context_copilot_widget.dart' show showCopilotChat;

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

  void _showDetail(Competitor competitor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompetitorDetailSheet(competitor: competitor),
    );
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
                      itemBuilder: (_, i) => _CompetitorCard(
                        competitor: competitors[i],
                        onTap: () => _showDetail(competitors[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Competitor card (list item) ───────────────────────────────────────────────

class _CompetitorCard extends StatelessWidget {
  const _CompetitorCard({required this.competitor, required this.onTap});
  final Competitor competitor;
  final VoidCallback onTap;

  Color get _typeColor {
    switch (competitor.type) {
      case 'direct': return const Color(0xFFFF6B6B);
      case 'indirect': return const Color(0xFFFFD93D);
      default: return const Color(0xFF6BCB77);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Detail bottom sheet ───────────────────────────────────────────────────────

class _CompetitorDetailSheet extends StatelessWidget {
  const _CompetitorDetailSheet({required this.competitor});
  final Competitor competitor;

  Color get _typeColor {
    switch (competitor.type) {
      case 'direct': return const Color(0xFFFF6B6B);
      case 'indirect': return const Color(0xFFFFD93D);
      default: return const Color(0xFF6BCB77);
    }
  }

  String get _typeLabel {
    switch (competitor.type) {
      case 'direct': return 'Concorrente Direto';
      case 'indirect': return 'Concorrente Indireto';
      default: return 'Referência de Mercado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(competitor.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(competitor.url,
                            style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _typeColor.withOpacity(0.5)),
                    ),
                    child: Text(_typeLabel,
                        style: TextStyle(color: _typeColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF333355), height: 1),
            // Body
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(20),
                children: [
                  // Scores row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _DetailScore(label: 'Similaridade', value: competitor.similarityScore, color: const Color(0xFF4D96FF)),
                      _DetailScore(label: 'Autoridade', value: competitor.authorityScore, color: const Color(0xFFFFD93D)),
                      _DetailScore(label: 'Relevância', value: competitor.relevanceScore, color: const Color(0xFF6BCB77)),
                      _DetailScore(label: 'Geral', value: competitor.overallScore, color: const Color(0xFFFF6B6B)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (competitor.description.isNotEmpty) ...[
                    const Text('Sobre', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(competitor.description,
                        style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
                    const SizedBox(height: 16),
                  ],
                  if (competitor.strengths.isNotEmpty) ...[
                    _ListSection(
                      title: 'Pontos Fortes',
                      icon: Icons.thumb_up_rounded,
                      color: const Color(0xFF6BCB77),
                      items: competitor.strengths,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (competitor.weaknesses.isNotEmpty) ...[
                    _ListSection(
                      title: 'Pontos Fracos',
                      icon: Icons.thumb_down_rounded,
                      color: const Color(0xFFFF6B6B),
                      items: competitor.weaknesses,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (competitor.opportunities.isNotEmpty) ...[
                    _ListSection(
                      title: 'Oportunidades de Diferenciação',
                      icon: Icons.lightbulb_rounded,
                      color: const Color(0xFFFFD93D),
                      items: competitor.opportunities,
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Ask IVE button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showCopilotChat(
                          context,
                          screenName: 'competitor_detail',
                          contextData: CopilotContextData(
                            market: {
                              'competitor_name': competitor.name,
                              'competitor_url': competitor.url,
                              'competitor_type': competitor.type,
                              'similarity_score': competitor.similarityScore,
                              'authority_score': competitor.authorityScore,
                              'relevance_score': competitor.relevanceScore,
                              'strengths': competitor.strengths,
                              'weaknesses': competitor.weaknesses,
                              'opportunities': competitor.opportunities,
                            },
                          ),
                          initialMessage:
                              'Quero entender melhor como me diferenciar de ${competitor.name}.',
                        );
                      },
                      icon: const Icon(Icons.psychology_rounded),
                      label: const Text('Perguntar à IVE sobre este concorrente'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailScore extends StatelessWidget {
  const _DetailScore({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.4), width: 2),
          ),
          child: Center(
            child: Text('$value',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, color: color.withOpacity(0.6), size: 6),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Score chip (list card) ────────────────────────────────────────────────────

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
