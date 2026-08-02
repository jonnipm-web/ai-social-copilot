import 'package:flutter/material.dart';

import '../models/ive_avatar_state_v2.dart';
import 'ive_avatar_motion_policy.dart';

// ── V2 Animation Controller ───────────────────────────────────────────────────
//
// Manages the ring pulse AnimationController lifecycle for the V2 avatar.
// Must be created in a State that provides a TickerProvider.
// Call dispose() in State.dispose().

class IveAvatarAnimationControllerV2 {
  IveAvatarAnimationControllerV2();

  AnimationController? _ctrl;
  Animation<double>? _animation;
  bool _disposed = false;

  Animation<double> get animation =>
      _animation ?? const AlwaysStoppedAnimation(0.0);
  bool get isActive => _ctrl?.isAnimating ?? false;

  void initialize({
    required TickerProvider vsync,
    required IveAvatarStateV2 state,
    required IveMotionPolicy motionPolicy,
  }) {
    _ctrl?.dispose();
    _disposed = false;

    final config = IveAvatarStateConfigV2.forState(state);
    final duration = IveMotionPolicyResolver.scaleDuration(
      config.animationDuration,
      motionPolicy,
    );

    if (motionPolicy == IveMotionPolicy.staticOnly ||
        duration == Duration.zero) {
      _ctrl = null;
      _animation = const AlwaysStoppedAnimation(0.5);
      return;
    }

    _ctrl = AnimationController(vsync: vsync, duration: duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl!, curve: Curves.easeInOut),
    );

    // Start at mid-point so state transitions feel immediate, not a ramp from zero
    _ctrl!.value = 0.5;

    final shouldLoop = IveMotionPolicyResolver.shouldLoop(motionPolicy);
    if (shouldLoop) {
      _ctrl!.repeat(reverse: true);
    } else {
      _ctrl!.forward();
    }
  }

  void updateState({
    required IveAvatarStateV2 state,
    required IveMotionPolicy motionPolicy,
    required TickerProvider vsync,
  }) {
    if (_disposed) return;
    initialize(vsync: vsync, state: state, motionPolicy: motionPolicy);
  }

  void pause() {
    if (_disposed) return;
    _ctrl?.stop();
  }

  void resume() {
    if (_disposed) return;
    _ctrl?.repeat(reverse: true);
  }

  void dispose() {
    _disposed = true;
    _ctrl?.dispose();
    _ctrl = null;
    _animation = null;
  }
}
