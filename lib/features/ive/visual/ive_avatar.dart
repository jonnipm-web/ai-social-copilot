import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import '../../../providers/ive_provider.dart';
import 'ive_avatar_controller.dart';
import 'ive_avatar_state.dart';
import 'ive_status_ring.dart';
import 'ive_visual_config.dart';
import 'ive_visual_fallback.dart';

export 'ive_avatar_state.dart' show IveVisualState;
export 'ive_visual_config.dart' show IveAvatarSize;

// ── IveAvatar — main character widget ────────────────────────────────────────
//
// Usage:
//   IveAvatar(
//     size:           IveAvatarSize.compact,
//     showStatusRing: true,
//     interactive:    true,
//     onTap:          openIveChat,
//   )
//
// The widget auto-watches iveProvider and maps IveState → IveVisualState.
// It attempts to load the Rive runtime on init; if the .riv asset is missing
// it automatically renders IveVisualFallback (reference image + ring).

class IveAvatar extends ConsumerStatefulWidget {
  final IveAvatarSize size;
  final bool showStatusRing;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IveAvatar({
    super.key,
    this.size = IveAvatarSize.standard,
    this.showStatusRing = true,
    this.interactive = true,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<IveAvatar> createState() => _IveAvatarState();
}

class _IveAvatarState extends ConsumerState<IveAvatar>
    with SingleTickerProviderStateMixin {
  final _controller = IveAvatarController();
  bool _initialized = false;

  // Ring pulse animation (used even when Rive is active for the outer ring)
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _tryLoadRive();
  }

  Future<void> _tryLoadRive() async {
    final loaded = await _controller.initializeRive();
    if (mounted) setState(() => _initialized = true);
    if (!mounted) return;
    if (!loaded) {
      // Rive unavailable — fallback active, nothing else needed.
      return;
    }
    // Apply current IVE state once Rive is ready
    final iveState = ref.read(iveProvider);
    _controller.applyVisualState(IveVisualStateMapper.fromIveState(iveState));
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iveState = ref.watch(iveProvider);
    final visualState = IveVisualStateMapper.fromIveState(iveState);

    // Propagate state changes to the Rive runtime
    if (_initialized) {
      _controller.applyVisualState(visualState);
    }

    final dp = widget.size.dp;

    Widget avatar;

    if (_controller.isRiveReady) {
      // ── Rive path ────────────────────────────────────────────────────────
      avatar = _RiveAvatar(
        controller: _controller,
        size: dp,
        state: visualState,
        pulse: _pulse,
        showRing: widget.showStatusRing,
      );
    } else {
      // ── Fallback path ─────────────────────────────────────────────────────
      avatar = IveVisualFallback(
        state: visualState,
        size: dp,
      );
    }

    if (!widget.interactive) return avatar;

    return Semantics(
      label: 'IVE, assistente executiva',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ExcludeSemantics(child: avatar),
      ),
    );
  }
}

// ── Rive display sub-widget ───────────────────────────────────────────────────

class _RiveAvatar extends StatelessWidget {
  const _RiveAvatar({
    required this.controller,
    required this.size,
    required this.state,
    required this.pulse,
    required this.showRing,
  });

  final IveAvatarController controller;
  final double size;
  final IveVisualState state;
  final Animation<double> pulse;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => SizedBox(
        width: size,
        height: size,
        child: showRing
            ? CustomPaint(
                painter: IveStatusRingPainter(
                  state: state,
                  glowPulse: pulse.value,
                ),
                child: Padding(
                  padding: EdgeInsets.all(size * 0.055),
                  child: ClipOval(child: _riveWidget),
                ),
              )
            : ClipOval(child: _riveWidget),
      ),
    );
  }

  Widget get _riveWidget {
    final artboard = controller.riveRuntime?.artboard;
    if (artboard == null) return const SizedBox.shrink();
    return Rive(
      artboard: artboard,
      fit: BoxFit.contain,
      useArtboardSize: false,
    );
  }
}
