// IVE-COMMERCIAL-STABILITY-09 — isolated reproduction attempt for the
// "Null check operator used on a null value" production crash.
//
// STATIC LEAD (not yet proven): lib/app.dart's MaterialApp.router `builder`
// callback does `child!` (line ~628) inside a `Stack` that also mounts the
// globally-present `IveOverlay`. This is the ONLY widget structurally
// present on every single route (confirmed via grep: IveOverlay has a
// single mount point, in app.dart, wrapping the routed content). Evidence
// from production diagnostic_events (session 7f8d86a8..., 5 crash clusters
// across 6 distinct routes: /ecosystem, /ecosystem/briefing,
// /market-intelligence/competitors/:id, /opportunity-lab, /action-engine
// x2) shows the crash is NOT tied to one specific screen, which points
// away from screen-local code and toward something globally mounted like
// this builder or IveOverlay itself.
//
// This test isolates the SMALLEST possible reproduction of app.dart's
// exact structural pattern (MaterialApp.router + a GoRouter with an ASYNC
// redirect callback, matching _router's `redirect: (context, state) async
// {...}` at app.dart:215, plus a builder doing the literal `child!`) to
// determine whether Flutter's MaterialApp.router can ever invoke `builder`
// with `child == null` while an async redirect is pending or during rapid
// route transitions. It does NOT use the real App/Supabase/routes — per
// mission instruction (Section 08: "binary isolation... identify the
// smallest condition necessary for reproduction").
//
// The literal `child!` is used deliberately (not a defensive `if (child ==
// null)` check) so that, if it ever fires, `tester.takeException()` below
// captures the EXACT same exception type/message as production
// ("Null check operator used on a null value"), not a stand-in assertion.
//
// RESULT OF THIS TEST IS EVIDENCE, either way:
//   - If `tester.takeException()` returns a null-check error: PROVEN
//     reproduction of the exact production signature, isolating the
//     responsible line (app.dart's builder / child!).
//   - If it never throws despite the async-redirect + rapid-transition
//     stress below: this specific hypothesis is ELIMINATED, and
//     investigation must continue elsewhere (IveOverlay's own internals,
//     provider watch chains, etc.) — report this explicitly either way.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'MaterialApp.router builder child! never throws under an async '
    'redirect + rapid route-transition stress (isolated app.dart pattern)',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        redirect: (context, state) async {
          // Mirrors app.dart's `redirect: (context, state) async {...}` —
          // an async gap on every navigation, exactly like the real app's
          // _computeRedirect await chain.
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return null; // no actual redirect, just the same async shape
        },
        routes: [
          GoRoute(path: '/a', builder: (_, __) => const Text('A')),
          GoRoute(path: '/b', builder: (_, __) => const Text('B')),
          GoRoute(path: '/c', builder: (_, __) => const Text('C')),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          // Exact structural mirror of app.dart:626-631 — literal `child!`
          // inside a Stack with a second always-mounted widget.
          builder: (context, child) => Stack(
            children: [
              child!,
              const _GlobalOverlayStandIn(),
            ],
          ),
        ),
      );
      await tester.pump();

      // Rapid-fire route transitions while redirects are still resolving —
      // reproduces the "burst" shape seen in production (multiple crashes
      // within ~1 second of each other across the evidence matrix).
      for (var i = 0; i < 20; i++) {
        router.go(i.isEven ? '/b' : '/c');
        // No await on the 5ms redirect delay here on purpose: pumping with
        // zero extra delay lets Flutter process whatever microtasks/frames
        // are ready without letting the redirect fully resolve before the
        // NEXT navigation fires — this is the async-overlap condition.
        await tester.pump();
      }

      // Let everything settle, then collect whatever exception (if any)
      // the framework caught during the stress above.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      final caught = tester.takeException();
      if (caught != null) {
        // Surface it as a normal test failure with full context instead of
        // letting the test runner report a bare stack — this IS the
        // evidence the mission asked for if it happens.
        fail(
          'REPRODUCED under isolated stress: ${caught.runtimeType}: $caught\n'
          'This suggests app.dart:628 (`child!` in MaterialApp.router\'s '
          'builder) as the root cause of the production crash.',
        );
      }
      // No exception: hypothesis eliminated for this specific code shape.
    },
  );
}

/// Stand-in for IveOverlay: a second widget mounted alongside `child` on
/// every route (mirrors app.dart's `Stack(children: [child!, const
/// IveOverlay()])`), to prove the Stack construction itself does not
/// independently misbehave under the same stress.
class _GlobalOverlayStandIn extends StatelessWidget {
  const _GlobalOverlayStandIn();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
