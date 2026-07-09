import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/market_analysis_provider.dart';

class ContentClusterScreen extends ConsumerStatefulWidget {
  const ContentClusterScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  ConsumerState<ContentClusterScreen> createState() => _ContentClusterScreenState();
}

class _ContentClusterScreenState extends ConsumerState<ContentClusterScreen> {
  bool _running = false;
  String? _error;
  final _keywordCtrl = TextEditingController();

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  Future<void> _build() async {
    final kw = _keywordCtrl.text.trim();
    if (kw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite a palavra-chave principal'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() { _running = true; _error = null; });
    try {
      final analysis = await ref.read(marketAnalysisByIdProvider(widget.analysisId).future);
      await ref.read(marketAnalysisServiceProvider).buildContentCluster(widget.analysisId, analysis.input, kw);
      ref.invalidate(contentClusterByAnalysisProvider(widget.analysisId));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCluster = ref.watch(contentClusterByAnalysisProvider(widget.analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Content Cluster Engine', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            AppConstants.routeMarketIntelligenceHub.replaceFirst(':id', widget.analysisId),
          ),
        ),
      ),
      body: asyncCluster.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFAB83FF))),
        error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (cluster) => cluster == null
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.account_tree_outlined, color: Colors.white24, size: 64),
                    const SizedBox(height: 16),
                    const Text('Nenhum cluster ainda', style: TextStyle(color: Colors.white38)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _keywordCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Palavra-chave principal',
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
                          borderSide: const BorderSide(color: Color(0xFFAB83FF)),
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
                            : const Icon(Icons.account_tree_rounded),
                        label: Text(_running ? 'Gerando...' : 'Gerar Content Cluster'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFAB83FF),
                          foregroundColor: Colors.white,
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFAB83FF).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.key_rounded, color: Color(0xFFAB83FF), size: 18),
                          const SizedBox(width: 8),
                          Text('Palavra-chave: ${cluster.mainKeyword}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ClusterSection(title: 'Clusters de Conteúdo', color: const Color(0xFFAB83FF), items: cluster.clusters, labelKey: 'name', descKey: 'description'),
                    _ClusterSection(title: 'Silos de SEO', color: const Color(0xFF4D96FF), items: cluster.silos, labelKey: 'name', descKey: 'description'),
                    _ArticleSection(articles: cluster.articles),
                    _RoadmapSection(roadmap: cluster.editorialRoadmap),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ClusterSection extends StatelessWidget {
  const _ClusterSection({
    required this.title,
    required this.color,
    required this.items,
    required this.labelKey,
    required this.descKey,
  });

  final String title;
  final Color color;
  final List<Map<String, dynamic>> items;
  final String labelKey;
  final String descKey;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item[labelKey]?.toString() ?? '',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                if ((item[descKey]?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item[descKey].toString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({required this.articles});
  final List<Map<String, dynamic>> articles;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Artigos Sugeridos', style: TextStyle(color: Color(0xFF6BCB77), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...articles.asMap().entries.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6BCB77).withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BCB77).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${e.key + 1}',
                        style: const TextStyle(color: Color(0xFF6BCB77), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value['title']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      if (e.value['keyword'] != null)
                        Text('Keyword: ${e.value['keyword']}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _RoadmapSection extends StatelessWidget {
  const _RoadmapSection({required this.roadmap});
  final List<Map<String, dynamic>> roadmap;

  @override
  Widget build(BuildContext context) {
    if (roadmap.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Roadmap Editorial', style: TextStyle(color: Color(0xFFFFD93D), fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...roadmap.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD93D).withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['month'] != null)
                  Text('Mês ${item['month']}', style: const TextStyle(color: Color(0xFFFFD93D), fontSize: 12, fontWeight: FontWeight.bold)),
                if (item['focus'] != null)
                  Text(item['focus'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
