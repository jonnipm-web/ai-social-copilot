// TEMPORARY investigation only -- not part of the permanent suite. Answers
// definitively: inside GoRouter's own top-level `redirect` callback, is
// GoRouterState.fullPath non-null for a MATCHED route, and null for a
// genuinely UNMATCHED location (headed for errorBuilder)? This determines
// whether `state.fullPath != null` is a reliable "this path matched a real
// registered route" signal for STABILITY-09-FIX's settled-route gate.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('PROBE: state.fullPath for matched vs unmatched top-level redirect', (tester) async {
    String? matchedFullPath;
    String? matchedMatchedLocation;
    String? unmatchedFullPath;
    String? unmatchedMatchedLocation;
    var redirectCallCount = 0;

    final router = GoRouter(
      initialLocation: '/known',
      redirect: (context, state) {
        redirectCallCount++;
        final path = state.matchedLocation;
        if (path == '/known') {
          matchedFullPath = state.fullPath;
          matchedMatchedLocation = state.matchedLocation;
        } else {
          unmatchedFullPath = state.fullPath;
          unmatchedMatchedLocation = state.matchedLocation;
        }
        return null;
      },
      errorBuilder: (context, state) => const Scaffold(body: Text('error')),
      routes: [
        GoRoute(path: '/known', builder: (_, __) => const Scaffold(body: Text('known'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump();

    router.go('/totally-unmatched-path-xyz');
    await tester.pump();
    await tester.pump();

    // ignore: avoid_print
    print('REDIRECT_FULLPATH_PROBE '
        'redirectCallCount=$redirectCallCount '
        'matchedFullPath=$matchedFullPath matchedMatchedLocation=$matchedMatchedLocation '
        'unmatchedFullPath=$unmatchedFullPath unmatchedMatchedLocation=$unmatchedMatchedLocation');

    expect(true, isTrue);
  });
}
