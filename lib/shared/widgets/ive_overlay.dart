import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/ive_issue.dart';
import '../../data/models/ive_state.dart';
import '../../features/ive/visual/ive_avatar.dart';
import '../../features/ive/domain/ive_route_context.dart';
import '../../features/ive/domain/ive_presentation_state.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ive_context_provider.dart';
import '../../providers/ive_memory_provider.dart';
import '../../providers/ive_provider.dart';
import '../../providers/knowledge_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/selected_project_provider.dart';
import 'context_copilot_widget.dart' show closeIveForSignedOut, openIveChat;
import 'ive_issue_detail_sheet.dart';

// ── Route bridge ──────────────────────────────────────────────────────────────
final iveRouteNotifier = ValueNotifier<String>('');

/// Fronteira visual de autenticação. Não cria [IveOverlay] enquanto não
/// existir uma sessão válida, evitando inicializar providers de negócio.
class AuthenticatedIveOverlay extends ConsumerStatefulWidget {
  const AuthenticatedIveOverlay({super.key});

  @override
  ConsumerState<AuthenticatedIveOverlay> createState() =>
      _AuthenticatedIveOverlayState();
}

class _AuthenticatedIveOverlayState
    extends ConsumerState<AuthenticatedIveOverlay> {
  void _clearSignedOutSession() {
    closeIveForSignedOut();
    iveRouteNotifier.value = '';
    ref.read(iveProvider.notifier).resetForSignedOut();
    ref.read(iveMemoryProvider.notifier).clearSensitiveSession();
    unawaited(ref.read(selectedProjectProvider.notifier).clear());
    ref.invalidate(iveContextDataProvider);
    ref.invalidate(projectsNotifierProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String?>>(authenticatedUserIdProvider,
        (previous, next) {
      if (previous?.valueOrNull != null && next.valueOrNull == null) {
        _clearSignedOutSession();
      }
    });
    final userId = ref.watch(authenticatedUserIdProvider).valueOrNull;
    if (userId == null) {
      return const SizedBox.shrink(
        key: ValueKey('ive-authenticated-overlay-blocked'),
      );
    }
    return const IveOverlay();
  }
}

class IveRouteObserver extends NavigatorObserver {
  void _registerModal(Route route) {
    if (route is PopupRoute) {
      ivePresentationController.registerModal(route);
    }
  }

  void _unregisterModal(Route route) {
    if (route is PopupRoute) {
      ivePresentationController.unregisterModal(route);
    }
  }

  void _notify(Route route) {
    final name = route.settings.name ?? '';
    if (name.isNotEmpty) iveRouteNotifier.value = name;
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _registerModal(route);
    _notify(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _unregisterModal(route);
    if (previousRoute != null) _notify(previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _unregisterModal(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (oldRoute != null) _unregisterModal(oldRoute);
    if (newRoute != null) _registerModal(newRoute);
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
  static const double _overlayWidth = 220;
  static const double _avatarTouchSize = 56;
  Offset? _position;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    iveRouteNotifier.addListener(_onRouteChange);
  }

  @override
  void dispose() {
    iveRouteNotifier.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() {
    final route = iveRouteNotifier.value;
    ref.read(iveProvider.notifier).setRoute(route);
    ref.read(iveMemoryProvider.notifier).setRoute(route);
  }

  Offset _defaultPosition(Size screen) => Offset(
      (screen.width - _overlayWidth - 12).clamp(0, double.infinity),
      screen.height - 200);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ivePresentationController,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        if (!ivePresentationController.externalOverlayVisible ||
            media.viewInsets.bottom > 0) {
          return const SizedBox.shrink(
            key: ValueKey('ive-external-overlay-hidden'),
          );
        }
        return _buildVisibleOverlay(context, media.size);
      },
    );
  }

  Widget _buildVisibleOverlay(BuildContext context, Size screen) {
    final state = ref.watch(iveProvider);
    _position ??= _defaultPosition(screen);

    final maxPosition = Offset(
      (screen.width - _overlayWidth).clamp(0, double.infinity),
      (screen.height - 100).clamp(0, double.infinity),
    );
    _position = _position!.clamp(Offset.zero, maxPosition);

    return Positioned(
      key: const ValueKey('ive-external-overlay-visible'),
      left: _position!.dx,
      top: _position!.dy,
      child: SizedBox(
        width: _overlayWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Speech bubble — IgnorePointer evita hitbox invisível quando opacity=0
            IgnorePointer(
              ignoring: !state.bubbleVisible || _dragging,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: state.bubbleVisible && !_dragging ? 1.0 : 0.0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 350),
                  offset: state.bubbleVisible && !_dragging
                      ? Offset.zero
                      : const Offset(0, 0.15),
                  curve: Curves.easeOut,
                  child: _IveBubble(
                    message: state.message,
                    expression: state.expression,
                    activeIssue: state.activeIssue,
                    onDismiss: () {
                      final ctx = ref.read(iveContextDataProvider).valueOrNull;
                      if (ctx != null && ctx.alertId.isNotEmpty) {
                        ref
                            .read(iveMemoryProvider.notifier)
                            .dismissAlert(ctx.alertId);
                      }
                      ref.read(iveProvider.notifier).dismissBubble();
                    },
                    onChat: state.activeIssue == null
                        ? () {
                            _debugTap('IVE_CTA_TAP');
                            ref.read(iveProvider.notifier).dismissBubble();
                            _openChat(context, state.screenName);
                          }
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // ── New IveAvatar (replaces old IveAvatarWidget) ─────────────────
            GestureDetector(
              key: const ValueKey('ive-overlay-avatar'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => setState(() => _dragging = true),
              onPanUpdate: (d) => setState(() {
                _position = (_position! + d.delta).clamp(
                  Offset.zero,
                  maxPosition,
                );
              }),
              onPanEnd: (_) => setState(() => _dragging = false),
              onTap: () {
                if (_dragging) return;
                _debugTap('IVE_AVATAR_TAP');
                if (state.bubbleVisible) {
                  ref.read(iveProvider.notifier).dismissBubble();
                }
                _openChat(context, state.screenName);
              },
              child: SizedBox(
                width: _avatarTouchSize,
                height: _avatarTouchSize,
                child: AnimatedScale(
                  scale: _dragging ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: const IveAvatar(
                    size: IveAvatarSize.compact,
                    showStatusRing: true,
                    interactive: false, // overlay owns the tap
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
    openIveChat(
      context,
      screenName: IveRouteContext.displayName(screenName),
      route: screenName,
    );
  }

  void _debugTap(String marker) {
    assert(() {
      debugPrint(marker);
      return true;
    }());
  }
}

// ── Speech bubble ─────────────────────────────────────────────────────────────

class _IveBubble extends StatelessWidget {
  final String message;
  final IveExpression expression;
  final IveIssue? activeIssue;
  final VoidCallback onDismiss;
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
      case IveExpression.excited:
        return '✦';
      case IveExpression.thinking:
        return '◈';
      case IveExpression.winking:
        return '◉';
      case IveExpression.neutral:
        return '⬡';
      case IveExpression.happy:
        return '◈';
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
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: _accentColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_moodIcon ',
                            style: TextStyle(color: _iconColor, fontSize: 11),
                          ),
                          TextSpan(
                            text: message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Colors.white24),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_hasIssue)
                _IssueActions(issue: activeIssue!)
              else if (onChat != null)
                GestureDetector(
                  key: const ValueKey('ive-bubble-chat-cta'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onChat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B5CF6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Flexible(
                        child: Text(
                          'Conversar com a IVE',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF9B8FFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
      spacing: 6,
      runSpacing: 4,
      children: actions.map((a) => _IssueActionChip(action: a)).toList(),
    );
  }
}

class _IssueActionChip extends ConsumerWidget {
  const _IssueActionChip({required this.action});
  final IveIssueAction action;

  static const _color = Color(0xFFFF4560);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _handle(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Text(
          action.label,
          style: const TextStyle(
            color: _color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, WidgetRef ref) async {
    final issue = ref.read(iveProvider).activeIssue;
    switch (action.actionKey) {
      case 'dismiss':
        ref.read(iveProvider.notifier).dismissBubble();

      case 'retry':
        if (issue?.entityType == 'knowledge_item' && issue?.entityId != null) {
          // Retry real: rebusca o item e re-dispara a análise por IA
          ref.read(iveProvider.notifier).dismissBubble();
          final svc = ref.read(knowledgeServiceProvider);
          final item = await svc.fetchById(issue!.entityId!);
          if (item != null) {
            await ref
                .read(
                    knowledgeAnalysisNotifierProvider(issue.entityId!).notifier)
                .analyze(item);
          }
        } else {
          // Fallback: reinicia o ciclo de mensagens da tela atual
          ref.read(iveProvider.notifier).retryCurrentRoute();
        }

      case 'view_details':
        // Abre o sheet de diagnóstico completo
        if (issue != null && context.mounted) {
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => IveIssueDetailSheet(issue: issue),
          );
        }

      case 'send_file':
        // Navega para o Cofre de Conhecimento para upload
        ref.read(iveProvider.notifier).dismissBubble();
        if (context.mounted) {
          GoRouter.of(context).push(AppConstants.routeKnowledge);
        }

      case 'update_link':
        // Navega para a edição do item de conhecimento
        ref.read(iveProvider.notifier).dismissBubble();
        if (issue?.entityId != null && context.mounted) {
          GoRouter.of(context).push('/knowledge/${issue!.entityId}/edit');
        }

      default:
        ref.read(iveProvider.notifier).dismissBubble();
    }
  }
}

extension on Offset {
  Offset clamp(Offset min, Offset max) => Offset(
        dx.clamp(min.dx, max.dx),
        dy.clamp(min.dy, max.dy),
      );
}
