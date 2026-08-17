import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animations/ive_avatar_animation_controller.dart';
import '../animations/ive_avatar_motion_policy.dart';
import '../models/ive_avatar_configuration.dart';
import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';
import '../providers/ive_avatar_provider_v2.dart';
import '../theme/ive_avatar_theme.dart';
import '../theme/ive_avatar_tokens.dart';
import 'ive_avatar_semantic_wrapper.dart';
import 'ive_avatar_status_indicator.dart';
import '_ive_avatar_face.dart';

// ── IveAvatarV2 — Full / Primary V2 widget ────────────────────────────────────
//
// Self-reads iveAvatarV2StateProvider (Riverpod).
// Accepts explicit state override for showcase/preview scenarios.
//
// Supports four display modes via IveAvatarConfiguration:
//   compact, assistantButton, card, full (this widget renders full).
//
// The feature flag (iveAvatarV2EnabledProvider) must be true for this
// widget to be displayed in production routes. The showcase bypasses the flag.

class IveAvatarV2 extends ConsumerStatefulWidget {
  final IveAvatarStateV2? overrideState;
  final IveAvatarContext? overrideContext;
  final IveAvatarConfiguration configuration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IveAvatarV2({
    super.key,
    this.overrideState,
    this.overrideContext,
    this.configuration = IveAvatarConfiguration.full,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<IveAvatarV2> createState() => _IveAvatarV2State();
}

class _IveAvatarV2State extends ConsumerState<IveAvatarV2>
    with TickerProviderStateMixin {
  final _animCtrl = IveAvatarAnimationControllerV2();
  IveAvatarStateV2 _lastState = IveAvatarStateV2.idle;

  @override
  void initState() {
    super.initState();
    final state = widget.overrideState ?? IveAvatarStateV2.idle;
    _lastState = state;
    _animCtrl.initialize(
      vsync: this,
      state: state,
      motionPolicy: IveMotionPolicy.fullMotion,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _maybeUpdateAnim(IveAvatarStateV2 current) {
    if (current == _lastState) return;
    _lastState = current;
    final policy = IveMotionPolicyResolver.resolve(context);
    _animCtrl.updateState(state: current, motionPolicy: policy, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(iveAvatarV2StateProvider);
    final avatarState = widget.overrideState ?? providerState;

    _maybeUpdateAnim(avatarState);

    final policy = IveMotionPolicyResolver.resolve(context);
    final size = widget.configuration.size;
    final config = IveAvatarStateConfigV2.forState(avatarState);
    final theme = IveAvatarTheme.forState(avatarState);

    Widget avatar = RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: widget.configuration.showStatusRing
            ? Stack(
                alignment: Alignment.center,
                children: [
                  IveAvatarStatusIndicator(
                    state: avatarState,
                    size: size,
                    motionPolicy: policy,
                    animation: _animCtrl.animation,
                  ),
                  Padding(
                    padding:
                        EdgeInsets.all(size * IveAvatarTokens.ringGapRatio),
                    child: ClipOval(
                      child: IveAvatarFacePlaceholder(
                        state: avatarState,
                        size: size,
                      ),
                    ),
                  ),
                ],
              )
            : ClipOval(
                child: IveAvatarFacePlaceholder(
                  state: avatarState,
                  size: size,
                ),
              ),
      ),
    );

    // Label below avatar in full mode
    if (widget.configuration.showLabel) {
      avatar = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: IveAvatarTokens.stateChangeFade,
            child: Text(
              config.fallbackLabel,
              key: ValueKey(avatarState),
              style: theme.labelStyle.copyWith(
                fontSize: IveAvatarTokens.labelFontSizeMedium,
              ),
            ),
          ),
        ],
      );
    }

    // Disabled dimming
    avatar = AnimatedOpacity(
      opacity: avatarState == IveAvatarStateV2.disabled
          ? IveAvatarTokens.disabledOpacity
          : 1.0,
      duration: IveAvatarTokens.transitionDuration,
      child: avatar,
    );

    if (!widget.configuration.interactive) return avatar;

    return IveAvatarSemanticWrapper(
      state: avatarState,
      interactive: true,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: avatar,
    );
  }
}
