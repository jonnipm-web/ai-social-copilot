import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/market_analysis_provider.dart';
import '../../../shared/widgets/app_drawer.dart';

class MarketIntelligenceHubScreen extends ConsumerWidget {
  const MarketIntelligenceHubScreen({super.key, required this.analysisId});
  final String analysisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAnalysis = ref.watch(marketAnalysisByIdProvider(analysisId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        title: const Text('Inteligência de Mercado', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppConstants.routeMarketIntelligence),
        ),
      ),
      drawer: const AppDrawer(),
      body: asyncAnalysis.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00BCD4))),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
        data: (analysis) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Score card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
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
                              Text(
                                analysis.input,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (analysis.niche != null) ...[
                                const SizedBox(height: 4),
                                Text(analysis.niche!, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                        _ScoreBadge(score: analysis.opportunityScore),
                      ],
                    ),
                    if (analysis.executiveSummary.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        analysis.executiveSummary,
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick stats row
              if (analysis.niche != null || analysis.targetAudience != null) ...[
                Row(
                  children: [
                    if (analysis.niche != null)
                      Expanded(child: _InfoChip(label: 'Nicho', value: analysis.niche!)),
                    if (analysis.niche != null && analysis.targetAudience != null)
                      const SizedBox(width: 8),
                    if (analysis.targetAudience != null)
                      Expanded(child: _InfoChip(label: 'Público', value: analysis.targetAudience!)),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Module cards
              const Text(
                'Módulos de Análise',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _ModuleCard(
                icon: Icons.people_alt_rounded,
                color: const Color(0xFFFF6B6B),
                title: 'Concorrentes',
                subtitle: 'Descubra e analise seus competidores',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceCompetitors.replaceFirst(':id', analysisId),
                ),
              ),
              _ModuleCard(
                icon: Icons.find_in_page_rounded,
                color: const Color(0xFFFFD93D),
                title: 'Gap Analysis',
                subtitle: 'Encontre lacunas de conteúdo, SEO e produto',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceGaps.replaceFirst(':id', analysisId),
                ),
              ),
              _ModuleCard(
                icon: Icons.star_rounded,
                color: const Color(0xFF6BCB77),
                title: 'Oportunidades',
                subtitle: 'Score de oportunidade 0-100 por categoria',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceOpportunities.replaceFirst(':id', analysisId),
                ),
              ),
              _ModuleCard(
                icon: Icons.hub_rounded,
                color: const Color(0xFF4D96FF),
                title: 'Nichos & Sub-nichos',
                subtitle: 'Top 10 nichos rankeados por potencial',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceNiches.replaceFirst(':id', analysisId),
                ),
              ),
              _ModuleCard(
                icon: Icons.account_tree_rounded,
                color: const Color(0xFFAB83FF),
                title: 'Content Cluster Engine',
                subtitle: 'Clusters, silos e roadmap editorial',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceCluster.replaceFirst(':id', analysisId),
                ),
              ),
              _ModuleCard(
                icon: Icons.attach_money_rounded,
                color: const Color(0xFF00BCD4),
                title: 'Revenue Planner',
                subtitle: 'Projeções conservador / moderado / agressivo',
                onTap: () => context.go(
                  AppConstants.routeMarketIntelligenceRevenue.replaceFirst(':id', analysisId),
                ),
              ),

              // Recommendations
              if (analysis.recommendations.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Recomendações Executivas',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...analysis.recommendations.asMap().entries.map(
                  (e) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF333355)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: Color(0xFF00BCD4),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                        ),
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final int score;

  Color get _color {
    if (score >= 80) return const Color(0xFF6BCB77);
    if (score >= 60) return const Color(0xFF00BCD4);
    if (score >= 40) return const Color(0xFFFFD93D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: _color, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$score',
            style: TextStyle(color: _color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text('score', style: TextStyle(color: _color.withOpacity(0.7), fontSize: 9)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333355)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
