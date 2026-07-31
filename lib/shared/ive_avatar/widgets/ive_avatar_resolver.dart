import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/context_copilot_widget.dart'
    show showCopilotChat;
import '../../../shared/widgets/ive_overlay.dart'
    show IveOverlay, iveRouteNotifier;
import '../models/ive_avatar_configuration.dart';
import '../models/ive_avatar_state_v2.dart';
import '../providers/effective_avatar_version_provider.dart';
import '../providers/ive_avatar_provider_v2.dart';
import '../providers/ive_operational_state_provider.dart';
import '../theme/ive_avatar_tokens.dart';
import 'ive_avatar_v2.dart';

export '../providers/effective_avatar_version_provider.dart'
    show
        IveAvatarVersion,
        IveAvatarLocalOverride,
        iveIsHiddenRoute,
        iveIsAuthenticated;

// ── IveAvatarResolver ─────────────────────────────────────────────────────────
//
// Single global render point. Mounted in app.dart's Stack.
//
// Watches effectiveIveAvatarVersionProvider and renders:
//   legacy → IveOverlay  (draggable legacy widget — unmodified)
//   v2     → _IveOverlayV2 (V2 wrapper, same drag behaviour)
//   hidden → SizedBox.shrink()
//
// Route/auth hiding is handled here. IveOverlay itself still contains its
// own internal route listener (for IveState.screenName) — that is additive,
// not conflicting, because IveAvatarResolver prevents IveOverlay from
// mounting on hidden routes in the first place.

class IveAvatarResolver extends ConsumerStatefulWidget {
  const IveAvatarResolver({super.key});

  @override
  ConsumerState<IveAvatarResolver> createState() => _IveAvatarResolverState();
}

class _IveAvatarResolverState extends ConsumerState<IveAvatarResolver> {
  String _route = '';
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    iveRouteNotifier.addListener(_onRouteChange);
    _route = iveRouteNotifier.value;
    _authenticated = iveIsAuthenticated();
  }

  @override
  void dispose() {
    iveRouteNotifier.removeListener(_onRouteChange);
    super.dispose();
  }

  void _onRouteChange() {
    final route = iveRouteNotifier.value;
    final auth = iveIsAuthenticated();
    if (route == _route && auth == _authenticated) return;
    setState(() {
      _route = route;
      _authenticated = auth;
    });
  }

  bool get _shouldHide => !_authenticated || iveIsHiddenRoute(_route);

  @override
  Widget build(BuildContext context) {
    if (_shouldHide) return const SizedBox.shrink();

    final version = ref.watch(effectiveIveAvatarVersionProvider);

    // Keep V2 operational state in sync even when rendering legacy,
    // so switching is instantaneous.
    final opState = ref.watch(iveOperationalStateProvider);
    ref.read(iveAvatarV2Provider.notifier).updateAvatarState(opState);

    switch (version) {
      case IveAvatarVersion.hidden:
        return const SizedBox.shrink();
      case IveAvatarVersion.legacy:
        return const IveOverlay();
      case IveAvatarVersion.v2:
        return _IveOverlayV2(operationalState: opState, route: _route);
    }
  }
}

// ── _IveOverlayV2 ─────────────────────────────────────────────────────────────
//
// Draggable V2 avatar overlay. Mirrors IveOverlay drag behaviour.

class _IveOverlayV2 extends StatefulWidget {
  const _IveOverlayV2({required this.operationalState, required this.route});
  final IveAvatarStateV2 operationalState;
  final String route;

  @override
  State<_IveOverlayV2> createState() => _IveOverlayV2State();
}

class _IveOverlayV2State extends State<_IveOverlayV2> {
  Offset? _position;
  bool _dragging = false;

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  Offset _defaultPosition(Size screen) {
    if (_isDesktop) return Offset(screen.width - 96, screen.height - 220);
    return Offset(screen.width - 88, screen.height - 200);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    _position ??= _defaultPosition(screen);

    final maxY = screen.height - 104 - safeBottom;

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => setState(() {
          _position = (_position! + d.delta).clamp(
            Offset.zero,
            Offset(screen.width - 80, maxY),
          );
        }),
        onPanEnd: (_) => setState(() => _dragging = false),
        onTap: _dragging ? null : _handleTap,
        child: AnimatedScale(
          scale: _dragging ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: IveAvatarV2(
            configuration: const IveAvatarConfiguration(
              displayMode: IveAvatarDisplayMode.compact,
              size: IveAvatarTokens.sizeSmall,
              showStatusRing: true,
              showLabel: false,
              interactive: false, // overlay owns the gesture
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (!mounted || _dragging) return;
    showCopilotChat(context, screenName: _routeToName(widget.route));
  }
}

// ── Route → display name ──────────────────────────────────────────────────────

String _routeToName(String route) {
  const map = <String, String>{
    '/projects': 'Projetos',
    '/opportunity-lab': 'Oportunidades',
    '/ecosystem': 'Decisões',
    '/ecosystem/briefing': 'Briefing',
    '/ecosystem/resources': 'Recursos',
    '/personas': 'Personas',
    '/knowledge': 'Conhecimento',
    '/action-engine': 'Ações',
    '/intelligence-debug': 'Debug Hub',
    '/market-intelligence': 'Inteligência de Mercado',
    '/roi-tracker': 'ROI Tracker',
    '/dashboard': 'Business OS',
    '/executive-dashboard': 'Dashboard Executivo',
    '/generate': 'Geração',
    '/content': 'Conteúdo',
    '/campaigns': 'Campanhas',
    '/calendar': 'Calendário',
    '/performance': 'Performance',
  };
  return map[route] ?? route;
}

extension on Offset {
  Offset clamp(Offset min, Offset max) =>
      Offset(dx.clamp(min.dx, max.dx), dy.clamp(min.dy, max.dy));
}
