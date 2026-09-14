import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — canonical back-navigation helper
// (mission Section 13; docs/commercial/COMMERCIAL_NAVIGATION_STANDARD.md
// §2-3). Most screens in this app already hand-roll the same
// `context.canPop() ? context.pop() : context.go(<fallback>)` pattern
// inline in their AppBar's `leading:` — this widget is that same
// pattern, extracted once, so future screens converge on ONE
// implementation rather than each re-typing it (and getting it slightly
// wrong, as `website_analysis_result_screen.dart` did by having no
// `leading:` at all).
//
// Deliberately NOT retrofitted onto every screen in this Phase A mission
// (mission Section 13: "Do NOT manually add arbitrary context.pop() to
// every screen... Target only CRITICAL/high-value screens necessary to
// establish the pattern") — wired into `website_analysis_result_screen.
// dart` only, the one screen with a confirmed, reproducible dead end
// (every entry point uses `context.go()`, which replaces the navigation
// stack, so there is nothing to pop and no default back arrow appears).
class CanonicalBackButton extends StatelessWidget {
  const CanonicalBackButton({super.key, required this.fallbackRoute});

  /// Where to go when there is no internal navigation history to pop —
  /// must be a real, reachable route (a hub/list screen), never a dead
  /// end itself.
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
    );
  }
}
