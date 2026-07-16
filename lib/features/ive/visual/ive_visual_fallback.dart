import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ive_avatar_state.dart';
import 'ive_status_ring.dart';
import 'ive_visual_config.dart';

// ── Temporary Fallback ────────────────────────────────────────────────────────
// Displayed when the Rive asset is not yet available.
// Uses the approved reference image with a status ring overlay.
// THIS IS NOT THE FINAL IMPLEMENTATION — it will be replaced by IveRiveRuntime
// once assets/ive/rive/ive_executive_v1.riv is available.

class IveVisualFallback extends StatefulWidget {
  final IveVisualState state;
  final double         size;

  const IveVisualFallback({
    super.key,
    required this.state,
    required this.size,
  });

  @override
  State<IveVisualFallback> createState() => _IveVisualFallbackState();
}

class _IveVisualFallbackState extends State<IveVisualFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config  = IveVisualStateConfig.forState(widget.state);
    final padding = widget.size * 0.055;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return SizedBox(
          width:  widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: IveStatusRingPainter(
              state:     widget.state,
              glowPulse: _pulse.value,
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Reference image — official character identity
                    Image.asset(
                      IveAssetPaths.referenceImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => _Placeholder(state: widget.state),
                    ),

                    // Subtle state color overlay
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      decoration: BoxDecoration(
                        color: config.overlayColor.withOpacity(
                          config.overlayOpacity * (0.6 + _pulse.value * 0.4),
                        ),
                      ),
                    ),

                    // TEMPORARY_REFERENCE_FALLBACK badge (debug builds only)
                    if (kDebugMode)
                      Positioned(
                        bottom: 0,
                        left:   0,
                        right:  0,
                        child: Container(
                          color: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: const Text(
                            'RIVE ASSET PENDING',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:       Color(0xFFFFB020),
                              fontSize:    6.5,
                              fontWeight:  FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Placeholder when image asset fails ───────────────────────────────────────

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.state});
  final IveVisualState state;

  @override
  Widget build(BuildContext context) {
    final config = IveVisualStateConfig.forState(state);
    return Container(
      color: const Color(0xFF0A0B1A),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: config.ringColor.withOpacity(0.4),
          size:  24,
        ),
      ),
    );
  }
}
