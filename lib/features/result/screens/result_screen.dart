import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/post_generation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/post_provider.dart';
import '../../../shared/widgets/result_block.dart';
import '../../../shared/widgets/score_chip.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String originalText;
  final Map<String, dynamic> result;
  final double? processingSeconds;

  const ResultScreen({
    super.key,
    required this.originalText,
    required this.result,
    this.processingSeconds,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _saved = false;
  bool _isSaving = false;

  PostGeneration get _generation =>
      widget.result['_generation'] as PostGeneration;

  Map<String, dynamic> get _scores =>
      widget.result['scores'] as Map<String, dynamic>;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(postServiceProvider).saveGeneration(_generation);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _isSaving = false;
      });
      showSuccessSnack(context, AppLocalizations.of(context)!.uxResultSavedToHistory);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showErrorSnack(context, AppLocalizations.of(context)!.uxResultSaveError);
    }
  }

  void _copyAll() {
    final r = widget.result;
    final l10n = AppLocalizations.of(context)!;
    final text = [
      '✨ ${l10n.uxPostImproved}\n${r['improved_text']}',
      '💼 ${l10n.uxPostProfessional}\n${r['professional_version']}',
      '😊 ${l10n.uxPostCasual}\n${r['casual_version']}',
      '📈 ${l10n.uxPostPersuasive}\n${r['persuasive_version']}',
      '💬 ${l10n.uxPostCommentReply}\n${r['comment_reply']}',
    ].join('\n\n');
    Clipboard.setData(ClipboardData(text: text));
    showSuccessSnack(context, l10n.uxContentCopied);
  }

  @override
  Widget build(BuildContext context) {
    final scores = _scores;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.uxResultTitle),
        actions: [
          TextButton.icon(
            onPressed: _copyAll,
            icon: const Icon(Icons.copy_all_rounded, size: 16),
            label: Text(l10n.uxCopyAll),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          ),
          if (!_saved)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(l10n.commonSave),
            ),
          if (_saved)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.bookmark_added, color: Colors.green),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (widget.processingSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 13,
                        color: Colors.white38,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.uxResultGeneratedIn(widget.processingSeconds!.toStringAsFixed(1)),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ScoreChip(
                    label: l10n.uxScoreClarity,
                    score: (scores['clarity'] as num).toDouble(),
                  ),
                  ScoreChip(
                    label: l10n.actionEngineScoreImpact,
                    score: (scores['impact'] as num).toDouble(),
                  ),
                  ScoreChip(
                    label: l10n.uxScoreEngagement,
                    score: (scores['engagement'] as num).toDouble(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ResultBlock(
                title: l10n.uxPostImproved,
                content: widget.result['improved_text'] as String,
                icon: Icons.auto_awesome,
              ),
              const SizedBox(height: 12),
              ResultBlock(
                title: l10n.uxPostProfessional,
                content: widget.result['professional_version'] as String,
                icon: Icons.work_outline,
              ),
              const SizedBox(height: 12),
              ResultBlock(
                title: l10n.uxPostCasual,
                content: widget.result['casual_version'] as String,
                icon: Icons.emoji_emotions_outlined,
              ),
              const SizedBox(height: 12),
              ResultBlock(
                title: l10n.uxPostPersuasive,
                content: widget.result['persuasive_version'] as String,
                icon: Icons.trending_up,
              ),
              const SizedBox(height: 12),
              ResultBlock(
                title: l10n.uxPostCommentReply,
                content: widget.result['comment_reply'] as String,
                icon: Icons.chat_bubble_outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
