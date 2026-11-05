import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/copilot_context_data.dart';
import '../../../data/models/copilot_turn.dart';
import '../../../data/models/ive_interaction_request.dart';
import '../../../data/models/opportunity_lab_item.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/context_copilot_provider.dart';
import '../../../providers/insight_provider.dart';
import '../../../providers/ive_context_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../widgets/insight_card.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

class IveAnalysisScreen extends ConsumerStatefulWidget {
  const IveAnalysisScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<IveAnalysisScreen> createState() => _IveAnalysisScreenState();
}

class _IveAnalysisScreenState extends ConsumerState<IveAnalysisScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  OpportunityLabItem? _pendingInsight;
  bool _justSaved = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  CopilotConversationKey get _convKey => ('ive_analysis', widget.projectId);

  bool _isQuotaBlocked(InsightState insightState, bool isPro) {
    if (isPro) return false;
    return insightState.monthCount >= AppConstants.insightFreeMonthlyLimit;
  }

  Future<void> _send(bool blocked) async {
    if (blocked) return;
    final question = _ctrl.text.trim();
    if (question.isEmpty) return;
    _focus.unfocus();

    final ctxValue =
        ref.read(iveContextDataProvider(widget.projectId)).valueOrNull;
    CopilotContextData context = ctxValue != null
        ? CopilotContextData.fromIveContext(ctxValue)
        : const CopilotContextData();
    context = context.withIdentity(IveInteractionRequest(
      projectId: widget.projectId,
      sourceModule: 'ive_analysis',
      sourceEntityType: 'project',
      sourceEntityId: widget.projectId,
      operationType: IveOperationType.analyze,
    ));

    setState(() {
      _pendingInsight = null;
      _justSaved = false;
    });
    _ctrl.clear();

    await ref
        .read(contextCopilotProvider(_convKey).notifier)
        .send(message: question, screenName: 'ive_analysis', context: context);

    final copilotState = ref.read(contextCopilotProvider(_convKey));
    final lastTurn = copilotState.turns.lastWhere(
      (t) => t.role == 'assistant',
      orElse: () => CopilotTurn(
          role: 'assistant', content: '', timestamp: DateTime.now()),
    );

    if (mounted && lastTurn.content.isNotEmpty) {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      setState(() {
        _pendingInsight = OpportunityLabItem(
          id: '',
          userId: uid,
          projectId: widget.projectId,
          title: _titleFrom(question),
          description: lastTurn.content,
          confidence: lastTurn.confidence,
          sources: lastTurn.sources,
          actionSteps: lastTurn.actionSuggestion != null
              ? [lastTurn.actionSuggestion!.label]
              : [],
          origin: AppConstants.originIveAnalysis,
          createdAt: lastTurn.timestamp,
        );
      });
    }
  }

  Future<void> _saveInsight() async {
    final pending = _pendingInsight;
    if (pending == null) return;

    final copilotState = ref.read(contextCopilotProvider(_convKey));
    final lastTurn = copilotState.turns.lastWhere(
      (t) => t.role == 'assistant',
      orElse: () => CopilotTurn(
          role: 'assistant', content: '', timestamp: DateTime.now()),
    );
    if (lastTurn.content.isEmpty) return;

    final question = copilotState.turns
        .lastWhere(
          (t) => t.role == 'user',
          orElse: () =>
              CopilotTurn(role: 'user', content: '', timestamp: DateTime.now()),
        )
        .content;

    final saved = await ref
        .read(insightNotifierProvider(widget.projectId).notifier)
        .save(question: question, turn: lastTurn);

    if (!mounted) return;
    final t = AppLocalizations.of(context)!;

    if (saved != null) {
      setState(() {
        _pendingInsight = null;
        _justSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.insightSaved),
        backgroundColor: AppColors.positive,
        duration: const Duration(seconds: 2),
      ));
    } else {
      final error = ref.read(insightNotifierProvider(widget.projectId)).error;
      final isQuota = error == 'quota_exceeded';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(isQuota ? t.insightQuotaExceeded : t.insightAddToActionsError),
        backgroundColor: AppColors.negative,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _addToActions(OpportunityLabItem item) async {
    final t = AppLocalizations.of(context)!;
    final action = await ref
        .read(insightNotifierProvider(widget.projectId).notifier)
        .addToActions(item);
    if (!mounted) return;
    if (action != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.insightAddedToActions),
        backgroundColor: AppColors.accent,
        duration: const Duration(seconds: 2),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.insightAddToActionsError),
        backgroundColor: AppColors.negative,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(insightsByProjectProvider(widget.projectId));
    await ref.read(insightNotifierProvider(widget.projectId).notifier).load();
  }

  String _titleFrom(String q) {
    final trimmed = q.trim();
    return trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 57)}…';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final copilotState = ref.watch(contextCopilotProvider(_convKey));
    final insightState = ref.watch(insightNotifierProvider(widget.projectId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isPro = profile?.isPro ?? false;
    final blocked = _isQuotaBlocked(insightState, isPro);

    final projectName = ref
            .watch(projectsNotifierProvider)
            .valueOrNull
            ?.where((p) => p.id == widget.projectId)
            .map((p) => p.name)
            .firstOrNull ??
        widget.projectId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppConstants.routeHome),
        ),
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.insightTitle,
                style: const TextStyle(color: AppColors.ink, fontSize: 16)),
            Text(projectName,
                style: const TextStyle(color: AppColors.inkMuted, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            icon: insightState.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
                : const Icon(Icons.refresh_rounded, color: AppColors.accent),
            onPressed: insightState.loading ? null : _refresh,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            if (!isPro)
              _QuotaBadge(
                used: insightState.monthCount,
                max: AppConstants.insightFreeMonthlyLimit,
                blocked: blocked,
                t: t,
              ),
            if (!isPro) const SizedBox(height: 12),
            _InputCard(
              ctrl: _ctrl,
              focus: _focus,
              loading: copilotState.loading,
              blocked: blocked,
              onSend: () => _send(blocked),
              t: t,
            ),
            if (copilotState.loading) ...[
              const SizedBox(height: 16),
              _ThinkingCard(t: t),
            ],
            if (!copilotState.loading && _pendingInsight != null) ...[
              const SizedBox(height: 16),
              InsightCard(
                item: _pendingInsight!,
                elevated: true,
                onAddToActions: () => _addToActions(_pendingInsight!),
              ),
              const SizedBox(height: 8),
              _SaveButton(saved: _justSaved, onSave: _saveInsight, t: t),
            ],
            if (copilotState.error != null &&
                !copilotState.loading &&
                _pendingInsight == null) ...[
              const SizedBox(height: 12),
              _ErrorCard(onRetry: () => _send(blocked), t: t),
            ],
            if (insightState.items.isNotEmpty) ...[
              const SizedBox(height: 24),
              _HistoryHeader(count: insightState.items.length, t: t),
              const SizedBox(height: 8),
              ...insightState.items.map((item) => InsightCard(
                    key: ValueKey(item.id),
                    item: item,
                    onAddToActions: () => _addToActions(item),
                    onDelete: () async {
                      final ok = await _confirmDelete(context, t);
                      if (ok && mounted) {
                        ref
                            .read(insightNotifierProvider(widget.projectId)
                                .notifier)
                            .delete(item.id);
                      }
                    },
                  )),
            ],
            if (insightState.loading && insightState.items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              ),
            if (!insightState.loading &&
                insightState.items.isEmpty &&
                _pendingInsight == null &&
                !copilotState.loading)
              _EmptyState(t: t),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext ctx, AppLocalizations t) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirmar', style: TextStyle(color: AppColors.ink)),
        content: Text(t.insightDeleteConfirm,
            style: const TextStyle(color: AppColors.inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.insightCancel,
                style: const TextStyle(color: AppColors.inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    return result == true;
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({
    required this.used,
    required this.max,
    required this.blocked,
    required this.t,
  });
  final int used;
  final int max;
  final bool blocked;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final color = blocked ? AppColors.negative : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(
          blocked ? Icons.lock_rounded : Icons.info_outline_rounded,
          color: color,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            blocked ? t.insightQuotaExceeded : t.insightUsageOf(used, max),
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
        if (blocked)
          GestureDetector(
            onTap: () => context.push(AppConstants.routeUpgrade),
            child: Text(t.insightUpgradeCta,
                style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.blocked,
    required this.onSend,
    required this.t,
  });
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading;
  final bool blocked;
  final VoidCallback onSend;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final disabled = loading || blocked;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: blocked
              ? AppColors.negative.withValues(alpha: 0.3)
              : AppColors.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              Icons.psychology_alt_rounded,
              color: blocked ? AppColors.inkSubtle : AppColors.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.insightSubtitle,
                style: TextStyle(
                  color: blocked ? AppColors.inkSubtle : AppColors.inkMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            focusNode: focus,
            enabled: !disabled,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: blocked ? t.insightQuotaExceeded : t.insightAskHint,
              hintStyle: const TextStyle(color: AppColors.inkSubtle, fontSize: 13),
              filled: true,
              fillColor: AppColors.ground,
              contentPadding: const EdgeInsets.all(12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.surfaceRaised),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    blocked ? AppColors.accent : AppColors.accent,
                foregroundColor: AppColors.ink,
                disabledBackgroundColor: AppColors.line,
                disabledForegroundColor: AppColors.inkSubtle,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.ink))
                  : Icon(
                      blocked ? Icons.lock_rounded : Icons.send_rounded,
                      size: 16,
                    ),
              label:
                  Text(blocked ? t.insightUpgradeCta : t.insightAnalyzeProject),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  const _ThinkingCard({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Text(t.insightThinking,
            style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
      ]),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saved,
    required this.onSave,
    required this.t,
  });
  final bool saved;
  final VoidCallback onSave;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: saved ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.positive,
          foregroundColor: Colors.black,
          disabledBackgroundColor:
              AppColors.positive.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.black38,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(saved ? Icons.check_rounded : Icons.save_alt_rounded,
            size: 16),
        label: Text(t.insightSaved),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry, required this.t});
  final VoidCallback onRetry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.negativeSoft,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.negative.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.negative, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(t.insightError,
              style: const TextStyle(color: AppColors.negative, fontSize: 13)),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(t.insightRetry,
              style: const TextStyle(color: AppColors.accent)),
        ),
      ]),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.count, required this.t});
  final int count;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(t.insightRecent,
          style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t.insightNOf(count),
            style: const TextStyle(color: AppColors.accent, fontSize: 11)),
      ),
    ]);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        const Icon(Icons.lightbulb_outline_rounded,
            color: AppColors.inkSubtle, size: 48),
        const SizedBox(height: 12),
        Text(t.insightEmpty,
            style: const TextStyle(color: AppColors.inkSubtle, fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(t.insightEmptyPrompt,
            style: const TextStyle(color: AppColors.inkSubtle, fontSize: 12),
            textAlign: TextAlign.center),
      ]),
    );
  }
}
