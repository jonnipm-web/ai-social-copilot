import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/ive_forensic_snapshot.dart';
import '../../data/models/copilot_context_data.dart';
import '../../data/models/ive_interaction_request.dart';
import '../../data/models/ive_issue.dart';
import '../../data/models/ive_state.dart';
import '../../features/ive/visual/ive_avatar.dart';
import '../../features/ive/visual/ive_visual_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ive_context_provider.dart';
import '../../providers/ive_memory_provider.dart';
import '../../providers/ive_provider.dart';
import '../../providers/profile_provider.dart';
import 'context_copilot_widget.dart' show showCopilotChat;

// ── Route bridge ──────────────────────────────────────────────────────────────
final iveRouteNotifier = ValueNotifier<String>('');

class IveRouteObserver extends NavigatorObserver {
  void _notify(Route route) {
    final name = route.settings.name ?? '';
    if (name.isNotEmpty) iveRouteNotifier.value = name;
  }

  @override void didPush(Route route, Route? previousRoute) => _notify(route);

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) _notify(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) _notify(newRoute);
  }
}

// ── Overlay ───────────────────────────────────────────────────────────────────

class IveOverlay extends ConsumerStatefulWidget {
  const IveOverlay({super.key});

  @override
  ConsumerState<IveOverlay> createState() => _IveOverlayState();
}

class _IveOverlayState extends ConsumerState<IveOverlay> {
  Offset? _position;
  bool    _dragging = false;

  @override
  void initState() {
    super.initState();
    iveRouteNotifier.addListener(_onRouteChange);
    // IVE-COMMERCIAL-STABILITY-09O — reuses this already-existing lifecycle
    // callback; no new listener.
    IveForensicSnapshot.overlayMounted = true;
  }

  @override
  void dispose() {
    iveRouteNotifier.removeListener(_onRouteChange);
    // IVE-COMMERCIAL-STABILITY-09O (Codex Gate, P2 ACCEPTED) — a dispose
    // mid-drag (e.g. a fast sign-out while dragging) would otherwise leave
    // overlayDragging stuck true forever, misleadingly implying an
    // in-progress drag at the moment of some LATER, unrelated crash.
    IveForensicSnapshot.overlayMounted  = false;
    IveForensicSnapshot.overlayDragging = false;
    super.dispose();
  }

  void _onRouteChange() {
    final route = iveRouteNotifier.value;
    ref.read(iveProvider.notifier).setRoute(route);
    ref.read(iveMemoryProvider.notifier).setRoute(route);
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  // IVE-EXPERIENCE-V1-06QA (live-QA gate-2 defect, Codex-confirmed P1) —
  // `_position.dx` is the column's distance from the RIGHT edge of the
  // screen, not a left-x coordinate. The column (bubble + avatar, sized to
  // fit its widest child, up to the bubble's `maxWidth: 220`) used to be
  // anchored via `Positioned(left: screen.width - 88, ...)`. That assumed
  // the column was only ~88px wide (avatar + margin), but the bubble is up
  // to 220px wide, so the right-aligned avatar rendered `220 - 88 = 132px`
  // past the visible edge on every desktop-width screen -- unreachable,
  // regardless of viewport width, whenever the bubble was wide enough to
  // hit maxWidth (e.g. any real alert message). Anchoring with `right:`
  // instead (see build() below) makes the column grow leftward from a
  // fixed right margin, so its right-aligned avatar is always exactly
  // `dx` away from the screen's right edge no matter how wide the bubble
  // gets -- structurally immune to this class of overflow.
  Offset _defaultPosition(Size screen) {
    if (_isDesktop) {
      // Desktop: safe corner — bottom-right with extra margin to avoid overlapping content
      return Offset(88, screen.height - 220);
    }
    return Offset(80, screen.height - 200);
  }

  @override
  Widget build(BuildContext context) {
    // IVE-EXPERIENCE-V1-06QA (live-QA defect) — this overlay is mounted
    // globally in app.dart's Stack with NO route awareness at all, so
    // before this fix it rendered on every screen including /login and
    // /splash. IveIntroGate (mounted in the same Stack) already gated
    // itself on `currentProfileProvider` resolving to a non-null profile
    // — the exact same "authenticated and app-state stable" signal used
    // elsewhere in app.dart — but that comment explicitly (and wrongly)
    // assumed IveOverlay needed no equivalent gate ("Never shown on
    // Splash/Login" referred only to the intro sheet, not this widget).
    //
    // Codex adversarial review (this fix, P1, ACCEPTED) — gating on
    // `currentProfileProvider` alone fails closed for the unauthenticated/
    // loading/error states, but not for an IN-FLIGHT sign-out: AuthNotifier.
    // signOut() awaits the Supabase call BEFORE invalidating the profile
    // provider (auth_provider.dart), so a previously-resolved non-null
    // profile can briefly remain cached while sign-out is still in
    // progress. Also requiring `authStateProvider`'s session to be
    // non-null closes this: that stream reflects Supabase's own
    // client-side auth state change directly, independent of when this
    // app's own profile-invalidation call happens to run afterward.
    final hasSession = ref.watch(authStateProvider).valueOrNull?.session != null;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    // IVE-COMMERCIAL-STABILITY-09O — reuses this already-existing provider
    // watch; no new subscription.
    IveForensicSnapshot.profileResolved = profile != null;
    if (!hasSession || profile == null) {
      // IVE-COMMERCIAL-STABILITY-09O (Codex Gate, P2 ACCEPTED) — this early
      // return skips the `issuePresent`/`overlayDragging` writes below, so
      // without this, a stale `true` from BEFORE sign-out/session-loss
      // would misleadingly survive into a later crash's forensic snapshot
      // even though the overlay (and its issue bubble) is no longer shown.
      IveForensicSnapshot.issuePresent    = false;
      IveForensicSnapshot.overlayDragging = false;
      return const SizedBox.shrink();
    }

    final state  = ref.watch(iveProvider);
    // IVE-COMMERCIAL-STABILITY-09O — reuses the `state` already read above
    // for the widget's own rendering; no new watch.
    IveForensicSnapshot.issuePresent = state.activeIssue != null;
    final screen = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    _position ??= _defaultPosition(screen);

    // On desktop clamp to avoid navigation bars / toolbars
    final maxY = _isDesktop
        ? screen.height - 140 - safeBottom
        : screen.height - 100;

    return Positioned(
      right: _position!.dx,
      top:   _position!.dy,
      child: GestureDetector(
        onPanStart:  (_) => setState(() {
          _dragging = true;
          IveForensicSnapshot.overlayDragging = true;
        }),
        onPanUpdate: (d) => setState(() {
          // dx tracks distance-from-right: dragging right (positive delta.dx)
          // moves the widget closer to the right edge, so dx DECREASES.
          _position = Offset(_position!.dx - d.delta.dx, _position!.dy + d.delta.dy).clamp(
            Offset.zero,
            Offset(screen.width - 72, maxY),
          );
        }),
        onPanEnd: (_) => setState(() {
          _dragging = false;
          IveForensicSnapshot.overlayDragging = false;
        }),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Speech bubble — IgnorePointer evita hitbox invisível quando opacity=0
            IgnorePointer(
              ignoring: !state.bubbleVisible || _dragging,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity:  state.bubbleVisible && !_dragging ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 350),
                  offset:   state.bubbleVisible && !_dragging
                      ? Offset.zero
                      : const Offset(0, 0.15),
                  curve:    Curves.easeOut,
                  child: _IveBubble(
                    message:     state.message,
                    expression:  state.expression,
                    activeIssue: state.activeIssue,
                    onDismiss: () {
                      // Overlay global, sem projeto específico em foco — ver
                      // comentário do provider em ive_context_provider.dart.
                      final ctx = ref.read(iveContextDataProvider(null)).valueOrNull;
                      if (ctx != null && ctx.alertId.isNotEmpty) {
                        ref.read(iveMemoryProvider.notifier).dismissAlert(ctx.alertId);
                      }
                      ref.read(iveProvider.notifier).dismissBubble();
                    },
                    onChat: state.activeIssue == null
                        ? () => _openChat(context, state.screenName)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── New IveAvatar (replaces old IveAvatarWidget) ─────────────────
            // IVE-AVATAR-COMMERCIAL-FALLBACK-04 (Codex P2): the avatar is
            // mounted with interactive:false (overlay owns the tap), which
            // skips IveAvatar's own Semantics wrapper — so the overlay
            // provides the screen-reader label/button role here instead.
            Semantics(
              label:            'IVE, assistente executiva',
              button:           true,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  if (_dragging) return;
                  if (state.bubbleVisible) {
                    ref.read(iveProvider.notifier).dismissBubble();
                  } else {
                    _openChat(context, state.screenName);
                  }
                },
                child: AnimatedScale(
                  scale:    _dragging ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: IveAvatar(
                    size:           IveAvatarSize.compact,
                    showStatusRing: true,
                    interactive:    false, // overlay owns the tap
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String screenName) {
    ref.read(iveMemoryProvider.notifier).incrementInteraction();
    // Overlay global — sempre projectId: null. Se o usuário estiver
    // dentro do Project Command Center de um projeto específico, esse
    // botão de tela usa seu próprio showCopilotChat com o projectId real
    // (ver project_command_center_screen.dart); este é o avatar
    // FLUTUANTE, presente em toda tela, sem noção de "projeto atual".
    final ctx = ref.read(iveContextDataProvider(null)).valueOrNull;
    // IVE-COMMERCIAL-TARGETED-REMEDIATION-04 — conversão movida para
    // CopilotContextData.fromIveContext() (fonte única, também usada por
    // ive_detail_sheet.dart) em vez de uma cópia privada só deste widget.
    final contextData = ctx != null ? CopilotContextData.fromIveContext(ctx) : const CopilotContextData();
    showCopilotChat(
      context,
      screenName:  _routeToName(screenName),
      contextData: contextData,
      request: IveInteractionRequest(
        sourceModule:  'global_overlay',
        operationType: IveOperationType.ask,
      ),
    );
  }

  String _routeToName(String route) {
    const map = <String, String>{
      '/projects':            'Projetos',
      '/opportunity-lab':     'Oportunidades',
      '/ecosystem':           'Decisões',
      '/ecosystem/briefing':  'Briefing',
      '/ecosystem/resources': 'Recursos',
      '/personas':            'Personas',
      '/knowledge':           'Conhecimento',
      '/action-engine':       'Ações',
      '/intelligence-debug':  'Debug Hub',
      '/market-intelligence': 'Inteligência de Mercado',
      '/roi-tracker':         'ROI Tracker',
    };
    return map[route] ?? route;
  }
}

// ── Speech bubble ─────────────────────────────────────────────────────────────

class _IveBubble extends StatelessWidget {
  final String        message;
  final IveExpression expression;
  final IveIssue?     activeIssue;
  final VoidCallback  onDismiss;
  final VoidCallback? onChat;

  const _IveBubble({
    required this.message,
    required this.expression,
    required this.onDismiss,
    this.activeIssue,
    this.onChat,
  });

  bool get _hasIssue => activeIssue != null;

  String get _moodIcon {
    if (_hasIssue) return '⚠';
    switch (expression) {
      case IveExpression.excited:  return '✦';
      case IveExpression.thinking: return '◈';
      case IveExpression.winking:  return '◉';
      case IveExpression.neutral:  return '⬡';
      case IveExpression.happy:    return '◈';
    }
  }

  Color get _accentColor =>
      _hasIssue ? const Color(0xFFFF4560) : const Color(0xFF7B5CF6);

  Color get _iconColor =>
      _hasIssue ? const Color(0xFFFF4560) : const Color(0xFF9B8FFF);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1535),
            borderRadius: const BorderRadius.only(
              topLeft:     Radius.circular(14),
              topRight:    Radius.circular(14),
              bottomLeft:  Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset:     const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _accentColor.withOpacity(0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
            children: [
              Row(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:  '$_moodIcon ',
                            style: TextStyle(color: _iconColor, fontSize: 11),
                          ),
                          TextSpan(
                            text:  message,
                            style: const TextStyle(
                              color:    Colors.white,
                              fontSize: 12,
                              height:   1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap:  onDismiss,
                    child:  const Icon(Icons.close_rounded, size: 14, color: Colors.white24),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_hasIssue)
                _IssueActions(issue: activeIssue!)
              else if (onChat != null)
                GestureDetector(
                  onTap: onChat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4, height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B5CF6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Conversar com a IVE',
                        style: TextStyle(
                          color:      Color(0xFF9B8FFF),
                          fontSize:   11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Issue action buttons ──────────────────────────────────────────────────────

class _IssueActions extends StatelessWidget {
  const _IssueActions({required this.issue});
  final IveIssue issue;

  @override
  Widget build(BuildContext context) {
    final actions = issue.recommendedActions;
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing:    6,
      runSpacing: 4,
      children:   actions.map((a) => _IssueActionChip(action: a)).toList(),
    );
  }
}

class _IssueActionChip extends StatelessWidget {
  const _IssueActionChip({required this.action});
  final IveIssueAction action;

  static const _color = Color(0xFFFF4560);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (action.actionKey == 'dismiss') {
          Navigator.of(context, rootNavigator: true).maybePop();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text(
          action.label,
          style: const TextStyle(
            color:      _color,
            fontSize:   10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

extension on Offset {
  Offset clamp(Offset min, Offset max) => Offset(
        dx.clamp(min.dx, max.dx),
        dy.clamp(min.dy, max.dy),
      );
}
