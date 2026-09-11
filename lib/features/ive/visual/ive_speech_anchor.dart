import 'package:flutter/material.dart';

// ── Speech Anchor ─────────────────────────────────────────────────────────────
// Positions the speech bubble relative to the avatar.
// Placed here so the overlay can compose: IveAvatar + IveSpeechAnchor.
//
// STATUS (IVE-AVATAR-STATE-MACHINE-02 audit): still unwired — IveOverlay
// composes its speech bubble with a plain Column, not this widget. Left in
// place rather than removed: it's a small, self-contained positioning
// helper with no dependency on the interaction-state work done in this
// mission, and no evidence it's dead by mistake vs. dead by not-yet-adopted.
// Wire it in (or delete it) the next time IveOverlay's bubble layout is
// touched, rather than as a side effect of an unrelated mission.

class IveSpeechAnchor extends StatelessWidget {
  const IveSpeechAnchor({
    super.key,
    required this.avatarSize,
    required this.child,
    this.alignment = IveSpeechAlignment.topLeft,
  });

  final double             avatarSize;
  final Widget             child;
  final IveSpeechAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: child,
    );
  }
}

enum IveSpeechAlignment { topLeft, topRight, bottomLeft, bottomRight }
