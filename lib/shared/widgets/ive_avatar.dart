import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../data/models/ive_state.dart';

class IveAvatarWidget extends StatefulWidget {
  final IveExpression expression;
  final double size;

  const IveAvatarWidget({
    super.key,
    required this.expression,
    this.size = 60,
  });

  @override
  State<IveAvatarWidget> createState() => _IveAvatarWidgetState();
}

class _IveAvatarWidgetState extends State<IveAvatarWidget>
    with TickerProviderStateMixin {
  late final AnimationController _blinkCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _waveCtrl;

  late final Animation<double> _blink;
  late final Animation<double> _float;
  late final Animation<double> _wave;

  bool _eyesOpen = true;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _wave = Tween<double>(begin: 0, end: 0.3).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.elasticOut),
    );
    _waveCtrl.forward();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _blink = Tween<double>(begin: 1, end: 0.05).animate(_blinkCtrl);
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    await Future.delayed(
      Duration(milliseconds: 3000 + math.Random().nextInt(2000)),
    );
    if (!mounted) return;
    await _blinkCtrl.forward();
    await _blinkCtrl.reverse();
    _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _floatCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _wave]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _float.value),
        child: Transform.rotate(
          angle: math.sin(_wave.value * math.pi) * 0.08,
          child: AnimatedBuilder(
            animation: _blink,
            builder: (_, __) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _IveAvatarPainter(
                expression: widget.expression,
                eyeScale:   _blink.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _IveAvatarPainter extends CustomPainter {
  final IveExpression expression;
  final double eyeScale;

  const _IveAvatarPainter({
    required this.expression,
    required this.eyeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // ── Background glow ──────────────────────────────────────────────────────
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = const Color(0xFF6C63FF).withOpacity(0.35);
    canvas.drawCircle(c, r + 3, glowPaint);

    // ── Face circle ──────────────────────────────────────────────────────────
    final facePaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF9B8FFF), const Color(0xFF4B3DCC)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, facePaint);

    // ── Border ───────────────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r - 1, borderPaint);

    final s = size.width;

    // ── Eyes ─────────────────────────────────────────────────────────────────
    _drawEyes(canvas, s, c);

    // ── Mouth ─────────────────────────────────────────────────────────────────
    _drawMouth(canvas, s, c);

    // ── Cheeks ───────────────────────────────────────────────────────────────
    if (expression == IveExpression.excited || expression == IveExpression.happy) {
      final cheekPaint = Paint()
        ..color = Colors.pink.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx - s * 0.23, c.dy + s * 0.08), width: s * 0.18, height: s * 0.12),
        cheekPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx + s * 0.23, c.dy + s * 0.08), width: s * 0.18, height: s * 0.12),
        cheekPaint,
      );
    }
  }

  void _drawEyes(Canvas canvas, double s, Offset c) {
    final whitePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1A1635);
    final eyeH = s * 0.12 * eyeScale;

    if (expression == IveExpression.winking) {
      // Left eye — normal
      canvas.drawOval(
        Rect.fromCenter(center: Offset(c.dx - s * 0.17, c.dy - s * 0.08),
            width: s * 0.14, height: s * 0.14 * eyeScale),
        whitePaint,
      );
      canvas.drawCircle(Offset(c.dx - s * 0.15, c.dy - s * 0.08), s * 0.055, pupilPaint);
      // Right eye — wink line
      final winkPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = s * 0.04
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(c.dx + s * 0.10, c.dy - s * 0.07),
        Offset(c.dx + s * 0.24, c.dy - s * 0.09),
        winkPaint,
      );
    } else {
      // Both eyes normal
      for (final xOffset in [-0.17, 0.17]) {
        final eyeC = Offset(c.dx + s * xOffset, c.dy - s * 0.08);
        canvas.drawOval(
          Rect.fromCenter(center: eyeC, width: s * 0.14, height: s * 0.14 * eyeScale),
          whitePaint,
        );
        if (eyeScale > 0.1) {
          canvas.drawCircle(
            Offset(eyeC.dx + s * 0.015, eyeC.dy),
            s * 0.055,
            pupilPaint,
          );
          // Shine
          canvas.drawCircle(
            Offset(eyeC.dx + s * 0.02, eyeC.dy - s * 0.025),
            s * 0.018,
            Paint()..color = Colors.white,
          );
        }
      }
      if (expression == IveExpression.thinking) {
        // Raised left eyebrow
        final browPaint = Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..strokeWidth = s * 0.03
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(c.dx - s * 0.25, c.dy - s * 0.22),
          Offset(c.dx - s * 0.09, c.dy - s * 0.25),
          browPaint,
        );
      }
    }
  }

  void _drawMouth(Canvas canvas, double s, Offset c) {
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;

    final mY = c.dy + s * 0.14;
    final mX = c.dx;

    switch (expression) {
      case IveExpression.happy:
      case IveExpression.excited:
        final rect = Rect.fromCenter(
          center: Offset(mX, mY - s * 0.04),
          width: s * 0.38,
          height: s * 0.22,
        );
        canvas.drawArc(rect, 0, math.pi, false, mouthPaint);
        break;

      case IveExpression.winking:
        final rect = Rect.fromCenter(
          center: Offset(mX, mY - s * 0.03),
          width: s * 0.30,
          height: s * 0.16,
        );
        canvas.drawArc(rect, 0, math.pi, false, mouthPaint);
        break;

      case IveExpression.thinking:
        // Slightly curved / wavy thinking mouth
        final path = Path()
          ..moveTo(mX - s * 0.13, mY)
          ..quadraticBezierTo(mX - s * 0.04, mY + s * 0.04, mX, mY)
          ..quadraticBezierTo(mX + s * 0.04, mY - s * 0.04, mX + s * 0.13, mY);
        canvas.drawPath(path, mouthPaint);
        break;

      case IveExpression.neutral:
        canvas.drawLine(
          Offset(mX - s * 0.12, mY),
          Offset(mX + s * 0.12, mY),
          mouthPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(_IveAvatarPainter old) =>
      old.expression != expression || old.eyeScale != eyeScale;
}
