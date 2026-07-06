import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/knowledge_analysis.dart';
import '../../../data/models/knowledge_item.dart';
import '../../../providers/campaign_provider.dart';
import '../../../providers/knowledge_provider.dart';
import '../../../providers/strategy_provider.dart';

class CampaignBuilderScreen extends ConsumerStatefulWidget {
  const CampaignBuilderScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<CampaignBuilderScreen> createState() =>
      _CampaignBuilderScreenState();
}

class _CampaignBuilderScreenState
    extends ConsumerState<CampaignBuilderScreen> {
  String _objective   = 'Venda';
  int    _duration    = 30;
  final  _channels    = <String>{};
  bool   _generating  = false;

  static const _objectives = [
    'Venda', 'Autoridade', 'Leads', 'Engajamento',
    'Lançamento', 'Tráfego', 'Venda Hotmart',
    'Venda Shopify', 'Venda Amazon', 'Assinatura',
  ];

  static const _durations = [7, 15, 30, 60, 90];

  static const _allChannels = [
    'Instagram', 'Facebook', 'LinkedIn', 'Google',
    'Blog', 'YouTube', 'TikTok', 'Email',
    'Hotmart', 'Shopify', 'Amazon',
  ];

  @override
  Widget build(BuildContext context) {
    final itemAsync     = ref.watch(knowledgeItemByIdProvider(widget.itemId));
    final analysisAsync = ref.watch(knowledgeAnalysisProvider(widget.itemId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        foregroundColor: Colors.white,
        title: const Text(
          'Criar Campanha',
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
                return _noAnalysis(context);
              }
              return _buildForm(context, item, analysis);
            },
          );
        },
      ),
    );
  }

  Widget _noAnalysis(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined,
                size: 64, color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            const Text(
              'Analise o item primeiro para criar uma campanha.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, KnowledgeItem item, KnowledgeAnalysis analysis) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_stories_rounded,
                    color: Color(0xFF6C63FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Objetivo
          _Label('Objetivo da Campanha'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _objectives.map((obj) {
              final sel = _objective == obj;
              return GestureDetector(
                onTap: () => setState(() => _objective = obj),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF6C63FF)
                          : Colors.white12,
                    ),
                  ),
                  child: Text(
                    obj,
                    style: TextStyle(
                      color: sel
                          ? const Color(0xFF6C63FF)
                          : Colors.white54,
                      fontSize: 12,
                      fontWeight: sel
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Duração
          _Label('Duração'),
          const SizedBox(height: 10),
          Row(
            children: _durations.map((d) {
              final sel = _duration == d;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _duration = d),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF6C63FF).withOpacity(0.2)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF6C63FF)
                            : Colors.white12,
                      ),
                    ),
                    child: Text(
                      '${d}d',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFF6C63FF)
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: sel
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Canais
          _Label('Canais (selecione pelo menos 1)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allChannels.map((ch) {
              final sel = _channels.contains(ch);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (sel) {
                      _channels.remove(ch);
                    } else {
                      _channels.add(ch);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF00BCD4).withOpacity(0.15)
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF00BCD4)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sel)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF00BCD4), size: 12),
                      if (sel) const SizedBox(width: 4),
                      Text(
                        ch,
                        style: TextStyle(
                          color: sel
                              ? const Color(0xFF00BCD4)
                              : Colors.white54,
                          fontSize: 12,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // Gerar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.campaign_rounded),
              label: Text(
                _generating ? 'Gerando campanha…' : 'Gerar Campanha com IA',
                style: const TextStyle(fontSize: 15),
              ),
              onPressed: _channels.isEmpty || _generating
                  ? null
                  : () => _generate(context, item, analysis),
            ),
          ),

          if (_channels.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Selecione pelo menos um canal.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFF44336), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(
    BuildContext context,
    KnowledgeItem item,
    KnowledgeAnalysis analysis,
  ) async {
    setState(() => _generating = true);

    try {
      final strategyAsync = ref.read(knowledgeStrategyProvider(item.id));
      final strategy      = strategyAsync.valueOrNull;

      final campaign = await ref
          .read(campaignNotifierProvider.notifier)
          .generate(
            item:         item,
            analysis:     analysis,
            strategy:     strategy,
            objective:    _objective,
            durationDays: _duration,
            channels:     _channels.toList(),
          );

      if (!mounted) return;

      if (campaign != null) {
        ref.invalidate(campaignsProvider);
        ref.invalidate(campaignsByItemProvider(item.id));
        context.go(
          AppConstants.routeCampaignDetail.replaceFirst(':id', campaign.id),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao gerar campanha. Tente novamente.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _Label(String text) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600),
    );
  }
}
