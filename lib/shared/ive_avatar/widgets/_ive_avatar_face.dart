import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ive_avatar_state_v2.dart';

// ── IveAvatarFacePlaceholder ──────────────────────────────────────────────────
//
// Technical placeholder used in V2 preview until final Rive/PNG assets arrive.
// Renders the approved reference image with state-color overlay.
// Falls back to a geometric placeholder if image is unavailable.

const _kReferenceImage = 'assets/ive/reference/ive_character_reference.png';

class IveAvatarFacePlaceholder extends StatelessWidget {
  final IveAvatarStateV2 state;
  final double           size;

  const IveAvatarFacePlaceholder({
    super.key,
    required this.state,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final config = IveAvatarStateConfigV2.forState(state);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          _kReferenceImage,
          fit:       BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => _GeometricPlaceholder(
            color: config.ringColor,
            size:  size,
          ),
        ),
        // State color overlay
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color:    config.overlayColor.withValues(alpha: config.overlayOpacity),
        ),
        // V2 badge in debug builds
        if (kDebugMode)
          Positioned(
            bottom: 0,
            left:   0,
            right:  0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: const Text(
                'V2 PREVIEW',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:         Color(0xFF6C63FF),
                  fontSize:      6.0,
                  fontWeight:    FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Geometric fallback when image asset is missing ────────────────────────────

class _GeometricPlaceholder extends StatelessWidget {
  const _GeometricPlaceholder({required this.color, required this.size});

  final Color  color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0B1A),
      child: Center(
        child: CustomPaint(
          size:    Size(size * 0.55, size * 0.55),
          painter: _IvePlaceholderPainter(color: color),
        ),
      ),
    );
  }
}

class _IvePlaceholderPainter extends CustomPainter {
  const _IvePlaceholderPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Simple geometric IVE silhouette: circle head + rectangle body
    final headR = size.width * 0.28;
    final headC = Offset(size.width / 2, size.height * 0.35);
    canvas.drawCircle(headC, headR, paint);

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.72),
        width:  size.width * 0.52,
        height: size.height * 0.36,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, paint);
  }

  @override
  bool shouldRepaint(_IvePlaceholderPainter old) => old.color != color;
}
