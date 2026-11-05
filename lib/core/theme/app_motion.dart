import 'package:flutter/material.dart';

/// InsightValues Dark Premium — motion tokens.
///
/// Durations are picked by distance/complexity (ui-ux-pro-max rule
/// "Animation timing: shared tokens chosen for distance, complexity"),
/// never one duration copied everywhere.
class AppMotion {
  AppMotion._();

  /// Press / hover feedback (80–150ms).
  static const Duration micro = Duration(milliseconds: 140);

  /// Small state changes: badges, toggles, colour shifts.
  static const Duration short = Duration(milliseconds: 220);

  /// Content entrance (fade + rise).
  static const Duration medium = Duration(milliseconds: 420);

  /// Route change (fade-through).
  static const Duration page = Duration(milliseconds: 360);

  /// Data visualisations drawing in.
  static const Duration chart = Duration(milliseconds: 900);

  /// Delay between staggered siblings (kept small so long lists stay fast).
  static const Duration stagger = Duration(milliseconds: 55);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// True when the platform asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fade-through route transition: the outgoing page fades out first, then
/// the incoming page fades in while rising 12px and settling from 98.5%
/// scale. The two pages never overlap at high opacity, so transparent
/// scaffolds over the shared background never ghost.
class IvFadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const IvFadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }

    final incoming = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.30, 1.0, curve: AppMotion.emphasized),
      reverseCurve: const Interval(0.30, 1.0, curve: AppMotion.exit),
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0.0, 0.30, curve: AppMotion.exit),
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(outgoing),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(incoming),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(incoming),
            child: child,
          ),
        ),
      ),
    );
  }
}

const kIvPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: IvFadeThroughPageTransitionsBuilder(),
    TargetPlatform.iOS: IvFadeThroughPageTransitionsBuilder(),
    TargetPlatform.macOS: IvFadeThroughPageTransitionsBuilder(),
    TargetPlatform.windows: IvFadeThroughPageTransitionsBuilder(),
    TargetPlatform.linux: IvFadeThroughPageTransitionsBuilder(),
    TargetPlatform.fuchsia: IvFadeThroughPageTransitionsBuilder(),
  },
);
