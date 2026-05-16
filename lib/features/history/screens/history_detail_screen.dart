import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../providers/post_provider.dart';
import '../../../shared/widgets/result_block.dart';
import '../../../shared/widgets/score_chip.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final String id;

  const HistoryDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(generationDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhe')),
      body: detailAsync.when(
        loading: () => _buildShimmer(),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(e.toString(), textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (gen) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Texto original
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
                  const Text(
                    'Texto original',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w600,
                    ),
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
            const SizedBox(height: 24),
          ],
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
