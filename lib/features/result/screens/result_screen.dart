import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/post_generation.dart';
import '../../../data/services/post_service.dart';
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

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool _saved = false;
  bool _isSaving = false;
  late final TabController _platformTabCtrl;

  // Plataformas disponíveis: índice 0 = versões gerais
  static const _platformLabels = ['Geral', 'LinkedIn', 'Instagram', 'Twitter/X'];

  PostGeneration get _generation =>
      widget.result['_generation'] as PostGeneration;

  Map<String, dynamic> get _scores =>
      widget.result['scores'] as Map<String, dynamic>;

  List<String> get _hashtags =>
      (widget.result['suggested_hashtags'] as List<dynamic>? ?? [])
          .cast<String>();

  Map<String, dynamic>? get _platforms =>
      widget.result['platforms'] as Map<String, dynamic>?;

  @override
  void initState() {
    super.initState();
    _platformTabCtrl = TabController(length: _platformLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _platformTabCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(postServiceProvider).saveGeneration(_generation);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _isSaving = false;
      });
      showSuccessSnack(context, 'Salvo no histórico!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnack(context, 'Erro ao salvar. Tente novamente.');
    }
  }

  void _copyHashtags() {
    Clipboard.setData(ClipboardData(text: _hashtags.join(' ')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hashtags copiadas!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scores = _scores;
    final hashtags = _hashtags;
    final platforms = _platforms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        bottom: TabBar(
          controller: _platformTabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _platformLabels
              .map((l) => Tab(text: l))
              .toList(),
        ),
        actions: [
          if (!_saved)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
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
      body: TabBarView(
        controller: _platformTabCtrl,
        children: [
          // ── Tab 0: Geral ──────────────────────────────────────
          _GeneralTab(scores: scores, hashtags: hashtags,
              onCopyHashtags: _copyHashtags, result: widget.result),

          // ── Tab 1: LinkedIn ───────────────────────────────────
          _PlatformTab(
            platform: 'LinkedIn',
            icon: Icons.business_center_rounded,
            content: platforms?['linkedin'] as String?,
            characterLimit: 3000,
            tip: 'Parágrafos curtos, sem emojis excessivos. Hora de pico: ter/qua às 9h.',
          ),

          // ── Tab 2: Instagram ──────────────────────────────────
          _PlatformTab(
            platform: 'Instagram',
            icon: Icons.camera_enhance_rounded,
            content: platforms?['instagram'] as String?,
            characterLimit: 2200,
            tip: 'Emojis estratégicos, quebras de linha. Hora de pico: seg/qui às 11h.',
          ),

          // ── Tab 3: Twitter/X ──────────────────────────────────
          _PlatformTab(
            platform: 'Twitter/X',
            icon: Icons.bolt_rounded,
            content: platforms?['twitter_x'] as String?,
            characterLimit: 280,
            tip: 'Direto ao ponto. Máximo 280 caracteres. Hora de pico: seg–sex às 9h.',
          ),
        ],
      ),
    );
  }
}

// ── Tab Geral ────────────────────────────────────────────────────────────────

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.scores,
    required this.hashtags,
    required this.onCopyHashtags,
    required this.result,
  });

  final Map<String, dynamic> scores;
  final List<String> hashtags;
  final VoidCallback onCopyHashtags;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Scores
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ScoreChip(
                label: 'Clareza',
                score: (scores['clarity'] as num).toDouble()),
            ScoreChip(
                label: 'Impacto',
                score: (scores['impact'] as num).toDouble()),
            ScoreChip(
                label: 'Engajamento',
                score: (scores['engagement'] as num).toDouble()),
          ],
        ),
        const SizedBox(height: 20),

        // Hashtags
        if (hashtags.isNotEmpty) ...[
          _HashtagSection(hashtags: hashtags, onCopyAll: onCopyHashtags),
          const SizedBox(height: 16),
        ],

        ResultBlock(
          title: 'Post Melhorado',
          content: result['improved_text'] as String,
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 12),
        ResultBlock(
          title: 'Versão Profissional',
          content: result['professional_version'] as String,
          icon: Icons.work_outline,
        ),
        const SizedBox(height: 12),
        ResultBlock(
          title: 'Versão Descontraída',
          content: result['casual_version'] as String,
          icon: Icons.emoji_emotions_outlined,
        ),
        const SizedBox(height: 12),
        ResultBlock(
          title: 'Versão Persuasiva',
          content: result['persuasive_version'] as String,
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 12),
        ResultBlock(
          title: 'Sugestão de Resposta a Comentários',
          content: result['comment_reply'] as String,
          icon: Icons.chat_bubble_outline,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Tab de plataforma ────────────────────────────────────────────────────────

class _PlatformTab extends StatelessWidget {
  const _PlatformTab({
    required this.platform,
    required this.icon,
    required this.content,
    required this.characterLimit,
    required this.tip,
  });

  final String platform;
  final IconData icon;
  final String? content;
  final int characterLimit;
  final String tip;

  @override
  Widget build(BuildContext context) {
    if (content == null || content!.isEmpty) {
      return const Center(
        child: Text('Versão não disponível para este post.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    final charCount = content!.length;
    final overLimit = charCount > characterLimit;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dica da plataforma
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 14, color: Colors.amber.withOpacity(0.7)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tip,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54, height: 1.4)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contador de caracteres
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$charCount / $characterLimit chars',
              style: TextStyle(
                fontSize: 12,
                color: overLimit ? Colors.red : Colors.white38,
                fontWeight: overLimit ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ResultBlock(
          title: 'Versão $platform',
          content: content!,
          icon: icon,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ── Hashtags ─────────────────────────────────────────────────────────────────

class _HashtagSection extends StatelessWidget {
  const _HashtagSection({required this.hashtags, required this.onCopyAll});

  final List<String> hashtags;
  final VoidCallback onCopyAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.tag_rounded, size: 15, color: Colors.white38),
                SizedBox(width: 6),
                Text('Hashtags sugeridas',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            GestureDetector(
              onTap: onCopyAll,
              child: const Row(
                children: [
                  Icon(Icons.copy_rounded, size: 13, color: Colors.white38),
                  SizedBox(width: 4),
                  Text('Copiar todas',
                      style: TextStyle(fontSize: 12, color: Colors.white38)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: hashtags.map((tag) => _HashtagChip(tag: tag)).toList(),
        ),
      ],
    );
  }
}

class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: tag));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$tag copiado!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF7C3AED).withOpacity(0.3)),
        ),
        child: Text(
          tag,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFBB86FC),
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
