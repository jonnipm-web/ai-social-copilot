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
  late final AnimationController _entryCtrl;

  late final Animation<double> _blink;
  late final Animation<double> _float;
  late final Animation<double> _entry;

  @override
  void initState() {
    super.initState();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entry = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut),
    );
    _entryCtrl.forward();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _blink = Tween<double>(begin: 1, end: 0.06).animate(_blinkCtrl);
    _scheduleBlink();
  }

  void _scheduleBlink() async {
    await Future.delayed(
      Duration(milliseconds: 3200 + math.Random().nextInt(2400)),
    );
    if (!mounted) return;
    await _blinkCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;
    await _blinkCtrl.reverse();
    _scheduleBlink();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _floatCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _entry, _blink]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _float.value),
        child: Transform.scale(
          scale: _entry.value,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _IveExecutivePainter(
              expression: widget.expression,
              eyeScale:   _blink.value,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _IveExecutivePainter extends CustomPainter {
  final IveExpression expression;
  final double eyeScale;

  const _IveExecutivePainter({
    required this.expression,
    required this.eyeScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s * 0.5, s * 0.5);
    final r = s * 0.5;

    // Outer glow
    canvas.drawCircle(
      c, r + 3,
      Paint()
        ..color = const Color(0xFF6C63FF).withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Clip all drawing to circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - 0.5)));

    // Background
    canvas.drawCircle(
      c, r,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF1E1A38), const Color(0xFF0C0A1A)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Suit / collar (bottom portion)
    _drawCollar(canvas, s, c);

    // Hair back layer
    _drawHairBack(canvas, s, c);

    // Neck
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + s * 0.22),
        width: s * 0.13, height: s * 0.16,
      ),
      Paint()..color = const Color(0xFFEFBF89),
    );

    // Face oval
    _drawFace(canvas, s, c);

    // Hair front (sides framing face)
    _drawHairFront(canvas, s, c);

    // Eyes
    _drawEyes(canvas, s, c);

    // Eyebrows
    _drawEyebrows(canvas, s, c);

    // Nose hint
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy + s * 0.01),
        width: s * 0.04, height: s * 0.025,
      ),
      Paint()..color = const Color(0xFFCC9060).withOpacity(0.35),
    );

    // Lips
    _drawLips(canvas, s, c);

    // Forehead highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - s * 0.03, c.dy - s * 0.18),
        width: s * 0.14, height: s * 0.08,
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();

    // Tech ring frame on top
    canvas.drawCircle(
      c, r - 1.0,
      Paint()
        ..color = const Color(0xFF6C63FF).withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028,
    );

    // Corner accent dots
    final dotPaint = Paint()..color = const Color(0xFF9B8FFF);
    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) + math.pi / 4;
      canvas.drawCircle(
        Offset(c.dx + (r - 1) * math.cos(angle), c.dy + (r - 1) * math.sin(angle)),
        s * 0.022,
        dotPaint,
      );
    }
  }

  // ── Collar / suit ────────────────────────────────────────────────────────────
  void _drawCollar(Canvas canvas, double s, Offset c) {
    // Suit body
    final suit = Paint()..color = const Color(0xFF10142A);
    final suitPath = Path()
      ..moveTo(c.dx - s * 0.50, c.dy + s * 0.16)
      ..lineTo(c.dx - s * 0.24, c.dy + s * 0.34)
      ..lineTo(c.dx - s * 0.07, c.dy + s * 0.22)
      ..lineTo(c.dx, c.dy + s * 0.30)
      ..lineTo(c.dx + s * 0.07, c.dy + s * 0.22)
      ..lineTo(c.dx + s * 0.24, c.dy + s * 0.34)
      ..lineTo(c.dx + s * 0.50, c.dy + s * 0.16)
      ..lineTo(c.dx + s * 0.50, c.dy + s * 0.50)
      ..lineTo(c.dx - s * 0.50, c.dy + s * 0.50)
      ..close();
    canvas.drawPath(suitPath, suit);

    // Shirt / blouse (V inner)
    final shirt = Paint()..color = const Color(0xFFE8EAFF).withOpacity(0.85);
    final shirtPath = Path()
      ..moveTo(c.dx - s * 0.07, c.dy + s * 0.20)
      ..lineTo(c.dx, c.dy + s * 0.30)
      ..lineTo(c.dx + s * 0.07, c.dy + s * 0.20)
      ..lineTo(c.dx + s * 0.04, c.dy + s * 0.16)
      ..lineTo(c.dx - s * 0.04, c.dy + s * 0.16)
      ..close();
    canvas.drawPath(shirtPath, shirt);
  }

  // ── Hair back ────────────────────────────────────────────────────────────────
  void _drawHairBack(Canvas canvas, double s, Offset c) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy - s * 0.07),
        width:  s * 0.62,
        height: s * 0.68,
      ),
      Paint()..color = const Color(0xFF18100A),
    );
  }

  // ── Face ─────────────────────────────────────────────────────────────────────
  void _drawFace(Canvas canvas, double s, Offset c) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy - s * 0.04),
        width:  s * 0.50,
        height: s * 0.56,
      ),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          colors: [
            const Color(0xFFF8D4A2),
            const Color(0xFFECBF82),
            const Color(0xFFD4A068),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCenter(
          center: Offset(c.dx, c.dy - s * 0.04),
          width:  s * 0.50,
          height: s * 0.56,
        )),
    );
  }

  // ── Hair front ───────────────────────────────────────────────────────────────
  void _drawHairFront(Canvas canvas, double s, Offset c) {
    final hair = Paint()..color = const Color(0xFF18100A);

    // Crown (top cover)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, c.dy - s * 0.29),
        width:  s * 0.54, height: s * 0.24,
      ),
      hair,
    );

    // Left side
    final left = Path()
      ..moveTo(c.dx - s * 0.26, c.dy - s * 0.28)
      ..quadraticBezierTo(c.dx - s * 0.36, c.dy - s * 0.08, c.dx - s * 0.33, c.dy + s * 0.08)
      ..quadraticBezierTo(c.dx - s * 0.28, c.dy + s * 0.18, c.dx - s * 0.20, c.dy + s * 0.20)
      ..quadraticBezierTo(c.dx - s * 0.25, c.dy + s * 0.04, c.dx - s * 0.24, c.dy - s * 0.10)
      ..quadraticBezierTo(c.dx - s * 0.20, c.dy - s * 0.26, c.dx - s * 0.21, c.dy - s * 0.30)
      ..close();
    canvas.drawPath(left, hair);

    // Right side
    final right = Path()
      ..moveTo(c.dx + s * 0.26, c.dy - s * 0.28)
      ..quadraticBezierTo(c.dx + s * 0.36, c.dy - s * 0.08, c.dx + s * 0.33, c.dy + s * 0.08)
      ..quadraticBezierTo(c.dx + s * 0.28, c.dy + s * 0.18, c.dx + s * 0.20, c.dy + s * 0.20)
      ..quadraticBezierTo(c.dx + s * 0.25, c.dy + s * 0.04, c.dx + s * 0.24, c.dy - s * 0.10)
      ..quadraticBezierTo(c.dx + s * 0.20, c.dy - s * 0.26, c.dx + s * 0.21, c.dy - s * 0.30)
      ..close();
    canvas.drawPath(right, hair);

    // Hair sheen
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx + s * 0.04, c.dy - s * 0.30),
        width: s * 0.18, height: s * 0.09,
      ),
      Paint()
        ..color = const Color(0xFF3A2018).withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // ── Eyes ─────────────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, double s, Offset c) {
    final eyeY   = c.dy - s * 0.08;
    final leftX  = c.dx - s * 0.127;
    final rightX = c.dx + s * 0.127;

    if (expression == IveExpression.winking) {
      _drawAlmondEye(canvas, s, Offset(leftX, eyeY));
      _drawWink(canvas, s, Offset(rightX, eyeY));
    } else {
      _drawAlmondEye(canvas, s, Offset(leftX,  eyeY));
      _drawAlmondEye(canvas, s, Offset(rightX, eyeY));
    }
  }

  void _drawAlmondEye(Canvas canvas, double s, Offset ec) {
    final w = s * 0.115;
    final h = s * 0.052 * eyeScale;

    // White
    final eyePath = _almond(ec, w, h);
    canvas.drawPath(eyePath, Paint()..color = Colors.white);

    if (eyeScale > 0.12) {
      // Pupil
      canvas.drawOval(
        Rect.fromCenter(center: ec, width: w * 0.50, height: h * 1.15),
        Paint()..color = const Color(0xFF0C0A18),
      );
      // Iris ring
      canvas.drawOval(
        Rect.fromCenter(center: ec, width: w * 0.28, height: h * 0.65),
        Paint()..color = const Color(0xFF6C63FF).withOpacity(0.45),
      );
      // Shine
      canvas.drawCircle(
        Offset(ec.dx + w * 0.14, ec.dy - h * 0.28),
        s * 0.011,
        Paint()..color = Colors.white,
      );
      // Lash
      final lash = Paint()
        ..color = const Color(0xFF0C0A18)
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(ec.dx - w * 0.52, ec.dy - h * 0.18)
          ..quadraticBezierTo(ec.dx, ec.dy - h * 1.10, ec.dx + w * 0.52, ec.dy - h * 0.18),
        lash,
      );
    }
  }

  Path _almond(Offset c, double w, double h) => Path()
    ..moveTo(c.dx - w * 0.5, c.dy)
    ..quadraticBezierTo(c.dx - w * 0.18, c.dy - h, c.dx + w * 0.08, c.dy - h * 0.88)
    ..quadraticBezierTo(c.dx + w * 0.32, c.dy - h * 0.65, c.dx + w * 0.5, c.dy)
    ..quadraticBezierTo(c.dx + w * 0.18, c.dy + h * 0.45, c.dx, c.dy + h * 0.38)
    ..quadraticBezierTo(c.dx - w * 0.22, c.dy + h * 0.28, c.dx - w * 0.5, c.dy)
    ..close();

  void _drawWink(Canvas canvas, double s, Offset ec) {
    final w = s * 0.115;
    final paint = Paint()
      ..color = const Color(0xFF0C0A18)
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(ec.dx - w * 0.5, ec.dy)
        ..quadraticBezierTo(ec.dx, ec.dy - s * 0.032, ec.dx + w * 0.5, ec.dy),
      paint,
    );
  }

  // ── Eyebrows ─────────────────────────────────────────────────────────────────
  void _drawEyebrows(Canvas canvas, double s, Offset c) {
    final ey     = c.dy - s * 0.08;
    final paint  = Paint()
      ..color = const Color(0xFF18100A)
      ..strokeWidth = s * 0.024
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final liftL = expression == IveExpression.thinking ? s * 0.035 : 0.0;

    // Left brow
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s * 0.21, ey - s * 0.076 - liftL)
        ..quadraticBezierTo(c.dx - s * 0.12, ey - s * 0.11 - liftL, c.dx - s * 0.04, ey - s * 0.093),
      paint,
    );
    // Right brow
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + s * 0.04, ey - s * 0.093)
        ..quadraticBezierTo(c.dx + s * 0.12, ey - s * 0.11, c.dx + s * 0.21, ey - s * 0.076),
      paint,
    );
  }

  // ── Lips ─────────────────────────────────────────────────────────────────────
  void _drawLips(Canvas canvas, double s, Offset c) {
    final ly = c.dy + s * 0.10;
    final stroke = Paint()
      ..color = const Color(0xFFAA607A)
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (expression) {
      case IveExpression.happy:
      case IveExpression.winking:
        // Upper lip (Cupid bow)
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.10, ly)
            ..quadraticBezierTo(c.dx - s * 0.04, ly - s * 0.022, c.dx, ly - s * 0.016)
            ..quadraticBezierTo(c.dx + s * 0.04, ly - s * 0.022, c.dx + s * 0.10, ly),
          stroke,
        );
        // Smile
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.10, ly)
            ..quadraticBezierTo(c.dx, ly + s * 0.040, c.dx + s * 0.10, ly),
          stroke,
        );
        break;

      case IveExpression.excited:
        // Open smile with teeth
        final teethRect = Rect.fromCenter(
          center: Offset(c.dx, ly + s * 0.018),
          width: s * 0.20, height: s * 0.065,
        );
        canvas.drawPath(
          Path()..addRect(teethRect)
              ..close(),
          Paint()..color = Colors.white,
        );
        // Lip outline
        canvas.drawArc(Rect.fromCenter(center: Offset(c.dx, ly), width: s * 0.22, height: s * 0.08),
            0, math.pi, false, stroke..style = PaintingStyle.stroke);
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.11, ly)
            ..quadraticBezierTo(c.dx, ly - s * 0.030, c.dx + s * 0.11, ly),
          stroke,
        );
        break;

      case IveExpression.thinking:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s * 0.085, ly)
            ..quadraticBezierTo(c.dx - s * 0.02, ly + s * 0.012, c.dx + s * 0.02, ly)
            ..quadraticBezierTo(c.dx + s * 0.055, ly - s * 0.010, c.dx + s * 0.085, ly),
          stroke,
        );
        break;

      case IveExpression.neutral:
        canvas.drawLine(
          Offset(c.dx - s * 0.085, ly),
          Offset(c.dx + s * 0.085, ly),
          stroke,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _IveExecutivePainter old) =>
      old.expression != expression || old.eyeScale != eyeScale;
}
