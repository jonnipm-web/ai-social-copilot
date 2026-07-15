import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/copilot_context_data.dart';
import '../../data/models/copilot_turn.dart';
import '../../providers/context_copilot_provider.dart';

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
      tooltip: 'Pergunte ao Copilot',
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

  const _CopilotSheet({required this.screenName, required this.context});

  @override
  ConsumerState<_CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends ConsumerState<_CopilotSheet> {
  final _ctrl     = TextEditingController();
  final _scroll   = ScrollController();
  bool  _expanded = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final msg = _ctrl.text.trim();
    if (msg.isEmpty) return;
    _ctrl.clear();
    ref.read(contextCopilotProvider(widget.screenName).notifier).send(
          message:    msg,
          screenName: widget.screenName,
          context:    widget.context,
        );
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
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
    final state = ref.watch(contextCopilotProvider(widget.screenName));

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
                'AI Copilot',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (state.turns.isNotEmpty)
              IconButton(
                icon:    const Icon(Icons.delete_sweep_rounded, size: 20),
                color:   Colors.white38,
                tooltip: 'Limpar histórico',
                onPressed: () => ref
                    .read(contextCopilotProvider(widget.screenName).notifier)
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
              'Pergunte ao Copilot',
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
                    hintText:       'Pergunte ao Copilot…',
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
