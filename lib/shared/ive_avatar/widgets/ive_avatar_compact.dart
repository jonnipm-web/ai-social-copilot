import 'package:flutter/material.dart';

import '../animations/ive_avatar_animation_controller.dart';
import '../animations/ive_avatar_motion_policy.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';
import 'ive_avatar_semantic_wrapper.dart';
import 'ive_avatar_status_indicator.dart';
import '_ive_avatar_face.dart';

// ── IveAvatarCompact ──────────────────────────────────────────────────────────
//
// Compact presentation: AppBar, cards, list tiles, status badges.
// Uses RepaintBoundary to isolate repaints.

class IveAvatarCompact extends StatefulWidget {
  final IveAvatarStateV2 state;
  final double           size;
  final bool             showRing;
  final bool             interactive;
  final VoidCallback?    onTap;
  final VoidCallback?    onLongPress;
  final String?          overrideSemanticLabel;

  const IveAvatarCompact({
    super.key,
    required this.state,
    this.size                  = IveAvatarTokens.sizeSmall,
    this.showRing              = true,
    this.interactive           = true,
    this.onTap,
    this.onLongPress,
    this.overrideSemanticLabel,
  });

  @override
  State<IveAvatarCompact> createState() => _IveAvatarCompactState();
}

class _IveAvatarCompactState extends State<IveAvatarCompact>
    with SingleTickerProviderStateMixin {
  final _animCtrl = IveAvatarAnimationControllerV2();

  @override
  void initState() {
    super.initState();
    // Use fullMotion as default — actual policy is read in didChangeDependencies
    _animCtrl.initialize(
      vsync:        this,
      state:        widget.state,
      motionPolicy: IveMotionPolicy.fullMotion,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final policy = IveMotionPolicyResolver.resolve(context);
    _animCtrl.updateState(
      state:        widget.state,
      motionPolicy: policy,
      vsync:        this,
    );
  }

  @override
  void didUpdateWidget(IveAvatarCompact old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _animCtrl.updateState(
        state:        widget.state,
        motionPolicy: IveMotionPolicyResolver.resolve(context),
        vsync:        this,
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

    final face = RepaintBoundary(
      child: SizedBox(
        width:  widget.size,
        height: widget.size,
        child: widget.showRing
            ? Stack(
                alignment: Alignment.center,
                children: [
                  IveAvatarStatusIndicator(
                    state:       widget.state,
                    size:        widget.size,
                    motionPolicy: policy,
                    animation:   _animCtrl.animation,
                  ),
                  Padding(
                    padding: EdgeInsets.all(widget.size * IveAvatarTokens.ringGapRatio),
                    child: ClipOval(
                      child: IveAvatarFacePlaceholder(
                        state: widget.state,
                        size:  widget.size,
                      ),
                    ),
                  ),
                ],
              )
            : ClipOval(
                child: IveAvatarFacePlaceholder(
                  state: widget.state,
                  size:  widget.size,
                ),
              ),
      ),
    );

    return IveAvatarSemanticWrapper(
      state:         widget.state,
      interactive:   widget.interactive,
      onTap:         widget.onTap,
      onLongPress:   widget.onLongPress,
      overrideLabel: widget.overrideSemanticLabel,
      child: AnimatedOpacity(
        opacity:  widget.state == IveAvatarStateV2.disabled
            ? IveAvatarTokens.disabledOpacity
            : 1.0,
        duration: IveAvatarTokens.transitionDuration,
        child: face,
      ),
    );
  }
}
