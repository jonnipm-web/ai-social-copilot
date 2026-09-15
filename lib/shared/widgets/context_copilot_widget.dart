import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/uuid_v4.dart';
import '../../data/models/copilot_context_data.dart';
import '../../data/models/copilot_turn.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../providers/context_copilot_provider.dart';
import 'ai_execution_confirmation.dart';

// ── Public helper ─────────────────────────────────────────────────────────────

// IVE-COMMERCIAL-FOUNDATION-11 — `request` is now required: this is the
// single choke point every "Ask/Analyze/Compare/Explain com a IVE" call
// site in the app goes through (see
// docs/commercial/IVE_INTERACTION_AND_QUOTA_CONTRACT.md §2), so identity
// is attached here unconditionally via [CopilotContextData.withIdentity]
// rather than relying on each of the ~8 call sites to remember to do it
// themselves.
void showCopilotChat(
  BuildContext context, {
  required String screenName,
  required IveInteractionRequest request,
  CopilotContextData? contextData,
  String? initialMessage,
}) {
  final resolvedContext = (contextData ?? const CopilotContextData()).withIdentity(request);
  showModalBottomSheet(
    context:             context,
    isScrollControlled:  true,
    backgroundColor:     Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child:  _CopilotSheet(
        screenName:     screenName,
        context:        resolvedContext,
        initialMessage: initialMessage,
      ),
    ),
  );
}

class ContextCopilotButton extends ConsumerWidget {
  final String screenName;
  final CopilotContextData context;

  const ContextCopilotButton({
    super.key,
    required this.screenName,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'copilot_$screenName',
      onPressed: () => _openCopilot(ctx, ref),
      backgroundColor: const Color(0xFF6C63FF),
      tooltip: 'Pergunte à IVE',
      child: const Text('💬', style: TextStyle(fontSize: 22)),
    );
  }

  void _openCopilot(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context:       ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(ctx),
        child: _CopilotSheet(
          screenName: screenName,
          context:    context,
        ),
      ),
    );
  }
}

// ── Internal bottom-sheet ─────────────────────────────────────────────────────

class _CopilotSheet extends ConsumerStatefulWidget {
  final String screenName;
  final CopilotContextData context;
  final String? initialMessage;

  const _CopilotSheet({
    required this.screenName,
    required this.context,
    this.initialMessage,
  });

  @override
  ConsumerState<_CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends ConsumerState<_CopilotSheet> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  // IVE-COMMERCIAL-QUOTA-HARDENING-13 — this sheet is the single choke
  // point EVERY "Ask/Analyze/Compare/Explain com a IVE" call site goes
  // through (showCopilotChat's own doc comment), including an
  // auto-sending `initialMessage` that used to fire with ZERO
  // confirmation the instant this sheet mounted, AND a free-form chat
  // where every manually-typed message ALSO reserves quota server-side
  // (context-copilot/index.ts calls reserveQuota before every message) —
  // confirmed in production during Foundation-11D's physical validation
  // and registered as a known architectural gap in Mission 12's own
  // final report. Gating HERE, once, closes every one of those call
  // sites (~9 at last count) in one file instead of duplicating a
  // confirm() call at each of them and risking missing one.
  //
  // Confirmed ONCE per sheet lifetime (not per message) — mission
  // Section 13: "each intentional analysis must require exactly one
  // execution confirmation," and re-asking on every single chat turn
  // would be a UX disaster for what is, after the first message, an
  // already-acknowledged ongoing conversation. This is deliberately
  // DIFFERENT from the idempotency key below: confirmation is per
  // SESSION, the key is per MESSAGE.
  final _exec = AiExecutionController();
  bool _confirmedThisSession = false;

  // Codex-anticipated finding (mission Section 21: "rapid double click:
  // one operation") — once a session is already confirmed, _send() no
  // longer goes through _exec's own busy guard (only the FIRST message's
  // confirm() call does). Inserting the `await _ensureConfirmed()` check
  // before `_ctrl.clear()` created a narrow window where two rapid taps
  // could both read the same unclear text and both call send() with two
  // different idempotency keys — a real double-charge for what the user
  // perceived as one tap. This synchronous flag, set before the first
  // await in _send(), closes that the same way AiExecutionController's
  // own isBusy guard closes it for the first message.
  bool _sending = false;

  // IVE-COMMERCIAL-FOUNDATION-11 (Codex Gate 2, P1) — inclui projectId na
  // chave da conversa, não só o screenName, para que trocar de projeto na
  // mesma tela nunca reutilize o histórico de outro projeto (ver
  // comentário completo em context_copilot_provider.dart).
  CopilotConversationKey get _conversationKey =>
      (widget.screenName, widget.context.projectId);

  /// Shows the standard confirm dialog the FIRST time this sheet is about
  /// to send a message (auto-sent or manually typed) and remembers that
  /// for the rest of this sheet's lifetime. Returns false if the user
  /// cancelled (or this is a duplicate concurrent call while the dialog
  /// is already showing) — callers must not send in that case.
  Future<bool> _ensureConfirmed() async {
    if (_confirmedThisSession) return true;
    if (_exec.isBusy) return false;
    final request = IveInteractionRequest(
      projectId:        widget.context.projectId,
      sourceModule:     widget.context.sourceModule ?? widget.screenName,
      sourceEntityType: widget.context.sourceEntityType,
      sourceEntityId:   widget.context.sourceEntityId,
      operationType:    IveOperationType.ask,
      correlationId:    widget.context.correlationId,
    );
    final confirmed = await _exec.confirm(
      context:       context,
      ref:           ref,
      analysisLabel: 'Perguntar à IVE',
      request:       request,
    );
    if (confirmed) _confirmedThisSession = true;
    return confirmed;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final confirmed = await _ensureConfirmed();
        if (!mounted) return;
        if (!confirmed) {
          // The caller opened this sheet SPECIFICALLY to run one
          // auto-sent analysis — if the user declines the quota
          // confirmation, there is nothing left for this sheet to show;
          // closing it (rather than leaving an empty chat open) matches
          // what the caller's button press was actually for.
          Navigator.of(context).pop();
          return;
        }
        ref.read(contextCopilotProvider(_conversationKey).notifier).send(
              message:        widget.initialMessage!,
              screenName:     widget.screenName,
              context:        widget.context,
              idempotencyKey: newUuidV4(),
            );
        Future.delayed(const Duration(milliseconds: 400), _scrollToBottom);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _exec.dispose();
    super.dispose();
  }

  void _send() async {
    if (_sending) return; // synchronous guard, set before any await below
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    _sending = true;
    try {
      final confirmed = await _ensureConfirmed();
      if (!mounted || !confirmed) return; // leave the typed text in the box
      _ctrl.clear();
      // Codex Gate 2 round-2 finding — this call used to be fire-and-
      // forget: `_sending` reset in `finally` right after DISPATCHING the
      // request, not after it actually completed, so it stopped guarding
      // anything for the whole (multi-second, LLM-latency) duration the
      // network call was actually in flight. Awaiting it means `_sending`
      // (and _exec.isBusy, transitively) now cover the full request, the
      // same "busy for the real duration of the operation" guarantee
      // every other AiExecutionController-gated flow in the app already
      // has.
      await ref.read(contextCopilotProvider(_conversationKey).notifier).send(
            message:        msg,
            screenName:     widget.screenName,
            context:        widget.context,
            idempotencyKey: newUuidV4(),
          );
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    } finally {
      _sending = false;
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve:    Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final state = ref.watch(contextCopilotProvider(_conversationKey));

    if (state.turns.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.35,
      maxChildSize:     0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(state),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: state.turns.isEmpty
                  ? _empty()
                  : _messages(state.turns),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Erro: ${state.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            _input(state.loading),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width:  40,
          height: 4,
          decoration: BoxDecoration(
            color:        Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(CopilotState state) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
        child: Row(
          children: [
            const Text('💬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'IVE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (state.turns.isNotEmpty)
              IconButton(
                icon:    const Icon(Icons.delete_sweep_rounded, size: 20),
                color:   Colors.white38,
                tooltip: 'Limpar histórico',
                onPressed: () => ref
                    .read(contextCopilotProvider(_conversationKey).notifier)
                    .clearHistory(),
              ),
            IconButton(
              icon:    const Icon(Icons.close_rounded),
              color:   Colors.white38,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Pergunte à IVE',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              widget.screenName,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ..._suggestions().map((s) => _suggestionChip(s)),
          ],
        ),
      );

  List<String> _suggestions() {
    switch (widget.screenName) {
      case 'Projetos':
        return ['Qual projeto devo focar?', 'Quais projetos têm mais risco?'];
      case 'Oportunidades':
        return ['Qual oportunidade tem maior ROI?', 'O que devo aprovar agora?'];
      case 'Scores':
        return ['Por que meu score está baixo?', 'Como melhorar o Ecosystem Score?'];
      case 'Decisões':
        return ['O que devo escalar?', 'Simule o impacto de aprovar a top oportunidade'];
      case 'Briefing':
        return ['Resuma minha semana', 'Quais ações críticas estão atrasadas?'];
      case 'Conhecimento':
        return ['O que aprendi esta semana?', 'Qual documento mais impacta meu projeto?'];
      case 'Personas':
        return ['Qual persona mais avançou?', 'Qual nicho tem mais potencial?'];
      default:
        return ['Me explique os dados desta tela', 'O que devo fazer agora?'];
    }
  }

  Widget _suggestionChip(String text) => GestureDetector(
        onTap: () {
          _ctrl.text = text;
          _send();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border:       Border.all(color: const Color(0xFF6C63FF), width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text, style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 13)),
        ),
      );

  Widget _messages(List<CopilotTurn> turns) => ListView.builder(
        controller: _scroll,
        padding:    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount:  turns.length,
        itemBuilder: (_, i) => _TurnBubble(turn: turns[i]),
      );

  Widget _input(bool loading) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left:   12,
            right:  12,
            top:    8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller:    _ctrl,
                  onSubmitted:   (_) => _send(),
                  enabled:       !loading,
                  maxLines:      null,
                  style:         const TextStyle(color: Colors.white, fontSize: 14),
                  decoration:    InputDecoration(
                    hintText:       'Pergunte à IVE…',
                    hintStyle:      const TextStyle(color: Colors.white38),
                    filled:         true,
                    fillColor:      const Color(0xFF2A2740),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border:         OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:   BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              loading
                  ? const SizedBox(
                      width:  40,
                      height: 40,
                      child:  Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color:       Color(0xFF6C63FF),
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed:       _send,
                      icon:            const Icon(Icons.send_rounded),
                      color:           const Color(0xFF6C63FF),
                      style:           IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2740),
                      ),
                    ),
            ],
          ),
        ),
      );
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _TurnBubble extends StatelessWidget {
  final CopilotTurn turn;
  const _TurnBubble({required this.turn});

  @override
  Widget build(BuildContext ctx) {
    final isUser = turn.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin:  const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(ctx).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF6C63FF)
              : const Color(0xFF2A2740),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              turn.content,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
            ),
            if (!isUser && (turn.sources.isNotEmpty || turn.confidence > 0))
              _meta(turn),
            if (!isUser && turn.actionSuggestion != null)
              _actionChip(turn.actionSuggestion!),
          ],
        ),
      ),
    );
  }

  Widget _meta(CopilotTurn turn) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _badge('${turn.confidence}% conf.', Colors.white24),
            ...turn.sources.take(3).map((s) => _badge(s, const Color(0xFF3D3A5C))),
          ],
        ),
      );

  Widget _badge(String text, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      );

  Widget _actionChip(CopilotActionSuggestion action) => Container(
        margin:  const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        const Color(0xFF6C63FF).withOpacity(0.25),
          border:       Border.all(color: const Color(0xFF6C63FF), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF6C63FF)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                action.label,
                style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
