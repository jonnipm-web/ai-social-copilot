import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/knowledge_analysis.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../data/models/knowledge_strategy.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/strategy_provider.dart';

class StrategyScreen extends ConsumerWidget {
  const StrategyScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync     = ref.watch(knowledgeItemByIdProvider(itemId));
    final analysisAsync = ref.watch(knowledgeAnalysisProvider(itemId));
    final strategyAsync = ref.watch(knowledgeStrategyProvider(itemId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Estratégia',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Erro: $e',
                style: const TextStyle(color: Colors.white70))),
        data: (item) {
          if (item == null) {
            return const Center(
                child: Text('Item não encontrado.',
                    style: TextStyle(color: Colors.white70)));
          }
          return analysisAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
                child: Text('Erro: $e',
                    style: const TextStyle(color: Colors.white70))),
            data: (analysis) {
              if (analysis == null) {
                return _NoAnalysis(item: item);
              }
              return strategyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error:   (e, _) => _GeneratePrompt(item: item, analysis: analysis, error: e.toString()),
                data:    (strategy) => strategy == null
                    ? _GeneratePrompt(item: item, analysis: analysis)
                    : _StrategyContent(item: item, strategy: strategy, analysis: analysis),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoAnalysis extends StatelessWidget {
  const _NoAnalysis({required this.item});
  final KnowledgeItem item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            const Text(
              'Análise necessária',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Primeiro analise este item com IA para depois gerar a estratégia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Voltar e Analisar'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratePrompt extends ConsumerWidget {
  const _GeneratePrompt({required this.item, required this.analysis, this.error});
  final KnowledgeItem     item;
  final KnowledgeAnalysis analysis;
  final String?           error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifierState = ref.watch(strategyNotifierProvider);
    final isLoading = notifierState is AsyncLoading;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.rocket_launch_rounded,
                  size: 48, color: Color(0xFF6C63FF)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Gerar Estratégia Completa',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'A IA vai criar um plano estratégico completo com público-alvo, posicionamento, canais, funil, oportunidades comerciais e plano de crescimento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Erro: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF44336), fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            if (isLoading) ...[
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
              const SizedBox(height: 12),
              const Text('Gerando estratégia…',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
            ] else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.rocket_launch_rounded),
                label: const Text('Gerar Estratégia', style: TextStyle(fontSize: 15)),
                onPressed: () async {
                  final strategy = await ref
                      .read(strategyNotifierProvider.notifier)
                      .generate(item, analysis);
                  if (strategy != null) {
                    ref.invalidate(knowledgeStrategyProvider(item.id));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StrategyContent extends ConsumerWidget {
  const _StrategyContent({
    required this.item,
    required this.strategy,
    required this.analysis,
  });

  final KnowledgeItem     item;
  final KnowledgeStrategy strategy;
  final KnowledgeAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strategy.strategyJson;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        // Header
        _StratHeader(title: item.title, niche: item.niche),
        const SizedBox(height: 16),

        // Resumo estratégico
        if (strategy.strategicSummary.isNotEmpty) ...[
          _Section('Resumo Estratégico', Icons.summarize_rounded, const Color(0xFF6C63FF)),
          _HighlightCard(strategy.strategicSummary, const Color(0xFF6C63FF)),
          const SizedBox(height: 16),
        ],

        // Proposta de valor
        if (strategy.valueProposition.isNotEmpty) ...[
          _Section('Proposta de Valor', Icons.diamond_rounded, const Color(0xFFFFD700)),
          _HighlightCard(strategy.valueProposition, const Color(0xFFFFD700)),
          const SizedBox(height: 16),
        ],

        // Posicionamento
        if (strategy.positioning.isNotEmpty) ...[
          _Section('Posicionamento', Icons.flag_rounded, const Color(0xFF00BCD4)),
          _HighlightCard(strategy.positioning, const Color(0xFF00BCD4)),
          const SizedBox(height: 16),
        ],

        // Público-alvo
        _buildAudience(s),

        // Canais recomendados
        if (strategy.recommendedChannels.isNotEmpty) ...[
          _Section('Canais Recomendados', Icons.broadcast_on_personal_rounded, const Color(0xFF4CAF50)),
          const SizedBox(height: 8),
          ...strategy.recommendedChannels.map((ch) => _ChannelTile(ch)),
          const SizedBox(height: 16),
        ],

        // Funil
        if (strategy.funnel.isNotEmpty) ...[
          _Section('Funil de Marketing', Icons.filter_alt_rounded, const Color(0xFFFF9800)),
          const SizedBox(height: 8),
          _FunnelCard(strategy.funnel),
          const SizedBox(height: 16),
        ],

        // Oportunidades comerciais
        if (strategy.commercialOpportunities.isNotEmpty) ...[
          _Section('Oportunidades Comerciais', Icons.monetization_on_rounded, const Color(0xFFFFD700)),
          const SizedBox(height: 8),
          ...strategy.commercialOpportunities.map((op) => _OpportunityTile(op)),
          const SizedBox(height: 16),
        ],

        // Keywords prioritárias
        if (strategy.priorityKeywords.isNotEmpty) ...[
          _Section('Keywords Prioritárias', Icons.key_rounded, const Color(0xFF9C27B0)),
          const SizedBox(height: 8),
          _ChipRow(strategy.priorityKeywords, const Color(0xFF9C27B0)),
          const SizedBox(height: 16),
        ],

        // Quick wins
        if (strategy.quickWins.isNotEmpty) ...[
          _Section('Ações Rápidas', Icons.bolt_rounded, const Color(0xFFFF5722)),
          const SizedBox(height: 8),
          ...strategy.quickWins.map((w) => _BulletItem(w, const Color(0xFFFF5722))),
          const SizedBox(height: 16),
        ],

        // Plano de crescimento
        if (strategy.growthPlan.isNotEmpty) ...[
          _Section('Plano de Crescimento', Icons.trending_up_rounded, const Color(0xFF4CAF50)),
          const SizedBox(height: 8),
          _GrowthCard(strategy.growthPlan),
          const SizedBox(height: 16),
        ],

        // Regenerar
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white12),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Regenerar Estratégia', style: TextStyle(fontSize: 13)),
          onPressed: () async {
            ref.invalidate(knowledgeStrategyProvider(item.id));
            await ref
                .read(strategyNotifierProvider.notifier)
                .generate(item, analysis);
            ref.invalidate(knowledgeStrategyProvider(item.id));
          },
        ),
      ],
    );
  }

  Widget _buildAudience(Map<String, dynamic> s) {
    final audience = s['target_audience'];
    if (audience == null) return const SizedBox.shrink();
    final a = audience is Map ? Map<String, dynamic>.from(audience) : <String, dynamic>{};
    if (a.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section('Público-alvo', Icons.people_rounded, const Color(0xFFE91E63)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a['primary'] != null)
                _AudienceRow('Primário', a['primary'].toString(), const Color(0xFFE91E63)),
              if (a['secondary'] != null)
                _AudienceRow('Secundário', a['secondary'].toString(), Colors.white54),
              if (a['age_range'] != null)
                _AudienceRow('Faixa etária', a['age_range'].toString(), Colors.white38),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _StratHeader extends StatelessWidget {
  const _StratHeader({required this.title, this.niche});
  final String  title;
  final String? niche;

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
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_rounded, color: Color(0xFF6C63FF), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                if (niche != null)
                  Text(niche!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.icon, this.color);
  final String   title;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard(this.text, this.color);
  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copiado!'),
            duration: Duration(seconds: 1),
            backgroundColor: Color(0xFF1A1A2E),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.copy_rounded, color: color.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile(this.data);
  final Map<String, dynamic> data;

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'alta':  return const Color(0xFF4CAF50);
      case 'média': return const Color(0xFFFF9800);
      default:      return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final channel  = data['channel'] as String? ?? '';
    final priority = data['priority'] as String? ?? '';
    final reason   = data['reason'] as String? ?? '';
    final color    = _priorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(priority,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (reason.isNotEmpty)
                  Text(reason,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard(this.funnel);
  final Map<String, dynamic> funnel;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Awareness', funnel['awareness'], const Color(0xFF6C63FF)),
      ('Consideração', funnel['consideration'], const Color(0xFF00BCD4)),
      ('Conversão', funnel['conversion'], const Color(0xFF4CAF50)),
      ('Retenção', funnel['retention'], const Color(0xFFFFD700)),
    ];

    return Column(
      children: stages
          .where((s) => s.$2 != null && s.$2.toString().isNotEmpty)
          .map((s) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.$3.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: s.$3.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 70,
                      child: Text(s.$1,
                          style: TextStyle(
                              color: s.$3,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: Text(s.$2.toString(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12, height: 1.4)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile(this.data);
  final Map<String, dynamic> data;

  Color _potentialColor(String p) {
    switch (p.toLowerCase()) {
      case 'alto':  return const Color(0xFF4CAF50);
      case 'médio': return const Color(0xFFFF9800);
      default:      return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type        = data['type'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final potential   = data['potential'] as String? ?? '';
    final color       = _potentialColor(potential);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Color(0xFFFFD700), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                if (description.isNotEmpty)
                  Text(description,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (potential.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(potential,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow(this.items, this.color);
  final List<String> items;
  final Color        color;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((kw) => GestureDetector(
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              ))
          .toList(),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem(this.text, this.color);
  final String text;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.bolt_rounded, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _GrowthCard extends StatelessWidget {
  const _GrowthCard(this.plan);
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final months = [
      ('Mês 1', plan['month_1']),
      ('Mês 2', plan['month_2']),
      ('Mês 3', plan['month_3']),
    ];

    final kpis = plan['kpis'];
    final kpiList = kpis is List ? kpis.map((e) => e.toString()).toList() : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...months
            .where((m) => m.$2 != null && m.$2.toString().isNotEmpty)
            .map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 45,
                        child: Text(m.$1,
                            style: const TextStyle(
                                color: Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                      Expanded(
                        child: Text(m.$2.toString(),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                )),
        if (kpiList.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('KPIs',
              style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: kpiList
                .map((k) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF4CAF50).withOpacity(0.3)),
                      ),
                      child: Text(k,
                          style: const TextStyle(
                              color: Color(0xFF4CAF50), fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AudienceRow extends StatelessWidget {
  const _AudienceRow(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
