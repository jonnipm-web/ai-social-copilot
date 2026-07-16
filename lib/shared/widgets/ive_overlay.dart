import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/copilot_context_data.dart';
import '../../data/models/ive_state.dart';
import '../../providers/ive_context_provider.dart';
import '../../providers/ive_memory_provider.dart';
import '../../providers/ive_provider.dart';
import 'context_copilot_widget.dart' show showCopilotChat;
import 'ive_avatar.dart';

// ── Route bridge ──────────────────────────────────────────────────────────────
// GoRouter observer seta este notifier; IveOverlay lê e sincroniza ao iveProvider.
final iveRouteNotifier = ValueNotifier<String>('');

class IveRouteObserver extends NavigatorObserver {
  void _notify(Route route) {
    final name = route.settings.name ?? '';
    if (name.isNotEmpty) iveRouteNotifier.value = name;
  }

  @override
  void didPush(Route route, Route? previousRoute) => _notify(route);

  @override
  void didPop(Route route, Route? previousRoute) {
    if (previousRoute != null) _notify(previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute != null) _notify(newRoute);
  }
}

// ── Overlay widget ─────────────────────────────────────────────────────────────

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
  }

  void _onRouteChange() {
    final route = iveRouteNotifier.value;
    ref.read(iveProvider.notifier).setRoute(route);
    ref.read(iveMemoryProvider.notifier).setRoute(route);
  }

  @override
  void dispose() {
    iveRouteNotifier.removeListener(_onRouteChange);
    super.dispose();
  }

  Offset _defaultPosition(Size screen) =>
      Offset(screen.width - 80, screen.height - 200);

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(iveProvider);
    final screen = MediaQuery.of(context).size;
    _position ??= _defaultPosition(screen);

    // ── Listener de contexto: sobrescreve mensagem quando há alerta ou dados ──
    ref.listen<AsyncValue<IveContextData>>(iveContextDataProvider, (prev, next) {
      next.whenData((ctx) {
        final route   = iveRouteNotifier.value;
        final memory  = ref.read(iveMemoryProvider);
        final alertId = ctx.alertId;

        // Exibe alerta apenas se ainda não foi dispensado nesta sessão
        if (ctx.hasAlert && alertId.isNotEmpty && !memory.isAlertDismissed(alertId)) {
          ref.read(iveProvider.notifier).showContextAwareMessage(ctx, route);
        } else if (!ctx.hasAlert) {
          // Atualiza mensagem com dados reais quando não há alerta
          ref.read(iveProvider.notifier).showContextAwareMessage(ctx, route);
        }
      });
    });

    return Positioned(
      left: _position!.dx,
      top:  _position!.dy,
      child: GestureDetector(
        onPanStart:  (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() {
          _position = (_position! + d.delta).clamp(
            Offset.zero,
            Offset(screen.width - 72, screen.height - 100),
          );
        }),
        onPanEnd:    (_) => setState(() => _dragging = false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Speech bubble
            AnimatedOpacity(
              duration: const Duration(milliseconds: 350),
              opacity:  state.bubbleVisible && !_dragging ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 350),
                offset:   state.bubbleVisible && !_dragging
                    ? Offset.zero
                    : const Offset(0, 0.15),
                curve:    Curves.easeOut,
                child:    _IveBubble(
                  message:    state.message,
                  expression: state.expression,
                  onDismiss:  () {
                    // Persiste dismiss do alerta atual
                    final ctx = ref.read(iveContextDataProvider).valueOrNull;
                    if (ctx != null && ctx.alertId.isNotEmpty) {
                      ref.read(iveMemoryProvider.notifier).dismissAlert(ctx.alertId);
                    }
                    ref.read(iveProvider.notifier).dismissBubble();
                  },
                  onChat: () => _openChat(context, state.screenName),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Avatar
            GestureDetector(
              onTap: () {
                if (!_dragging) {
                  if (state.bubbleVisible) {
                    ref.read(iveProvider.notifier).dismissBubble();
                  } else {
                    _openChat(context, state.screenName);
                  }
                }
              },
              child: AnimatedScale(
                scale:    _dragging ? 0.92 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: IveAvatarWidget(
                  expression: state.expression,
                  size:       62,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context, String screenName) {
    // Incrementa contador de interações
    ref.read(iveMemoryProvider.notifier).incrementInteraction();

    // Constrói contexto rico com dados reais do ecossistema
    final ctx = ref.read(iveContextDataProvider).valueOrNull;
    final contextData = ctx != null ? _buildCopilotContext(ctx) : CopilotContextData();

    showCopilotChat(
      context,
      screenName:  _routeToName(screenName),
      contextData: contextData,
    );
  }

  CopilotContextData _buildCopilotContext(IveContextData ctx) {
    return CopilotContextData(
      scores: {
        'ecosystem_health':          ctx.healthScore,
        'total_projects':            ctx.projectCount,
        'pending_actions':           ctx.pendingActionsCount,
        'pending_opportunities':     ctx.pendingOpportunitiesCount,
        if (ctx.topProjectName  != null) 'top_project_name':  ctx.topProjectName,
        if (ctx.topProjectScore != null) 'top_project_score': ctx.topProjectScore,
        if (ctx.mainBottleneckName != null) 'main_bottleneck': ctx.mainBottleneckName,
        if (ctx.mainBottleneckScore != null) 'bottleneck_execution_score': ctx.mainBottleneckScore,
      },
    );
  }

  String _routeToName(String route) {
    const map = <String, String>{
      '/projects':           'Projetos',
      '/opportunity-lab':    'Oportunidades',
      '/ecosystem':          'Decisões',
      '/ecosystem/briefing': 'Briefing',
      '/ecosystem/resources':'Recursos',
      '/personas':           'Personas',
      '/knowledge':          'Conhecimento',
      '/action-engine':      'Ações',
      '/intelligence-debug': 'Debug Hub',
      '/market-intelligence':'Inteligência de Mercado',
      '/roi-tracker':        'ROI Tracker',
    };
    return map[route] ?? route;
  }
}

// ── Speech bubble ─────────────────────────────────────────────────────────────

class _IveBubble extends StatelessWidget {
  final String        message;
  final IveExpression expression;
  final VoidCallback  onDismiss;
  final VoidCallback  onChat;

  const _IveBubble({
    required this.message,
    required this.expression,
    required this.onDismiss,
    required this.onChat,
  });

  String get _moodIcon {
    switch (expression) {
      case IveExpression.excited:  return '✦';
      case IveExpression.thinking: return '◈';
      case IveExpression.winking:  return '◉';
      case IveExpression.neutral:  return '⬡';
      case IveExpression.happy:
      default:                     return '◈';
    }
  }

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
            border: Border.all(color: const Color(0xFF7B5CF6).withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize:       MainAxisSize.min,
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
                            style: const TextStyle(
                              color:    Color(0xFF9B8FFF),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: message,
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
              GestureDetector(
                onTap: onChat,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4, height: 4,
                      decoration: const BoxDecoration(
                        color:  Color(0xFF7B5CF6),
                        shape:  BoxShape.circle,
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

extension on Offset {
  Offset clamp(Offset min, Offset max) => Offset(
        dx.clamp(min.dx, max.dx),
        dy.clamp(min.dy, max.dy),
      );
}
