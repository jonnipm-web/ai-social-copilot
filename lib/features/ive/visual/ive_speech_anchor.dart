import 'package:flutter/material.dart';

// ── Speech Anchor ─────────────────────────────────────────────────────────────
// Positions the speech bubble relative to the avatar.
// Placed here so the overlay can compose: IveAvatar + IveSpeechAnchor.

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
