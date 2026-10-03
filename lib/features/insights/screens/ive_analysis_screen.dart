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
import '../../../providers/project_provider.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../widgets/insight_card.dart';

class IveAnalysisScreen extends ConsumerStatefulWidget {
  const IveAnalysisScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<IveAnalysisScreen> createState() => _IveAnalysisScreenState();
}

class _IveAnalysisScreenState extends ConsumerState<IveAnalysisScreen> {
  final _ctrl    = TextEditingController();
  final _focus   = FocusNode();

  // Holds the last AI response before the user saves it
  OpportunityLabItem? _pendingInsight;
  bool _justSaved = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  CopilotConversationKey get _convKey => ('ive_analysis', widget.projectId);

  Future<void> _send() async {
    final question = _ctrl.text.trim();
    if (question.isEmpty) return;
    _focus.unfocus();

    final ctxAsync = ref.read(iveContextDataProvider(widget.projectId));
    CopilotContextData context;
    if (ctxAsync.valueOrNull != null) {
      context = CopilotContextData.fromIveContext(ctxAsync.value!);
    } else {
      context = const CopilotContextData();
    }
    context = context.withIdentity(IveInteractionRequest(
      projectId:        widget.projectId,
      sourceModule:     'ive_analysis',
      sourceEntityType: 'project',
      sourceEntityId:   widget.projectId,
      operationType:    IveOperationType.analyze,
    ));

    setState(() {
      _pendingInsight = null;
      _justSaved      = false;
    });
    _ctrl.clear();

    await ref
        .read(contextCopilotProvider(_convKey).notifier)
        .send(message: question, screenName: 'ive_analysis', context: context);

    final copilotState = ref.read(contextCopilotProvider(_convKey));
    final lastTurn = copilotState.turns
        .lastWhere((t) => t.role == 'assistant', orElse: () => CopilotTurn(
              role: 'assistant', content: '', timestamp: DateTime.now()));

    if (mounted && lastTurn.content.isNotEmpty) {
      final uid = _currentUserId();
      setState(() {
        _pendingInsight = OpportunityLabItem(
          id:          '',
          userId:      uid,
          projectId:   widget.projectId,
          title:       _titleFromQuestion(question),
          description: lastTurn.content,
          confidence:  lastTurn.confidence,
          sources:     lastTurn.sources,
          actionSteps: lastTurn.actionSuggestion != null
              ? [lastTurn.actionSuggestion!.label]
              : [],
          origin:      AppConstants.originIveAnalysis,
          createdAt:   lastTurn.timestamp,
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
      orElse: () =>
          CopilotTurn(role: 'assistant', content: '', timestamp: DateTime.now()),
    );
    if (lastTurn.content.isEmpty) return;

    final prevQuestion = _extractQuestion(copilotState.turns);
    await ref.read(insightNotifierProvider(widget.projectId).notifier).save(
          projectId: widget.projectId,
          question:  prevQuestion,
          turn:      lastTurn,
        );

    if (mounted) {
      setState(() {
        _pendingInsight = null;
        _justSaved      = true;
      });
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:         Text(t.insightSaved),
        backgroundColor: const Color(0xFF6BCB77),
        duration:        const Duration(seconds: 2),
      ));
    }
  }

  String _currentUserId() =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  String _titleFromQuestion(String q) {
    final trimmed = q.trim();
    return trimmed.length <= 60 ? trimmed : '${trimmed.substring(0, 57)}…';
  }

  String _extractQuestion(List<CopilotTurn> turns) {
    final last = turns.lastWhere((t) => t.role == 'user',
        orElse: () =>
            CopilotTurn(role: 'user', content: '', timestamp: DateTime.now()));
    return last.content;
  }

  @override
  Widget build(BuildContext context) {
    final t            = AppLocalizations.of(context)!;
    final copilotState = ref.watch(contextCopilotProvider(_convKey));
    final insightState = ref.watch(insightNotifierProvider(widget.projectId));

    final projectName = ref.watch(projectsNotifierProvider).valueOrNull
            ?.where((p) => p.id == widget.projectId)
            .map((p) => p.name)
            .firstOrNull ??
        widget.projectId;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppConstants.routeHome),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.insightTitle,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(projectName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InputCard(
            ctrl:      _ctrl,
            focus:     _focus,
            loading:   copilotState.loading,
            onSend:    _send,
            t:         t,
          ),
          if (copilotState.loading) ...[
            const SizedBox(height: 16),
            _ThinkingCard(t: t),
          ],
          if (!copilotState.loading && _pendingInsight != null) ...[
            const SizedBox(height: 16),
            InsightCard(item: _pendingInsight!, elevated: true),
            const SizedBox(height: 8),
            _SaveButton(
              saved:   _justSaved,
              onSave:  _saveInsight,
              t:       t,
            ),
          ],
          if (copilotState.error != null &&
              !copilotState.loading &&
              _pendingInsight == null) ...[
            const SizedBox(height: 12),
            _ErrorCard(onRetry: _send, t: t),
          ],
          if (insightState.items.isNotEmpty) ...[
            const SizedBox(height: 24),
            _HistoryHeader(count: insightState.items.length, t: t),
            const SizedBox(height: 8),
            ...insightState.items.map((item) => InsightCard(
                  key:      ValueKey(item.id),
                  item:     item,
                  onDelete: () async {
                    final ok = await _confirmDelete(context, t);
                    if (ok && mounted) {
                      ref
                          .read(insightNotifierProvider(widget.projectId).notifier)
                          .delete(item.id);
                    }
                  },
                )),
          ],
          if (insightState.loading && insightState.items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              ),
            ),
          if (!insightState.loading && insightState.items.isEmpty && _pendingInsight == null && !copilotState.loading)
            _EmptyState(t: t),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, AppLocalizations t) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title:   const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text(t.insightDeleteConfirm,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
    return result == true;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.onSend,
    required this.t,
  });
  final TextEditingController ctrl;
  final FocusNode             focus;
  final bool                  loading;
  final VoidCallback          onSend;
  final AppLocalizations      t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.psychology_alt_rounded,
                color: Color(0xFF6C63FF), size: 18),
            const SizedBox(width: 8),
            Text(t.insightSubtitle,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller:      ctrl,
            focusNode:       focus,
            style:           const TextStyle(color: Colors.white, fontSize: 14),
            maxLines:        3,
            minLines:        2,
            textInputAction: TextInputAction.done,
            onSubmitted:     (_) => onSend(),
            decoration: InputDecoration(
              hintText:  t.insightAskHint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled:    true,
              fillColor: const Color(0xFF0F0F1A),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: Color(0xFF333355)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: loading
                  ? const SizedBox(
                      width:  16,
                      height: 16,
                      child:  CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(t.insightAnalyzeProject),
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
        color:        const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const SizedBox(
          width:  18,
          height: 18,
          child:  CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF6C63FF)),
        ),
        const SizedBox(width: 12),
        Text(t.insightThinking,
            style:
                const TextStyle(color: Colors.white54, fontSize: 13)),
      ]),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton(
      {required this.saved, required this.onSave, required this.t});
  final bool             saved;
  final VoidCallback     onSave;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: saved ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6BCB77),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon:  const Icon(Icons.save_alt_rounded, size: 16),
        label: Text(t.insightSaved),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry, required this.t});
  final VoidCallback     onRetry;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFF2A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFFF6B6B), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(t.insightError,
              style:
                  const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry',
              style: TextStyle(color: Color(0xFF6C63FF))),
        ),
      ]),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.count, required this.t});
  final int              count;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(t.insightRecent,
          style: const TextStyle(
              color:         Colors.white54,
              fontSize:      12,
              fontWeight:    FontWeight.bold,
              letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        const Color(0xFF6C63FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t.insightNOf(count),
            style: const TextStyle(color: Color(0xFFAB83FF), fontSize: 11)),
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
      child: Column(
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(t.insightEmpty,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(t.insightEmptyPrompt,
              style: const TextStyle(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
