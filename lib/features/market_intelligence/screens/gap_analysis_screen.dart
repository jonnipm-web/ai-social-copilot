import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/market_analysis_provider.dart';

class GapAnalysisScreen extends ConsumerStatefulWidget {
  const GapAnalysisScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends ConsumerState<GapAnalysisScreen> {
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref.read(marketAnalysisServiceProvider).runGapAnalysis(widget.analysisId, analysis.input);
      ref.invalidate(gapAnalysisByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncGap = ref.watch(gapAnalysisByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Gap Analysis', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', widget.analysisId),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(color: Color(0xFFFFD93D), strokeWidth: 2),
                  )
                : const Icon(Icons.find_in_page_rounded, color: Color(0xFFFFD93D)),
            label: Text(
              _running ? 'Analisando...' : 'Analisar',
              style: const TextStyle(color: Color(0xFFFFD93D)),
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
            child: asyncGap.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFFD93D))),
              error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
              data: (gap) => gap == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.find_in_page_outlined, color: Colors.white24, size: 64),
                          const SizedBox(height: 16),
                          const Text('Nenhuma análise de gaps ainda', style: TextStyle(color: Colors.white38)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _running ? null : _run,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD93D),
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Analisar Gaps'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GapSection(
                            icon: Icons.article_rounded,
                            color: const Color(0xFFFF6B6B),
                            title: 'Gaps de Conteúdo',
                            items: gap.contentGaps,
                          ),
                          _GapSection(
                            icon: Icons.search_rounded,
                            color: const Color(0xFF4D96FF),
                            title: 'Gaps de SEO',
                            items: gap.seoGaps,
                          ),
                          _GapSection(
                            icon: Icons.shield_rounded,
                            color: const Color(0xFF6BCB77),
                            title: 'Gaps de Autoridade',
                            items: gap.authorityGaps,
                          ),
                          _GapSection(
                            icon: Icons.attach_money_rounded,
                            color: const Color(0xFFFFD93D),
                            title: 'Gaps de Monetização',
                            items: gap.monetizationGaps,
                          ),
                          _GapSection(
                            icon: Icons.inventory_2_rounded,
                            color: const Color(0xFFAB83FF),
                            title: 'Gaps de Produto',
                            items: gap.productGaps,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A2E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF333355)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.summarize_rounded, color: Color(0xFFFFD93D), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Total: ${gap.totalGaps} gaps identificados',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD93D),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GapSection extends StatelessWidget {
  const _GapSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${items.length}',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF333355), height: 1),
          ...items.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
