import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/knowledge_analysis.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../providers/knowledge_provider.dart';

class KnowledgeAnalysisScreen extends ConsumerWidget {
  const KnowledgeAnalysisScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync     = ref.watch(knowledgeItemByIdProvider(itemId));
    final analysisAsync = ref.watch(knowledgeAnalysisProvider(itemId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Análise de Conhecimento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          itemAsync.maybeWhen(
            data: (item) => item == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded),
                    tooltip: 'Re-analisar',
                    onPressed: () async {
                      await ref
                          .read(knowledgeAnalysisNotifierProvider.notifier)
                          .analyze(item);
                      ref.invalidate(knowledgeAnalysisProvider(itemId));
                      ref.invalidate(knowledgeItemsProvider);
                    },
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: Colors.white70)),
        ),
        data: (item) {
          if (item == null) {
            return const Center(
              child: Text('Item não encontrado.',
                  style: TextStyle(color: Colors.white70)),
            );
          }
          return analysisAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _NoAnalysis(item: item, error: e.toString()),
            data: (analysis) => analysis == null
                ? _NoAnalysis(item: item)
                : _AnalysisContent(item: item, analysis: analysis),
          );
        },
      ),
    );
  }
}

// ── No analysis yet ──────────────────────────────────────────

class _NoAnalysis extends ConsumerWidget {
  const _NoAnalysis({required this.item, this.error});

  final KnowledgeItem item;
  final String?       error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(knowledgeAnalysisNotifierProvider) is AsyncLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined,
                size: 64, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            if (error != null) ...[
              Text(
                'Erro: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF44336), fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              isLoading
                  ? 'Analisando com IA…'
                  : 'Este item ainda não foi analisado.',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            if (!isLoading)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Analisar com IA'),
                onPressed: () async {
                  await ref
                      .read(knowledgeAnalysisNotifierProvider.notifier)
                      .analyze(item);
                  ref.invalidate(knowledgeAnalysisProvider(item.id));
                  ref.invalidate(knowledgeItemsProvider);
                },
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// ── Full analysis view ───────────────────────────────────────

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.item, required this.analysis});

  final KnowledgeItem     item;
  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _ItemHeader(item: item),
        const SizedBox(height: 16),

        if (analysis.summary != null) ...[
          _SectionTitle('Resumo'),
          _SummaryCard(analysis.summary!),
          const SizedBox(height: 16),
        ],

        _SectionTitle('Pontuações por Canal'),
        const SizedBox(height: 8),
        _ScoreGrid(analysis: analysis),
        const SizedBox(height: 16),

        _SectionTitle('Palavras-chave'),
        const SizedBox(height: 8),
        if (analysis.keywordsPrimary.isNotEmpty)
          _ChipSection('Primárias', analysis.keywordsPrimary,
              const Color(0xFF6C63FF)),
        if (analysis.keywordsSecondary.isNotEmpty)
          _ChipSection('Secundárias', analysis.keywordsSecondary,
              const Color(0xFF00BCD4)),
        if (analysis.keywordsLongtail.isNotEmpty)
          _ChipSection('Long-tail', analysis.keywordsLongtail,
              const Color(0xFF4CAF50)),
        const SizedBox(height: 8),

        if (analysis.audiencePainPoints.isNotEmpty) ...[
          _SectionTitle('Dores da Audiência'),
          _ListCards(analysis.audiencePainPoints,
              Icons.sentiment_dissatisfied_rounded, const Color(0xFFF44336)),
          const SizedBox(height: 12),
        ],
        if (analysis.audienceDesires.isNotEmpty) ...[
          _SectionTitle('Desejos da Audiência'),
          _ListCards(analysis.audienceDesires, Icons.favorite_rounded,
              const Color(0xFFE91E63)),
          const SizedBox(height: 12),
        ],

        if (analysis.contentPillars.isNotEmpty) ...[
          _SectionTitle('Pilares de Conteúdo'),
          _ChipSection('', analysis.contentPillars, const Color(0xFFFF9800)),
          const SizedBox(height: 8),
        ],
        if (analysis.topics.isNotEmpty) ...[
          _SectionTitle('Tópicos Principais'),
          _ChipSection('', analysis.topics, const Color(0xFF9C27B0)),
          const SizedBox(height: 8),
        ],

        if (analysis.postIdeas.isNotEmpty) ...[
          _SectionTitle('Ideias de Posts para Redes Sociais'),
          _ListCards(analysis.postIdeas, Icons.chat_bubble_outline_rounded,
              const Color(0xFF00BCD4)),
          const SizedBox(height: 12),
        ],
        if (analysis.campaignIdeas.isNotEmpty) ...[
          _SectionTitle('Ideias de Campanhas'),
          _ListCards(analysis.campaignIdeas, Icons.campaign_rounded,
              const Color(0xFFFF9800)),
          const SizedBox(height: 12),
        ],
        if (analysis.articleIdeas.isNotEmpty) ...[
          _SectionTitle('Ideias de Artigos / Blog'),
          _ListCards(analysis.articleIdeas, Icons.article_rounded,
              const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
        ],

        if (analysis.commercialAngles.isNotEmpty) ...[
          _SectionTitle('Ângulos Comerciais'),
          _ListCards(analysis.commercialAngles, Icons.monetization_on_rounded,
              const Color(0xFFFFD700)),
          const SizedBox(height: 12),
        ],
        if (analysis.ctas.isNotEmpty) ...[
          _SectionTitle('CTAs Sugeridas'),
          _ChipSection('', analysis.ctas, const Color(0xFFFFD700)),
          const SizedBox(height: 8),
        ],

        if (analysis.seoOpportunities.isNotEmpty) ...[
          _SectionTitle('Oportunidades SEO'),
          _ListCards(analysis.seoOpportunities, Icons.search_rounded,
              const Color(0xFF4CAF50)),
          const SizedBox(height: 12),
        ],
        if (analysis.adsenseOpportunities.isNotEmpty) ...[
          _SectionTitle('Oportunidades AdSense'),
          _ListCards(analysis.adsenseOpportunities, Icons.attach_money_rounded,
              const Color(0xFF8BC34A)),
          const SizedBox(height: 12),
        ],
        if (analysis.amazonKdpOpportunities.isNotEmpty) ...[
          _SectionTitle('Oportunidades Amazon KDP'),
          _ListCards(analysis.amazonKdpOpportunities, Icons.book_rounded,
              const Color(0xFFFF5722)),
          const SizedBox(height: 12),
        ],

        if (analysis.scoreDetails.isNotEmpty) ...[
          _SectionTitle('Detalhes por Canal'),
          _ScoreDetailsSection(analysis.scoreDetails),
        ],
      ],
    );
  }
}

// ── Common widgets ───────────────────────────────────────────

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});

  final KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.3),
            const Color(0xFF6C63FF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded,
              color: Color(0xFF6C63FF), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.niche != null)
                  Text(item.niche!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.summary);

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(summary,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.5)),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.analysis});

  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final scores = [
      _ScoreData('SEO', analysis.scoreSeo, const Color(0xFF4CAF50),
          Icons.search_rounded),
      _ScoreData('AdSense', analysis.scoreAdsense, const Color(0xFF8BC34A),
          Icons.attach_money_rounded),
      _ScoreData('Amazon KDP', analysis.scoreAmazonKdp,
          const Color(0xFFFF5722), Icons.book_rounded),
      _ScoreData('LinkedIn', analysis.scoreLinkedin, const Color(0xFF0077B5),
          Icons.business_rounded),
      _ScoreData('Social', analysis.scoreSocial, const Color(0xFFE91E63),
          Icons.people_rounded),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scores.map((s) => _ScoreCard(data: s)).toList(),
    );
  }
}

class _ScoreData {
  _ScoreData(this.label, this.score, this.color, this.icon);
  final String   label;
  final int      score;
  final Color    color;
  final IconData icon;
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.data});

  final _ScoreData data;

  Color get _barColor {
    if (data.score >= 70) return const Color(0xFF4CAF50);
    if (data.score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: data.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(data.icon, color: data.color, size: 20),
          const SizedBox(height: 6),
          Text(
            '${data.score}',
            style: TextStyle(
              color: _barColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(data.label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: data.score / 100,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection(this.label, this.items, this.color);

  final String       label;
  final List<String> items;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (kw) => GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: kw));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copiado: $kw'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: const Color(0xFF1A1A2E),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(kw,
                        style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ListCards extends StatelessWidget {
  const _ListCards(this.items, this.icon, this.color);

  final List<String> items;
  final IconData     icon;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copiado!'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Color(0xFF1A1A2E),
                        ),
                      );
                    },
                    child: const Icon(Icons.copy_rounded,
                        color: Colors.white24, size: 15),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ScoreDetailsSection extends StatelessWidget {
  const _ScoreDetailsSection(this.details);

  final Map<String, dynamic> details;

  static const _channelLabels = {
    'seo':        'SEO',
    'adsense':    'AdSense',
    'amazon_kdp': 'Amazon KDP',
    'linkedin':   'LinkedIn',
    'social':     'Social Media',
  };

  @override
  Widget build(BuildContext context) {
    final channels = _channelLabels.entries
        .where((e) => details.containsKey(e.key))
        .toList();

    return Column(
      children: channels.map((e) {
        final ch = details[e.key] as Map<String, dynamic>? ?? {};
        return _ChannelDetail(label: e.value, data: ch);
      }).toList(),
    );
  }
}

class _ChannelDetail extends StatefulWidget {
  const _ChannelDetail({required this.label, required this.data});

  final String               label;
  final Map<String, dynamic> data;

  @override
  State<_ChannelDetail> createState() => _ChannelDetailState();
}

class _ChannelDetailState extends State<_ChannelDetail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final strengths    = _list(widget.data['strengths']);
    final weaknesses   = _list(widget.data['weaknesses']);
    final improvements = _list(widget.data['improvements']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            trailing: Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: Colors.white38,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (strengths.isNotEmpty) ...[
                    _SubLabel('Pontos Fortes', const Color(0xFF4CAF50)),
                    ...strengths.map((s) => _DetailItem(s, const Color(0xFF4CAF50))),
                    const SizedBox(height: 6),
                  ],
                  if (weaknesses.isNotEmpty) ...[
                    _SubLabel('Pontos Fracos', const Color(0xFFF44336)),
                    ...weaknesses.map((s) => _DetailItem(s, const Color(0xFFF44336))),
                    const SizedBox(height: 6),
                  ],
                  if (improvements.isNotEmpty) ...[
                    _SubLabel('Melhorias', const Color(0xFF6C63FF)),
                    ...improvements.map((s) => _DetailItem(s, const Color(0xFF6C63FF))),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static List<String> _list(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text, this.color);

  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem(this.text, this.color);

  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 6, color: color.withOpacity(0.7)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
