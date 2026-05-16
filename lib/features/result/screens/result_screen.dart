import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/post_generation.dart';
import '../../../providers/post_provider.dart';
import '../../../shared/widgets/result_block.dart';
import '../../../shared/widgets/score_chip.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String originalText;
  final Map<String, dynamic> result;

  const ResultScreen({
    super.key,
    required this.originalText,
    required this.result,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;

  PostGeneration get _generation =>
      widget.result['_generation'] as PostGeneration;

  Map<String, dynamic> get _scores =>
      widget.result['scores'] as Map<String, dynamic>;

  Future<void> _save() async {
    await ref.read(postNotifierProvider.notifier).saveGeneration(_generation);
    if (!mounted) return;

    final state = ref.read(postNotifierProvider);
    if (state.hasError) {
      showErrorSnack(context, state.error.toString());
    } else {
      setState(() => _saved = true);
      showSuccessSnack(context, 'Salvo no histórico!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(postNotifierProvider).isLoading;
    final scores = _scores;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        actions: [
          if (!_saved)
            TextButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Salvar'),
            ),
          if (_saved)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.bookmark_added, color: Colors.green),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ScoreChip(
                label: 'Clareza',
                score: (scores['clarity'] as num).toDouble(),
              ),
              ScoreChip(
                label: 'Impacto',
                score: (scores['impact'] as num).toDouble(),
              ),
              ScoreChip(
                label: 'Engajamento',
                score: (scores['engagement'] as num).toDouble(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Blocos de texto
          ResultBlock(
            title: 'Post Melhorado',
            content: widget.result['improved_text'] as String,
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 12),
          ResultBlock(
            title: 'Versão Profissional',
            content: widget.result['professional_version'] as String,
            icon: Icons.work_outline,
          ),
          const SizedBox(height: 12),
          ResultBlock(
            title: 'Versão Descontraída',
            content: widget.result['casual_version'] as String,
            icon: Icons.emoji_emotions_outlined,
          ),
          const SizedBox(height: 12),
          ResultBlock(
            title: 'Versão Persuasiva',
            content: widget.result['persuasive_version'] as String,
            icon: Icons.trending_up,
          ),
          const SizedBox(height: 12),
          ResultBlock(
            title: 'Sugestão de Resposta a Comentários',
            content: widget.result['comment_reply'] as String,
            icon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
