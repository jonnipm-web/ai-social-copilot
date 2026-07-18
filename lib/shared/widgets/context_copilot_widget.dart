import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/copilot_context_data.dart';
import '../../data/models/copilot_turn.dart';
import '../../data/models/action_queue_item.dart';
import '../../providers/context_copilot_provider.dart';
import '../../providers/ive_context_provider.dart';
import '../../providers/selected_project_provider.dart';
import 'ive_action_confirmation_card.dart';
import 'ive_response_context_panel.dart';

final iveRootNavigatorKey = GlobalKey<NavigatorState>();

bool _iveChatOpen = false;

@visibleForTesting
void resetIveChatGateForTesting() => _iveChatOpen = false;

void _debugIve(String marker) {
  assert(() {
    debugPrint(marker);
    return true;
  }());
}

Future<void> openIveChat(
  BuildContext requestContext, {
  required String screenName,
  String? route,
  CopilotContextData? contextData,
  String? initialMessage,
  String? inputHint,
  String? selectedEntityType,
  String? selectedEntityId,
  String? selectedEntityLabel,
}) async {
  _debugIve('IVE_OPEN_REQUESTED');
  if (_iveChatOpen) return;

  try {
    final container = ProviderScope.containerOf(requestContext);
    final navigator = iveRootNavigatorKey.currentState ??
        Navigator.maybeOf(requestContext, rootNavigator: true);
    if (navigator == null || !navigator.mounted) {
      throw StateError('IVE root Navigator unavailable');
    }

    _iveChatOpen = true;
    final sheet = showModalBottomSheet<void>(
      context: navigator.context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: _CopilotSheet(
          screenName: screenName,
          route: route,
          contextData: contextData,
          initialMessage: initialMessage,
          inputHint: inputHint,
          selectedEntityType: selectedEntityType,
          selectedEntityId: selectedEntityId,
          selectedEntityLabel: selectedEntityLabel,
        ),
      ),
    );
    _debugIve('IVE_CHAT_OPENED');
    await sheet;
  } catch (error) {
    _debugIve('IVE_CHAT_OPEN_FAILED: $error');
  } finally {
    _iveChatOpen = false;
  }
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
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      heroTag: 'copilot_$screenName',
      onPressed: () => openIveChat(
        context,
        screenName: screenName,
        route: this.context.route,
        contextData: this.context,
      ),
      backgroundColor: const Color(0xFF6C63FF),
      tooltip: 'Pergunte à IVE',
      child: const Text('💬', style: TextStyle(fontSize: 22)),
    );
  }
}

class _CopilotSheet extends ConsumerStatefulWidget {
  final String screenName;
  final String? route;
  final CopilotContextData? contextData;
  final String? initialMessage;
  final String? inputHint;
  final String? selectedEntityType;
  final String? selectedEntityId;
  final String? selectedEntityLabel;

  const _CopilotSheet({
    required this.screenName,
    this.route,
    this.contextData,
    this.initialMessage,
    this.inputHint,
    this.selectedEntityType,
    this.selectedEntityId,
    this.selectedEntityLabel,
  });

  @override
  ConsumerState<_CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends ConsumerState<_CopilotSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _initialMessageSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitialMessage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  CopilotScope _scope(String uid, String? projectId) => CopilotScope(
        userId: uid,
        projectId: projectId ?? '',
        screenName: widget.screenName,
      );

  CopilotContextData? _currentContext() {
    final live = ref.read(iveContextDataProvider).valueOrNull;
    if (live == null || !live.hasActiveProject) return null;
    final trusted = live.toCopilotContext(
      route: widget.route ?? widget.screenName,
    );
    final provided = widget.contextData;
    if (provided == null ||
        provided.isEmpty ||
        provided.userId != trusted.userId ||
        provided.projectId != trusted.projectId) {
      return trusted;
    }
    return CopilotContextData(
      userId: trusted.userId,
      projectId: trusted.projectId,
      route: widget.route ?? widget.screenName,
      project: trusted.project,
      scores: provided.scores ?? trusted.scores,
      opportunities: provided.opportunities.isEmpty
          ? trusted.opportunities
          : provided.opportunities,
      actions: provided.actions.isEmpty ? trusted.actions : provided.actions,
      documents:
          provided.documents.isEmpty ? trusted.documents : provided.documents,
      personas:
          provided.personas.isEmpty ? trusted.personas : provided.personas,
      revenue: provided.revenue ?? trusted.revenue,
      market: provided.market ?? trusted.market,
      sourceLimitations: {
        ...trusted.sourceLimitations,
        ...provided.sourceLimitations,
      }.toList(),
    );
  }

  Future<void> _sendInitialMessage() async {
    if (!mounted || _initialMessageSent || widget.initialMessage == null) {
      return;
    }
    final context = _currentContext();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final projectId = ref.read(selectedProjectProvider)?.id;
    if (context == null || uid == null || projectId == null) return;
    _initialMessageSent = true;
    await ref
        .read(contextCopilotProvider(_scope(uid, projectId)).notifier)
        .send(
          message: widget.initialMessage!,
          context: context,
          selectedEntityType: widget.selectedEntityType,
          selectedEntityId: widget.selectedEntityId,
        );
    _scrollToBottom();
  }

  void _send() {
    final message = _controller.text.trim();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final projectId = ref.read(selectedProjectProvider)?.id;
    final context = _currentContext();
    if (message.isEmpty ||
        uid == null ||
        projectId == null ||
        context == null) {
      return;
    }
    _controller.clear();
    ref.read(contextCopilotProvider(_scope(uid, projectId)).notifier).send(
          message: message,
          context: context,
          selectedEntityType: widget.selectedEntityType,
          selectedEntityId: widget.selectedEntityId,
        );
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    final project = ref.watch(selectedProjectProvider);
    final liveContext = ref.watch(iveContextDataProvider);
    final canChat = project != null &&
        liveContext.valueOrNull?.activeProjectId == project.id;
    final scope = _scope(uid, project?.id);
    final state = ref.watch(contextCopilotProvider(scope));

    ref.listen(selectedProjectProvider, (previous, next) {
      if (previous?.id != null && previous?.id != next?.id && uid.isNotEmpty) {
        ref
            .read(contextCopilotProvider(_scope(uid, previous!.id)).notifier)
            .invalidateProposalForProjectChange();
      }
    });

    if (state.turns.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return DraggableScrollableSheet(
      key: const ValueKey('ive-chat-sheet'),
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(state, scope),
            _projectBadge(project?.name),
            if (widget.selectedEntityLabel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Contexto: ${widget.selectedEntityLabel}',
                    key: const ValueKey('ive-chat-entity-context'),
                    style: const TextStyle(
                      color: Color(0xFF9B8FFF),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            if (liveContext.isLoading)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF6C63FF),
                backgroundColor: Colors.transparent,
              ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: state.turns.isEmpty
                  ? _empty(project != null)
                  : _messages(state.turns),
            ),
            if (state.evidence.isNotEmpty || state.limitations.isNotEmpty)
              IveResponseContextPanel(
                evidence: state.evidence,
                limitations: state.limitations,
              ),
            if (state.pendingProposal != null)
              IveActionConfirmationCard(
                proposal: state.pendingProposal!,
                executing: state.executing,
                onConfirm: () => ref
                    .read(contextCopilotProvider(scope).notifier)
                    .confirmProposal(),
                onCancel: () => ref
                    .read(contextCopilotProvider(scope).notifier)
                    .cancelProposal(),
                onEdit: ({
                  required title,
                  required description,
                  required priority,
                  required impact,
                  required effort,
                }) =>
                    ref
                        .read(contextCopilotProvider(scope).notifier)
                        .reviseProposal(
                          title: title,
                          description: description,
                          priority: priority,
                          impact: impact,
                          effort: effort,
                        ),
              ),
            if (state.lastExecution != null)
              _executionResult(context, state.lastExecution!.action),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                            color: Colors.orangeAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            _input(state.loading || state.executing, canChat),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(CopilotState state, CopilotScope scope) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
        child: Row(
          children: [
            const Text('IVE',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.screenName,
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ),
            if (state.turns.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                color: Colors.white38,
                tooltip: 'Limpar histórico desta conversa',
                onPressed: state.executing
                    ? null
                    : () => ref
                        .read(contextCopilotProvider(scope).notifier)
                        .clearHistory(),
              ),
            IconButton(
              key: const ValueKey('ive-chat-close'),
              icon: const Icon(Icons.close_rounded),
              color: Colors.white38,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

  Widget _projectBadge(String? projectName) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: projectName == null
              ? Colors.orange.withValues(alpha: 0.12)
              : const Color(0xFF6C63FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: projectName == null
                ? Colors.orangeAccent.withValues(alpha: 0.5)
                : const Color(0xFF6C63FF).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              projectName == null
                  ? Icons.info_outline_rounded
                  : Icons.workspaces_rounded,
              color: projectName == null
                  ? Colors.orangeAccent
                  : const Color(0xFF9B8FFF),
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                projectName == null
                    ? 'Nenhum projeto selecionado'
                    : 'Projeto ativo: $projectName',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            if (projectName == null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).go(AppConstants.routeProjects);
                },
                child: const Text('Selecionar'),
              ),
          ],
        ),
      );

  Widget _empty(bool hasProject) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('◆',
                  style: TextStyle(fontSize: 42, color: Color(0xFF8B7CFF))),
              const SizedBox(height: 12),
              Text(
                hasProject
                    ? 'Posso analisar prioridades e transformar uma recomendação em ação.'
                    : 'Selecione um projeto para iniciar uma conversa executiva.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (hasProject) ...[
                const SizedBox(height: 18),
                ..._suggestions().map(_suggestionChip),
              ],
            ],
          ),
        ),
      );

  List<String> _suggestions() => const [
        'Qual ação devo priorizar para melhorar este projeto?',
        'Quais oportunidades têm maior impacto agora?',
      ];

  Widget _suggestionChip(String text) => GestureDetector(
        onTap: () {
          _controller.text = text;
          _send();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF6C63FF)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9B8FFF), fontSize: 12)),
        ),
      );

  Widget _messages(List<CopilotTurn> turns) => ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: turns.length,
        itemBuilder: (_, index) => _TurnBubble(turn: turns[index]),
      );

  Widget _executionResult(BuildContext context, ActionQueueItem action) =>
      Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Status: ${action.status}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                GoRouter.of(context).go('/action-engine/${action.id}');
              },
              child: const Text('Abrir no Action Engine'),
            ),
          ],
        ),
      );

  Widget _input(bool busy, bool hasProject) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('ive-chat-input'),
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  enabled: !busy && hasProject,
                  maxLines: null,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hasProject
                        ? widget.inputHint ?? 'Pergunte à IVE…'
                        : 'Selecione um projeto para conversar',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF2A2740),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF6C63FF)),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('ive-chat-send'),
                      onPressed: hasProject ? _send : null,
                      icon: const Icon(Icons.send_rounded),
                      color: const Color(0xFF6C63FF),
                    ),
            ],
          ),
        ),
      );
}

class _TurnBubble extends StatelessWidget {
  final CopilotTurn turn;

  const _TurnBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.84,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6C63FF) : const Color(0xFF2A2740),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(turn.content,
                style: const TextStyle(color: Colors.white, height: 1.4)),
            if (!isUser && turn.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: turn.sources.take(3).map((source) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(source,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10)),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
