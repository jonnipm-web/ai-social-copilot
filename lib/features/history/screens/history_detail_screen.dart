import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/post_generation.dart';
import '../../../providers/post_provider.dart';
import '../../../shared/widgets/result_block.dart';
import '../../../shared/widgets/score_chip.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final String id;

  const HistoryDetailScreen({super.key, required this.id});

  void _copyAll(BuildContext context, PostGeneration gen) {
    final text = [
      '✨ Post Melhorado\n${gen.improvedText}',
      '💼 Versão Profissional\n${gen.professionalVersion}',
      '😊 Versão Descontraída\n${gen.casualVersion}',
      '📈 Versão Persuasiva\n${gen.persuasiveVersion}',
      '💬 Sugestão de Resposta a Comentários\n${gen.commentReply}',
    ].join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    showSuccessSnack(context, 'Conteúdo copiado com sucesso!');
  }

  String _formatDateTime(DateTime dt) {
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date às $time';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(generationDetailProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe'),
        actions: [
          detailAsync.whenOrNull(
            data: (gen) => TextButton.icon(
              onPressed: () => _copyAll(context, gen),
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Copiar Tudo'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: detailAsync.when(
            loading: () => _buildShimmer(),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível carregar este item.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            data: (gen) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Cabeçalho: texto original + data
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Texto original',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white38,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateTime(gen.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        gen.originalText,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Scores
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ScoreChip(label: 'Clareza', score: gen.clarityScore),
                    ScoreChip(label: 'Impacto', score: gen.impactScore),
                    ScoreChip(label: 'Engajamento', score: gen.engagementScore),
                  ],
                ),
                const SizedBox(height: 20),

                ResultBlock(
                  title: 'Post Melhorado',
                  content: gen.improvedText,
                  icon: Icons.auto_awesome,
                ),
                const SizedBox(height: 12),
                ResultBlock(
                  title: 'Versão Profissional',
                  content: gen.professionalVersion,
                  icon: Icons.work_outline,
                ),
                const SizedBox(height: 12),
                ResultBlock(
                  title: 'Versão Descontraída',
                  content: gen.casualVersion,
                  icon: Icons.emoji_emotions_outlined,
                ),
                const SizedBox(height: 12),
                ResultBlock(
                  title: 'Versão Persuasiva',
                  content: gen.persuasiveVersion,
                  icon: Icons.trending_up,
                ),
                const SizedBox(height: 12),
                ResultBlock(
                  title: 'Sugestão de Resposta a Comentários',
                  content: gen.commentReply,
                  icon: Icons.chat_bubble_outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(
        4,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: const Color(0xFF1A1A2E),
            highlightColor: const Color(0xFF2A2A4E),
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
