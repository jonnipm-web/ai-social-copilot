import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/snackbar_utils.dart'
    show showErrorSnack, showSuccessSnack, extractErrorMessage;
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/post_generation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/post_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/ai_execution_confirmation.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/widgets/loading_button.dart';

class ContentGenerationScreen extends ConsumerStatefulWidget {
  const ContentGenerationScreen({super.key});

  @override
  ConsumerState<ContentGenerationScreen> createState() =>
      _ContentGenerationScreenState();
}

// IVE-COMMERCIAL-QUOTA-HARDENING-13 (Codex Gate 2 finding) — this screen
// fired improve-post directly with no confirmation and no idempotency
// key. Reachable only by admins today (module improve-post has
// commercialEnabled:false — route_policy.dart denies it to regular
// users), but it still spends a real quota unit when used, so it gets
// the same treatment as every other silent path.
class _ContentGenerationScreenState
    extends ConsumerState<ContentGenerationScreen> {
  final _textCtrl = TextEditingController();
  final _exec = AiExecutionController();
  int _charCount = 0;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      setState(() => _charCount = _textCtrl.text.length);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _exec.dispose();
    super.dispose();
  }

  Future<void> _improve() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _textCtrl.text.trim();
    if (text.length < AppConstants.minTextLength) {
      showErrorSnack(
        context,
        l10n.improvePostMinLength(AppConstants.minTextLength),
      );
      return;
    }

    final usage   = ref.read(monthlyUsageProvider).valueOrNull ?? 0;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final limit   = profile?.monthlyLimit ?? AppConstants.freeTierLimit;
    if (usage >= limit) {
      showErrorSnack(
        context,
        l10n.improvePostLimitReached(limit),
      );
      return;
    }

    _startTime = DateTime.now();
    final result = await _exec.run<PostGeneration?>(
      context: context,
      ref: ref,
      analysisLabel: l10n.improvePostAnalysisLabel,
      request: IveInteractionRequest(
        sourceModule:     'content_generation',
        sourceEntityType: 'post_generation',
        operationType:    IveOperationType.analyze,
      ),
      action: (idempotencyKey) => ref
          .read(postNotifierProvider.notifier)
          .improvePost(text, idempotencyKey: idempotencyKey),
    );

    if (!mounted) return;

    final state = ref.read(postNotifierProvider);
    if (state.hasError) {
      showErrorSnack(context, extractErrorMessage(state.error, AppLocalizations.of(context)));
      return;
    }

    if (result != null) {
      ref.invalidate(monthlyUsageProvider);
      final elapsed = _startTime != null
          ? DateTime.now().difference(_startTime!).inMilliseconds / 1000
          : null;
      if (mounted) {
        showSuccessSnack(context, AppLocalizations.of(context)!.improvePostSuccess);
      }
      context.push(AppConstants.routeResult, extra: {
        'originalText':     text,
        'result':           _generationToMap(result),
        'processingSeconds': elapsed,
      });
    }
  }

  Map<String, dynamic> _generationToMap(PostGeneration g) => {
        'improved_text':        g.improvedText,
        'professional_version': g.professionalVersion,
        'casual_version':       g.casualVersion,
        'persuasive_version':   g.persuasiveVersion,
        'comment_reply':        g.commentReply,
        'scores': {
          'clarity':    g.clarityScore,
          'impact':     g.impactScore,
          'engagement': g.engagementScore,
        },
        '_generation': g,
      };

  Future<void> _clear() async {
    if (_textCtrl.text.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.improvePostClearTitle),
        content: Text(l10n.improvePostClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.improvePostClearConfirm,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) _textCtrl.clear();
  }

  Future<void> _signOut() async {
    await ref.read(authNotifierProvider.notifier).signOut();
    if (mounted) context.go(AppConstants.routeLogin);
  }

  Color _counterColor() {
    if (_charCount >= AppConstants.maxTextLength) return Colors.red;
    if (_charCount >= AppConstants.maxTextLength - 200) return Colors.orange;
    if (_charCount >= AppConstants.maxTextLength - 500) return Colors.amber;
    return Colors.white38;
  }

  Widget _buildCreditsBanner(AppLocalizations l10n, int used, int limit) {
    final remaining = limit - used;
    final isFull = remaining <= 0;
    final color = isFull
        ? Colors.red.shade700
        : remaining == 1
            ? Colors.orange.shade700
            : Colors.teal.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isFull ? Icons.lock_outline_rounded : Icons.bolt_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFull
                  ? l10n.improvePostLimitBanner(limit)
                  : l10n.improvePostRemainingBanner(remaining, limit),
              style: TextStyle(fontSize: 13, color: color),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => context.push(AppConstants.routeUpgrade),
            style: TextButton.styleFrom(
              foregroundColor: color,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text(isFull ? l10n.improvePostUpgradeCta : l10n.improvePostSeePlans),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _exec,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final postState  = ref.watch(postNotifierProvider);
    final isLoading  = postState.isLoading || _exec.isBusy;
    final usageAsync = ref.watch(monthlyUsageProvider);
    final profile    = ref.watch(currentProfileProvider).valueOrNull;
    final limit      = profile?.monthlyLimit ?? AppConstants.freeTierLimit;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.improvePostTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeHome),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: l10n.dashShortcutHistory,
            onPressed: () => context.push(AppConstants.routeHistory),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: l10n.authSignOut,
            onPressed: _signOut,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppConstants.maxBodyWidth),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                usageAsync.when(
                  data: (used) => Column(
                    children: [
                      _buildCreditsBanner(l10n, used, limit),
                      const SizedBox(height: 14),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error:   (_, __) => const SizedBox.shrink(),
                ),
                Text(
                  l10n.improvePostHeading,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextFormField(
                    controller: _textCtrl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    maxLength: AppConstants.maxTextLength,
                    buildCounter: (_, {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    decoration: InputDecoration(
                      hintText: l10n.improvePostHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      l10n.improvePostCharCount(_charCount, AppConstants.maxTextLength),
                      style:
                          TextStyle(fontSize: 12, color: _counterColor()),
                    ),
                    const Spacer(),
                    if (_charCount > 0)
                      TextButton.icon(
                        onPressed: isLoading ? null : _clear,
                        icon: const Icon(Icons.clear, size: 14),
                        label: Text(l10n.improvePostClearConfirm),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white38,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LoadingButton(
                  label: l10n.improvePostButtonLabel,
                  loadingLabel: l10n.improvePostButtonLoading,
                  isLoading: isLoading,
                  onPressed:
                      (usageAsync.valueOrNull ?? 0) >= limit ? null : _improve,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
