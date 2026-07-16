import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'ive_avatar_state.dart';

// ── Status Ring Painter ───────────────────────────────────────────────────────
// Draws ONLY the outer ring + glow. No face elements.
// Used by both the Rive integration and the fallback.

class IveStatusRingPainter extends CustomPainter {
  final IveVisualState state;
  final double         glowPulse;   // 0.0–1.0, animated externally
  final double         strokeWidth;

  const IveStatusRingPainter({
    required this.state,
    required this.glowPulse,
    this.strokeWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final config  = IveVisualStateConfig.forState(state);
    final center  = Offset(size.width / 2, size.height / 2);
    final radius  = (size.width / 2) - (strokeWidth / 2) - 0.5;
    final color   = config.ringColor;
    final intensity = config.glowIntensity * (0.7 + glowPulse * 0.3);

    // Outer ambient glow (wide, soft)
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color       = color.withOpacity(0.18 * intensity)
        ..maskFilter  = MaskFilter.blur(BlurStyle.normal, 12 * intensity),
    );

    // Inner glow (tighter, brighter)
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color       = color.withOpacity(0.30 * intensity)
        ..maskFilter  = MaskFilter.blur(BlurStyle.normal, 5 * intensity),
    );

    // Solid ring stroke
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color       = color.withOpacity(0.85)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Small cardinal tick marks (4 points at 0°, 90°, 180°, 270°)
    final tickPaint = Paint()
      ..color       = color.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap   = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle  = i * math.pi / 2;
      final outer  = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner  = Offset(
        center.dx + (radius - 6) * math.cos(angle),
        center.dy + (radius - 6) * math.sin(angle),
      );
      canvas.drawLine(outer, inner, tickPaint);
    }
  }

  @override
  bool shouldRepaint(IveStatusRingPainter old) =>
      old.state      != state      ||
      old.glowPulse  != glowPulse  ||
      old.strokeWidth != strokeWidth;
}
