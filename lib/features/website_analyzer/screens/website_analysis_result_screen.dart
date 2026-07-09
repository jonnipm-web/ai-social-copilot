import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/website_analysis.dart';
import '../../../providers/website_analyzer_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class WebsiteAnalysisResultScreen extends ConsumerWidget {
  final String analysisId;

  const WebsiteAnalysisResultScreen({super.key, required this.analysisId});

  static const Color _background = Color(0xFF0F0F1A);
  static const Color _cardColor = Color(0xFF1A1A2E);
  static const Color _primary = Color(0xFF6C63FF);
  static const Color _accent = Color(0xFF00BCD4);

  Color _scoreColor(num score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(websiteAnalysisByIdProvider(analysisId));

    return Scaffold(
      backgroundColor: _background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: const Text(
          'Análise do Site',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          analysisAsync.whenOrNull(
            data: (analysis) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Análise já salva no banco de dados!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.lock, size: 16, color: _accent),
                  label: const Text(
                    'Salvar no Cofre',
                    style: TextStyle(color: _accent, fontSize: 13),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    context.go(
                      '/knowledge/new',
                      extra: {'prefillUrl': analysis.url},
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16, color: _primary),
                  label: const Text(
                    'Criar Estratégia',
                    style: TextStyle(color: _primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: analysisAsync.whenOrNull(
        data: (analysis) => _BottomActionBar(
          analysis: analysis,
          primary: _primary,
          accent: _accent,
          cardColor: _cardColor,
        ),
      ),
      body: analysisAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _accent),
              SizedBox(height: 16),
              Text(
                'Carregando análise...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erro ao carregar análise',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (analysis) => _AnalysisContent(
          analysis: analysis,
          scoreColor: _scoreColor,
          background: _background,
          cardColor: _cardColor,
          primary: _primary,
          accent: _accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content widget
// ---------------------------------------------------------------------------

class _AnalysisContent extends StatelessWidget {
  final WebsiteAnalysis analysis;
  final Color Function(num) scoreColor;
  final Color background;
  final Color cardColor;
  final Color primary;
  final Color accent;

  const _AnalysisContent({
    required this.analysis,
    required this.scoreColor,
    required this.background,
    required this.cardColor,
    required this.primary,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final websiteScore = analysis.scoreWebsite;
    final adsenseScore = analysis.scoreAdsense;
    final seoScore = analysis.scoreSeo;
    final monetizationScore = analysis.scoreMonetization;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.language, color: accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis.url,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.white.withOpacity(0.5), size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: analysis.url));
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4 Score Cards
          Row(
            children: [
              Expanded(
                child: _ScoreCard(
                  label: 'Website',
                  score: websiteScore,
                  icon: Icons.language,
                  color: scoreColor(websiteScore),
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreCard(
                  label: 'AdSense',
                  score: adsenseScore,
                  icon: Icons.monetization_on,
                  color: scoreColor(adsenseScore),
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreCard(
                  label: 'SEO',
                  score: seoScore,
                  icon: Icons.search,
                  color: scoreColor(seoScore),
                  cardColor: cardColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScoreCard(
                  label: 'Monetização',
                  score: monetizationScore,
                  icon: Icons.payments,
                  color: scoreColor(monetizationScore),
                  cardColor: cardColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Expandable Sections
          _ExpandableSection(
            title: 'Diagnóstico',
            icon: Icons.analytics,
            iconColor: primary,
            cardColor: cardColor,
            initiallyExpanded: true,
            child: _DiagnosticContent(analysis: analysis),
          ),

          const SizedBox(height: 8),

          if (analysis.strengths.isNotEmpty)
            _ExpandableSection(
              title: 'Pontos Fortes',
              icon: Icons.thumb_up,
              iconColor: Colors.green,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.strengths,
                color: Colors.green,
              ),
            ),

          if (analysis.strengths.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.weaknesses.isNotEmpty)
            _ExpandableSection(
              title: 'Pontos Fracos',
              icon: Icons.thumb_down,
              iconColor: Colors.orange,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.weaknesses,
                color: Colors.orange,
              ),
            ),

          if (analysis.weaknesses.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.criticalIssues.isNotEmpty)
            _ExpandableSection(
              title: 'Problemas Críticos',
              icon: Icons.warning_amber,
              iconColor: Colors.red,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.criticalIssues,
                color: Colors.red,
              ),
            ),

          if (analysis.criticalIssues.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.seoAnalysis.isNotEmpty)
            _ExpandableSection(
              title: 'Análise SEO',
              icon: Icons.search,
              iconColor: accent,
              cardColor: cardColor,
              child: _MapContent(data: analysis.seoAnalysis),
            ),

          if (analysis.seoAnalysis.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.adsenseAnalysis.isNotEmpty)
            _ExpandableSection(
              title: 'Análise AdSense',
              icon: Icons.monetization_on,
              iconColor: Colors.amber,
              cardColor: cardColor,
              child: _AdsenseContent(analysis: analysis),
            ),

          if (analysis.adsenseAnalysis.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.quickWins.isNotEmpty)
            _ExpandableSection(
              title: 'Vitórias Rápidas',
              icon: Icons.bolt,
              iconColor: Colors.yellow,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.quickWins,
                color: Colors.green,
                bulletChar: '✓',
              ),
            ),

          if (analysis.quickWins.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.plan7Days.isNotEmpty)
            _ExpandableSection(
              title: 'Plano 7 Dias',
              icon: Icons.calendar_today,
              iconColor: primary,
              cardColor: cardColor,
              child: _NumberedList(items: analysis.plan7Days),
            ),

          if (analysis.plan7Days.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.plan30Days.isNotEmpty)
            _ExpandableSection(
              title: 'Plano 30 Dias',
              icon: Icons.date_range,
              iconColor: primary,
              cardColor: cardColor,
              child: _NumberedList(items: analysis.plan30Days),
            ),

          if (analysis.plan30Days.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.articleIdeas.isNotEmpty)
            _ExpandableSection(
              title: 'Ideias de Artigos',
              icon: Icons.article,
              iconColor: accent,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.articleIdeas,
                color: accent,
              ),
            ),

          if (analysis.articleIdeas.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.monetizationOpportunities.isNotEmpty)
            _ExpandableSection(
              title: 'Oportunidades de Monetização',
              icon: Icons.attach_money,
              iconColor: Colors.green,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.monetizationOpportunities,
                color: Colors.green,
              ),
            ),

          if (analysis.monetizationOpportunities.isNotEmpty)
            const SizedBox(height: 8),

          if (analysis.commercialOpportunities.isNotEmpty)
            _ExpandableSection(
              title: 'Oportunidades Comerciais',
              icon: Icons.business_center,
              iconColor: Colors.amber,
              cardColor: cardColor,
              child: _BulletList(
                items: analysis.commercialOpportunities,
                color: Colors.amber,
              ),
            ),

          // Bottom padding for the bottom bar
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score Card widget
// ---------------------------------------------------------------------------

class _ScoreCard extends StatelessWidget {
  final String label;
  final num score;
  final IconData icon;
  final Color color;
  final Color cardColor;

  const _ScoreCard({
    required this.label,
    required this.score,
    required this.icon,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable Section
// ---------------------------------------------------------------------------

class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color cardColor;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.cardColor,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content sub-widgets
// ---------------------------------------------------------------------------

class _DiagnosticContent extends StatelessWidget {
  final WebsiteAnalysis analysis;

  const _DiagnosticContent({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final mainTopics = () {
      final raw = analysis.analysisJson['main_topics'];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return <String>[];
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (analysis.title != null) ...[
          Text(
            analysis.title!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (analysis.description != null) ...[
          Text(
            analysis.description!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (mainTopics.isNotEmpty) ...[
          Text(
            'Tópicos Principais:',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: mainTopics
                .map(
                  (topic) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      topic,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color color;
  final String bulletChar;

  const _BulletList({
    required this.items,
    required this.color,
    this.bulletChar = '•',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$bulletChar ',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;

  const _NumberedList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${entry.key + 1}',
                  style: const TextStyle(
                    color: Color(0xFF6C63FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MapContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MapContent({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        final key = entry.key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
        final value = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              if (value is List)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: (value as List).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: const Color(0xFF00BCD4).withOpacity(0.7),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$item',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                Text(
                  '$value',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              Divider(color: Colors.white.withOpacity(0.08), height: 12),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _AdsenseContent extends StatelessWidget {
  final WebsiteAnalysis analysis;

  const _AdsenseContent({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final adsenseData = analysis.adsenseAnalysis;

    final hasPrivacyPolicy = adsenseData['has_privacy_policy'] == true;
    final hasAboutPage = adsenseData['has_about_page'] == true;
    final hasContactPage = adsenseData['has_contact'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Policy indicators
        Row(
          children: [
            _PolicyIndicator(
              label: 'Política de Privacidade',
              hasIt: hasPrivacyPolicy,
            ),
            const SizedBox(width: 8),
            _PolicyIndicator(
              label: 'Sobre',
              hasIt: hasAboutPage,
            ),
            const SizedBox(width: 8),
            _PolicyIndicator(
              label: 'Contato',
              hasIt: hasContactPage,
            ),
          ],
        ),
        if (adsenseData.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MapContent(data: adsenseData),
        ],
      ],
    );
  }
}

class _PolicyIndicator extends StatelessWidget {
  final String label;
  final bool hasIt;

  const _PolicyIndicator({required this.label, required this.hasIt});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: (hasIt ? Colors.green : Colors.red).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (hasIt ? Colors.green : Colors.red).withOpacity(0.4),
          ),
        ),
        child: Column(
          children: [
            Icon(
              hasIt ? Icons.check_circle : Icons.cancel,
              color: hasIt ? Colors.green : Colors.red,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom Action Bar
// ---------------------------------------------------------------------------

class _BottomActionBar extends StatelessWidget {
  final WebsiteAnalysis analysis;
  final Color primary;
  final Color accent;
  final Color cardColor;

  const _BottomActionBar({
    required this.analysis,
    required this.primary,
    required this.accent,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'Criar Estratégia',
                icon: Icons.auto_awesome,
                color: primary,
                onTap: () => context.go(
                  '/knowledge/new',
                  extra: {'prefillUrl': analysis.url},
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                label: 'Criar Campanha',
                icon: Icons.campaign,
                color: accent,
                onTap: () => context.go(
                  '/campaigns/new',
                  extra: {'websiteUrl': analysis.url},
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                label: 'Plano SEO',
                icon: Icons.search,
                color: Colors.green,
                onTap: () => context.go(
                  '/seo-plan/new',
                  extra: {'analysisId': analysis.id},
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _ActionButton(
                label: 'Plano AdSense',
                icon: Icons.monetization_on,
                color: Colors.amber,
                onTap: () => context.go(
                  '/adsense-plan/new',
                  extra: {'analysisId': analysis.id},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
