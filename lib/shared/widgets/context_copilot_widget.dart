import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/diagnostics/diagnostic_models.dart';
import '../../core/ui/breakpoints.dart';
import '../../core/utils/uuid_v4.dart';
import '../../data/models/copilot_context_data.dart';
import '../../data/models/copilot_turn.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../features/ive/visual/ive_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/context_copilot_provider.dart';
import '../../providers/diagnostic_session_provider.dart';
import 'ai_execution_confirmation.dart';

// COMMERCIAL-EXPERIENCE-CLOSURE-16 — owner feedback (live physical/web QA,
// both platforms): while the chat dialog/sheet is open, IveOverlay's own
// floating avatar+bubble stayed visible underneath it -- two
// representations of IVE on screen at once, redundant with the portrait
// now shown inside the dialog itself (Section 01.3). Plain top-level
// ValueNotifier, matching the existing `iveRouteNotifier` pattern in
// ive_overlay.dart (that file already listens to a module-level notifier
// this way; this is the same mechanism, not a second one) -- avoids
// coupling this widget to IveOverlay's Riverpod providers just to toggle
// one boolean. Set true immediately before presenting, false once the
// route's own Future resolves (covers every dismissal path: close button,
// system back, tap-outside, or programmatic pop).
final iveChatOpenNotifier = ValueNotifier<bool>(false);

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

  // IVE-EXPERIENCE-V1-06 (Section 21/27) — minimal analytics, reusing the
  // existing DiagnosticCategory.ive vocabulary. Logged here (the single
  // choke point) rather than per call site, so it can never be forgotten by
  // a future module wiring. 'global_overlay' is IveOverlay's own
  // sourceModule value (see ive_overlay.dart) — every other value is a
  // contextual module entry point.
  ProviderScope.containerOf(context).read(diagnosticSessionProvider.notifier).logEvent(
        category:  DiagnosticCategory.ive,
        eventName: request.sourceModule == 'global_overlay' ? 'ive_opened_global' : 'ive_opened_contextual',
        operation: request.sourceModule,
      );

  _presentCopilotSheet(
    context,
    desktop: Breakpoints.isDesktop(MediaQuery.of(context).size.width),
    child: _CopilotSheet(
      screenName:     screenName,
      context:        resolvedContext,
      initialMessage: initialMessage,
    ),
  );
}

// COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 09) — the owner
// rejected the previous presentation for being "too small" on desktop: a
// bottom sheet capped at 92% height still reads as a thin strip pinned to
// the bottom of a large monitor, with no real reading/conversation area.
// Desktop gets a materially larger, centered dialog instead; mobile/tablet
// keep the existing DraggableScrollableSheet (already appropriate for a
// small viewport, and not something the mission asked to change). Both
// paths render the exact same `_CopilotSheet` content — this is a second
// presentation SHELL, not a second assistant.
void _presentCopilotSheet(BuildContext context, {required bool desktop, required Widget child}) {
  iveChatOpenNotifier.value = true;
  final Future<void> closed;
  if (desktop) {
    closed = showDialog(
      context: context,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child:  child,
      ),
    );
  } else {
    closed = showModalBottomSheet(
      context:            context,
      isScrollControlled:  true,
      backgroundColor:     Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child:  child,
      ),
    );
  }
  closed.whenComplete(() => iveChatOpenNotifier.value = false);
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
    final l10n = AppLocalizations.of(ctx)!;
    return FloatingActionButton(
      heroTag: 'copilot_$screenName',
      onPressed: () => _openCopilot(ctx, ref),
      backgroundColor: const Color(0xFF6C63FF),
      tooltip: l10n.iveChatAskCta,
      // Functional trigger (opens the chat) -- exactly the case mission
      // Section 01.2 carves out as a legitimate use of chat iconography,
      // unlike the removed decorative bubble inside the sheet itself below.
      child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
    );
  }

  void _openCopilot(BuildContext ctx, WidgetRef ref) {
    _presentCopilotSheet(
      ctx,
      desktop: Breakpoints.isDesktop(MediaQuery.of(ctx).size.width),
      child: _CopilotSheet(
        screenName: screenName,
        context:    context,
      ),
    );
  }
}

// ── Internal sheet/dialog content ────────────────────────────────────────────

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

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 11/12) — closes the
  // known gap where CopilotActionSuggestion was populated by the backend
  // but the chip rendering it had no onTap at all (purely decorative).
  //
  // The LLM (context-copilot/index.ts) is never given real database IDs
  // for opportunities/projects/actions in its prompt context — only
  // display fields (title/score/status). Its `action_suggestion.data` is
  // therefore a PROPOSAL, not a verified reference to an existing row.
  // Auto-executing a mutation (create/approve) straight from unverified
  // model output, with no human review of what's actually about to
  // happen, would reopen exactly the "no decorative fake action, but also
  // no unreviewed AI-driven mutation" tension the mission's own STOP
  // conditions warn about (material product-direction risk to
  // EXECUTION SECURITY). The safe, real, and honest action every one of
  // these types can perform today is: navigate to the existing screen
  // that already owns that creation/approval flow (with its own already-
  // audited confirmation boundary), and tell the user what IVE proposed
  // so they can act on it there. `generate_roadmap` has no dedicated
  // screen anywhere in this app (confirmed by repository search) — it
  // stays truthfully disabled rather than pointed at a fake destination.
  void _handleActionSuggestion(CopilotActionSuggestion action) {
    final l10n = AppLocalizations.of(context)!;
    String? route;
    switch (action.type) {
      case 'create_action':
        route = AppConstants.routeActionEngine;
        break;
      case 'approve_opportunity':
        route = AppConstants.routeOpportunityLab;
        break;
      case 'create_project':
        route = AppConstants.routeProjects;
        break;
      default:
        route = null; // includes 'generate_roadmap' -- no existing screen owns it
    }

    final messenger = ScaffoldMessenger.of(context);
    if (route == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.iveActionNoDestination)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.iveActionSuggestionHint(action.label))));
    final router = GoRouter.of(context); // capture while context is still mounted
    Navigator.of(context).pop();
    router.go(route);
  }

  @override
  Widget build(BuildContext ctx) {
    final desktop = Breakpoints.isDesktop(MediaQuery.of(ctx).size.width);
    return desktop ? _buildDesktopDialog(ctx) : _buildMobileSheet(ctx);
  }

  // ── Desktop: centered, materially larger dialog ─────────────────────────
  Widget _buildDesktopDialog(BuildContext ctx) {
    final screen = MediaQuery.of(ctx).size;
    final width  = (screen.width * 0.42).clamp(480.0, 680.0);
    final height = (screen.height * 0.78).clamp(560.0, 820.0);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:    const EdgeInsets.all(24),
      child: Container(
        width:  width,
        height: height,
        decoration: BoxDecoration(
          color:        const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _body(showDragHandle: false),
      ),
    );
  }

  // ── Mobile/tablet: existing draggable bottom sheet ──────────────────────
  Widget _buildMobileSheet(BuildContext ctx) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.35,
      maxChildSize:     0.92,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1B2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _body(showDragHandle: true),
      ),
    );
  }

  Widget _body({required bool showDragHandle}) {
    final state = ref.watch(contextCopilotProvider(_conversationKey));

    if (state.turns.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Column(
      children: [
        if (showDragHandle) _handle(),
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
              AppLocalizations.of(context)!.iveChatErrorPrefix(state.error ?? ''),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        _input(state.loading),
      ],
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

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 01.2) — the previous
  // header paired a 💬 emoji with the "IVE" text right next to it: two
  // representations of the same idea (this is IVE's chat) in a two-word
  // row. Removed rather than replaced -- the hero portrait below (_empty)
  // and the status ring already carry IVE's identity; this row's only
  // remaining job is the title + the two functional icon buttons.
  Widget _header(CopilotState state) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'IVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          if (state.turns.isNotEmpty)
            IconButton(
              icon:    const Icon(Icons.delete_sweep_rounded, size: 20),
              color:   Colors.white38,
              tooltip: l10n.iveChatClearHistory,
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
  }

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 01.3) — this was a
  // 48px 💬 emoji: a second, LARGER generic speech bubble (redundant with
  // the header's) standing in for IVE's actual visual identity. Replaced
  // with the real, approved 03B2 portrait (IveAvatar, already the
  // canonical widget used everywhere else IVE appears -- IveOverlay,
  // IveIntroSheet -- so this is the SAME character, not a second one).
  // Rive stays frozen (IveRiveFeatureGate=false, untouched): IveAvatar
  // transparently falls back to IveVisualFallback exactly as it already
  // does today.
  //
  // Avatar size is responsive, not a single fixed hero size: the mobile
  // sheet's initial height (DraggableScrollableSheet, 55% of a phone
  // screen) genuinely cannot fit a 220dp portrait plus title/subtitle/two
  // suggestion chips without overflowing (found by this mission's own
  // widget test at 400x800 -- a real bug, not a hypothetical one). The
  // desktop dialog has the room mission Section 09 asked for; mobile gets
  // `detail` (160dp) -- still far larger than the old ~24px emoji, just
  // not the same size as a materially bigger, dedicated desktop surface.
  // Wrapped in SingleChildScrollView as defense-in-depth for any viewport
  // this sizing still doesn't anticipate (e.g. a phone in landscape),
  // never clipping content mission Section 24 requires stay visible.
  Widget _empty() {
    final l10n = AppLocalizations.of(context)!;
    final desktop = Breakpoints.isDesktop(MediaQuery.of(context).size.width);
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        // ConstrainedBox + minHeight is the standard way to keep content
        // vertically centered when it fits, while still allowing it to
        // scroll (instead of overflowing) when it doesn't.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IveAvatar(
                  size:           desktop ? IveAvatarSize.hero : IveAvatarSize.detail,
                  showStatusRing: true,
                  interactive:    false,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.iveChatAskCta,
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _localizedScreenName(context, widget.screenName),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 20),
                ..._suggestions(context).map((s) => _suggestionChip(s)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _suggestions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.screenName) {
      case 'Projetos':
        return [l10n.iveSuggestionProjects1, l10n.iveSuggestionProjects2];
      case 'Oportunidades':
        return [l10n.iveSuggestionOpportunities1, l10n.iveSuggestionOpportunities2];
      case 'Scores':
        return [l10n.iveSuggestionScores1, l10n.iveSuggestionScores2];
      case 'Decisões':
        return [l10n.iveSuggestionDecisions1, l10n.iveSuggestionDecisions2];
      case 'Briefing':
        return [l10n.iveSuggestionBriefing1, l10n.iveSuggestionBriefing2];
      case 'Conhecimento':
        return [l10n.iveSuggestionKnowledge1, l10n.iveSuggestionKnowledge2];
      case 'Personas':
        return [l10n.iveSuggestionPersonas1, l10n.iveSuggestionPersonas2];
      default:
        return [l10n.iveSuggestionDefault1, l10n.iveSuggestionDefault2];
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
        itemBuilder: (_, i) => _TurnBubble(
          turn: turns[i],
          onActionTap: turns[i].actionSuggestion != null
              ? () => _handleActionSuggestion(turns[i].actionSuggestion!)
              : null,
        ),
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
                    hintText:       AppLocalizations.of(context)!.iveChatHint,
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

// COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 01.8) — `screenName`
// is passed as a stable PT-canonical identifier from ~9 call sites across
// the app (see e.g. ive_overlay.dart's `_routeToName`) and used internally
// as a conversation-history key (`_conversationKey` above) and an analytics
// label -- changing what callers pass would be a much larger, riskier
// refactor than this mission's "smallest coherent delta" calls for. This
// maps that SAME stable identifier to a localized DISPLAY string only,
// exactly where it is shown to the user. An unmapped/custom screenName
// falls back to the raw value (today's exact behavior), which is never a
// regression -- only mapped names change display language.
String _localizedScreenName(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;
  const map = <String, String Function(AppLocalizations)>{
    'Ações':                   _screenActions,
    'Website Analyzer':        _screenWebsiteAnalyzer,
    'Projetos':                _screenProjects,
    'Decisões':                _screenDecisions,
    'Conhecimento':            _screenKnowledge,
    'Market Intelligence':     _screenMarketIntelligence,
    'Business OS':             _screenBusinessOs,
    'Oportunidades':           _screenOpportunities,
    'Briefing':                _screenBriefing,
    'Recursos':                _screenResources,
    'Personas':                _screenPersonas,
    'Debug Hub':               _screenDebugHub,
    'ROI Tracker':             _screenRoiTracker,
    'Scores':                  _screenScores,
  };
  final fn = map[raw];
  return fn == null ? raw : fn(l10n);
}

String _screenActions(AppLocalizations l) => l.iveScreenActions;
String _screenWebsiteAnalyzer(AppLocalizations l) => l.iveScreenWebsiteAnalyzer;
String _screenProjects(AppLocalizations l) => l.iveScreenProjects;
String _screenDecisions(AppLocalizations l) => l.iveScreenDecisions;
String _screenKnowledge(AppLocalizations l) => l.iveScreenKnowledge;
String _screenMarketIntelligence(AppLocalizations l) => l.iveScreenMarketIntelligence;
String _screenBusinessOs(AppLocalizations l) => l.iveScreenBusinessOs;
String _screenOpportunities(AppLocalizations l) => l.iveScreenOpportunities;
String _screenBriefing(AppLocalizations l) => l.iveScreenBriefing;
String _screenResources(AppLocalizations l) => l.iveScreenResources;
String _screenPersonas(AppLocalizations l) => l.iveScreenPersonas;
String _screenDebugHub(AppLocalizations l) => l.iveScreenDebugHub;
String _screenRoiTracker(AppLocalizations l) => l.iveScreenRoiTracker;
String _screenScores(AppLocalizations l) => l.iveScreenScores;

// ── Message bubble ────────────────────────────────────────────────────────────

class _TurnBubble extends StatelessWidget {
  final CopilotTurn   turn;
  final VoidCallback? onActionTap;
  const _TurnBubble({required this.turn, this.onActionTap});

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
              _actionChip(turn.actionSuggestion!, onActionTap),
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

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 — now wired to `onActionTap`
  // (`_CopilotSheetState._handleActionSuggestion`); previously a plain
  // Container with no GestureDetector at all (mission Section 01.4:
  // "Commercial V1 must not ship misleading decorative actions").
  Widget _actionChip(CopilotActionSuggestion action, VoidCallback? onTap) => InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
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
        ),
      );
}
