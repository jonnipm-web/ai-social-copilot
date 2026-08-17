import 'package:flutter/widgets.dart';

// ── Motion policy ─────────────────────────────────────────────────────────────

enum IveMotionPolicy {
  fullMotion,
  reducedMotion,
  staticOnly,
}

// ── Motion policy resolver ─────────────────────────────────────────────────────

abstract final class IveMotionPolicyResolver {
  static IveMotionPolicy resolve(BuildContext context) {
    final disable = MediaQuery.disableAnimationsOf(context);
    if (disable) return IveMotionPolicy.reducedMotion;
    return IveMotionPolicy.fullMotion;
  }

  static Duration scaleDuration(Duration base, IveMotionPolicy policy) {
    switch (policy) {
      case IveMotionPolicy.fullMotion:
        return base;
      case IveMotionPolicy.reducedMotion:
        return Duration(
            milliseconds: (base.inMilliseconds * 0.4).round().clamp(200, 800));
      case IveMotionPolicy.staticOnly:
        return Duration.zero;
    }
  }

  static bool shouldLoop(IveMotionPolicy policy) {
    return policy == IveMotionPolicy.fullMotion;
  }

  static double scaleIntensity(double base, IveMotionPolicy policy) {
    switch (policy) {
      case IveMotionPolicy.fullMotion:
        return base;
      case IveMotionPolicy.reducedMotion:
        return base * 0.35;
      case IveMotionPolicy.staticOnly:
        return 0.0;
    }
  }
}
