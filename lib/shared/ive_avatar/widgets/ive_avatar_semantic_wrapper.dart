import 'package:flutter/material.dart';

import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';

// ── IveAvatarSemanticWrapper ──────────────────────────────────────────────────
//
// Wraps any avatar widget with correct accessibility semantics.
// Uses state-specific labels so screen readers announce the current IVE status.

class IveAvatarSemanticWrapper extends StatelessWidget {
  final Widget           child;
  final IveAvatarStateV2 state;
  final bool             interactive;
  final VoidCallback?    onTap;
  final VoidCallback?    onLongPress;
  final String?          overrideLabel;

  const IveAvatarSemanticWrapper({
    super.key,
    required this.child,
    required this.state,
    this.interactive  = true,
    this.onTap,
    this.onLongPress,
    this.overrideLabel,
  });

  String get _label {
    if (overrideLabel != null) return overrideLabel!;
    return IveAvatarStateConfigV2.forState(state).semanticLabel;
  }

  @override
  Widget build(BuildContext context) {
    Widget widget = Semantics(
      label:   _label,
      button:  interactive && onTap != null,
      enabled: state != IveAvatarStateV2.disabled,
      tooltip: interactive ? 'Abrir assistente IVE' : null,
      child:   child,
    );

    if (!interactive || (onTap == null && onLongPress == null)) {
      return widget;
    }

    return GestureDetector(
      onTap:      onTap,
      onLongPress: onLongPress,
      behavior:   HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth:  IveAvatarTokens.minTouchTarget,
          minHeight: IveAvatarTokens.minTouchTarget,
        ),
        child: widget,
      ),
    );
  }
}
