// TEMPORARY investigation only -- not part of the permanent suite. Answers
// definitively: from the EXACT real production topology (MaterialApp.router
// with `builder` placing a widget as a Stack SIBLING of `child`, per
// app.dart), does Navigator.maybeOf(context) ever resolve non-null once the
// route has settled, or is it permanently null for this structural position?

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

bool? navigatorFoundImmediately;
bool? navigatorFoundAfterSettle;
final rootNavigatorKey = GlobalKey<NavigatorState>();
bool? keyBasedNavigatorFound;

class _ProbeWidget extends StatefulWidget {
  const _ProbeWidget({super.key});
  @override
  State<_ProbeWidget> createState() => _ProbeWidgetState();
}

class _ProbeWidgetState extends State<_ProbeWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigatorFoundImmediately = Navigator.maybeOf(context) != null;
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void probeNow() {
    navigatorFoundAfterSettle = Navigator.maybeOf(context) != null;
  }
}

final _probeKey = GlobalKey<_ProbeWidgetState>();

void main() {
  testWidgets('TOPOLOGY PROBE: exact app.dart MaterialApp.router builder structure', (tester) async {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) {
        // Exactly mirrors app.dart's real structure: child! is the actual
        // Router/Navigator; the probe is a SIBLING in the same Stack, same
        // as IveOverlay/IveIntroGate really are.
        return Stack(
          children: [
            child!,
            _ProbeWidget(key: _probeKey),
          ],
        );
      },
    ));

    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Probe again now that everything has settled -- this is the
    // "steady-state, long after boot" case IveOverlay's chat represents.
    _probeKey.currentState?.probeNow();

    // Codex's recommended alternative: does a NavigatorState reached via an
    // explicitly-owned GlobalKey<NavigatorState> (assigned to GoRouter's own
    // `navigatorKey` parameter) work from this same structural position,
    // where ancestor-based Navigator.maybeOf(context) does not?
    keyBasedNavigatorFound = rootNavigatorKey.currentState != null;

    // ignore: avoid_print
    print('TOPOLOGY_PROBE_RESULT immediate=$navigatorFoundImmediately settled=$navigatorFoundAfterSettle keyBased=$keyBasedNavigatorFound');

    expect(true, isTrue); // always "passes" -- this test is for its printed output only.
  });
}
