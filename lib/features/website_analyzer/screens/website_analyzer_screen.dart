import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/website_analyzer_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class WebsiteAnalyzerScreen extends ConsumerStatefulWidget {
  const WebsiteAnalyzerScreen({super.key});

  @override
  ConsumerState<WebsiteAnalyzerScreen> createState() =>
      _WebsiteAnalyzerScreenState();
}

class _WebsiteAnalyzerScreenState extends ConsumerState<WebsiteAnalyzerScreen> {
  final TextEditingController _urlController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const Color _background = Color(0xFF0F0F1A);
  static const Color _cardColor = Color(0xFF1A1A2E);
  static const Color _primary = Color(0xFF6C63FF);
  static const Color _accent = Color(0xFF00BCD4);

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Color _scoreColor(num score) {
    if (score > 70) return Colors.green;
    if (score > 40) return Colors.orange;
    return Colors.red;
  }

  Future<void> _analyze() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final url = _urlController.text.trim();
    try {
      final analysisId = await ref
          .read(websiteAnalyzerNotifierProvider.notifier)
          .analyze(url);
      if (mounted) {
        context.go('/website-analyzer/$analysisId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao analisar o site: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final analyzerState = ref.watch(websiteAnalyzerNotifierProvider);
    final analysesAsync = ref.watch(websiteAnalysesProvider);

    return Scaffold(
      backgroundColor: _background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: _cardColor,
        title: const Text(
          'Website Analyzer',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, color: _accent, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Analisar Website',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analise seu site e receba um diagnóstico completo com SEO, AdSense e oportunidades de monetização.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // URL Input Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'URL do site (ex: https://meusite.com)',
                      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                      hintText: 'https://meusite.com',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(Icons.link, color: _accent),
                      filled: true,
                      fillColor: _cardColor,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _accent.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _accent, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Por favor, insira a URL do site';
                      }
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'URL inválida. Use o formato https://meusite.com';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: analyzerState.isLoading ? null : _analyze,
                      icon: analyzerState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        analyzerState.isLoading ? 'Analisando...' : 'Analisar Site',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _accent.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Previous Analyses Section
            Row(
              children: [
                Icon(Icons.history, color: _primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Análises Anteriores',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            analysesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: _accent),
                ),
              ),
              error: (error, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Erro ao carregar análises: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (analyses) {
                if (analyses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.language_outlined,
                          size: 48,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma análise ainda',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Insira uma URL acima para começar',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: analyses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final analysis = analyses[index];
                    final websiteScore = analysis.scoreWebsite;
                    final adsenseScore = analysis.scoreAdsense;
                    final displayUrl = analysis.url.length > 40
                        ? '${analysis.url.substring(0, 40)}...'
                        : analysis.url;

                    final dateStr = _formatDate(analysis.createdAt);

                    return InkWell(
                      onTap: () => context.go('/website-analyzer/${analysis.id}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, color: _accent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayUrl,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 12,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _ScoreChip(
                                  label: 'Site',
                                  score: websiteScore,
                                  color: _scoreColor(websiteScore),
                                ),
                                const SizedBox(width: 8),
                                _ScoreChip(
                                  label: 'AdSense',
                                  score: adsenseScore,
                                  color: _scoreColor(adsenseScore),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final num score;
  final Color color;

  const _ScoreChip({
    required this.label,
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$label: ${score.toStringAsFixed(0)}',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
