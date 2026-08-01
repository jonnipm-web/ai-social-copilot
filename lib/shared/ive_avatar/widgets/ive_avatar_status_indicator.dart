import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../animations/ive_avatar_motion_policy.dart';
import '../models/ive_avatar_state_v2.dart';
import '../theme/ive_avatar_tokens.dart';

// ── V2 Status Ring Painter ────────────────────────────────────────────────────

class IveAvatarStatusRingV2 extends CustomPainter {
  final IveAvatarStateV2 state;
  final double glowPulse;
  final double strokeWidth;
  final IveMotionPolicy motionPolicy;

  const IveAvatarStatusRingV2({
    required this.state,
    required this.glowPulse,
    this.strokeWidth = IveAvatarTokens.ringStrokeWidth,
    this.motionPolicy = IveMotionPolicy.fullMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final config = IveAvatarStateConfigV2.forState(state);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2) - 0.5;
    final color = config.ringColor;
    final intensity = IveMotionPolicyResolver.scaleIntensity(
      config.glowIntensity * (0.7 + glowPulse * 0.3),
      motionPolicy,
    );

    // Outer ambient glow
    canvas.drawCircle(
      center,
      radius + 4,
      Paint()
        ..color = color.withValues(alpha: 0.18 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * intensity),
    );

    // Inner tight glow
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.30 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * intensity),
    );

    // Solid ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Cardinal tick marks
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      canvas.drawLine(outer, inner, tickPaint);
    }
  }

  @override
  bool shouldRepaint(IveAvatarStatusRingV2 old) =>
      old.state != state ||
      old.glowPulse != glowPulse ||
      old.strokeWidth != strokeWidth ||
      old.motionPolicy != motionPolicy;
}

// ── Status indicator widget ───────────────────────────────────────────────────

class IveAvatarStatusIndicator extends StatelessWidget {
  final IveAvatarStateV2 state;
  final double size;
  final IveMotionPolicy motionPolicy;
  final Animation<double>? animation;

  const IveAvatarStatusIndicator({
    super.key,
    required this.state,
    required this.size,
    this.motionPolicy = IveMotionPolicy.fullMotion,
    this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final anim = animation ?? const AlwaysStoppedAnimation(0.5);

    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => CustomPaint(
        size: Size(size, size),
        painter: IveAvatarStatusRingV2(
          state: state,
          glowPulse: anim.value,
          motionPolicy: motionPolicy,
        ),
      ),
    );
  }
}
