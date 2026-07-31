import 'package:flutter/material.dart';

import '../animations/ive_avatar_animation_controller.dart';
import '../animations/ive_avatar_motion_policy.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';
import 'ive_avatar_semantic_wrapper.dart';
import 'ive_avatar_status_indicator.dart';
import '_ive_avatar_face.dart';

// ── IveAvatarAssistantButton ──────────────────────────────────────────────────
//
// Floating assistant button — safe replacement for the current floating avatar.
// Guards: not shown before auth, not shown on hidden routes (caller responsible).
// Uses RepaintBoundary to prevent list/dashboard repaints.

class IveAvatarAssistantButton extends StatefulWidget {
  final IveAvatarStateV2 state;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool hasNotification;
  final double size;
  final EdgeInsetsGeometry margin;

  const IveAvatarAssistantButton({
    super.key,
    required this.state,
    this.onTap,
    this.onLongPress,
    this.hasNotification = false,
    this.size = IveAvatarTokens.assistantButtonSize,
    this.margin = const EdgeInsets.only(bottom: 16, right: 16),
  });

  @override
  State<IveAvatarAssistantButton> createState() =>
      _IveAvatarAssistantButtonState();
}

class _IveAvatarAssistantButtonState extends State<IveAvatarAssistantButton>
    with TickerProviderStateMixin {
  final _animCtrl = IveAvatarAnimationControllerV2();

  @override
  void initState() {
    super.initState();
    _animCtrl.initialize(
      vsync: this,
      state: widget.state,
      motionPolicy: IveMotionPolicy.fullMotion,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = IveMotionPolicyResolver.resolve(context);
    _animCtrl.updateState(
      state: widget.state,
      motionPolicy: policy,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(IveAvatarAssistantButton old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      final policy = IveMotionPolicyResolver.resolve(context);
      _animCtrl.updateState(
        state: widget.state,
        motionPolicy: policy,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policy = IveMotionPolicyResolver.resolve(context);

    return Padding(
      padding: widget.margin,
      child: RepaintBoundary(
        child: IveAvatarSemanticWrapper(
          state: widget.state,
          interactive: true,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedOpacity(
            opacity: widget.state == IveAvatarStateV2.disabled
                ? IveAvatarTokens.disabledOpacity
                : 1.0,
            duration: IveAvatarTokens.transitionDuration,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Status ring
                SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IveAvatarStatusIndicator(
                        state: widget.state,
                        size: widget.size,
                        motionPolicy: policy,
                        animation: _animCtrl.animation,
                      ),
                      Padding(
                        padding: EdgeInsets.all(
                          widget.size * IveAvatarTokens.ringGapRatio,
                        ),
                        child: ClipOval(
                          child: IveAvatarFacePlaceholder(
                            state: widget.state,
                            size: widget.size,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification dot
                if (widget.hasNotification)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _NotificationDot(
                      color: IveAvatarStateConfigV2.forState(widget.state)
                          .ringColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationDot extends StatelessWidget {
  final Color color;
  const _NotificationDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: IveAvatarTokens.backgroundDark, width: 1.5),
      ),
    );
  }
}
