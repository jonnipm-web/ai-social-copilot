import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/shared/widgets/ive_exclusion_region.dart';

// GATE-17-FINAL-CLOSURE (COMMERCIAL-EXPERIENCE-CLOSURE-17A, IVE Adaptive
// Resting Placement) — dedicated tests for IveExclusionRegion itself,
// independent of the full IveOverlay wiring (already covered by
// ive_overlay_auth_gate_test.dart's L/M/O). These focus on what only a
// real Scrollable can prove.
void main() {
  setUp(() {
    // Top-level singleton (module state persists across tests in this
    // isolate) -- reset so ordering never matters, same pattern as
    // ive_overlay_auth_gate_test.dart's own setUp.
    iveExclusionRegionsNotifier.value = const [];
  });

  testWidgets(
    'Codex final audit, P1 ACCEPTED: a mounted-but-unrebuilt item that '
    'scrolls re-publishes its geometry (was previously only measured from '
    'build(), going stale mid-scroll)',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              const SizedBox(height: 800),
              IveExclusionRegion(
                key: const ValueKey('tracked'),
                child: Container(height: 80, color: Colors.red),
              ),
              const SizedBox(height: 800),
            ],
          ),
        ),
      ));
      await tester.pump();
      // IveExclusionRegion's own measurement is itself post-frame.
      await tester.pump();

      final rects = iveExclusionRegionsNotifier.value;
      expect(rects, hasLength(1));
      final beforeScroll = rects.single;

      controller.jumpTo(controller.offset + 400);
      await tester.pump();
      // The scroll-position listener schedules its remeasure post-frame.
      await tester.pump();

      final afterScroll = iveExclusionRegionsNotifier.value.single;
      expect(afterScroll, isNot(equals(beforeScroll)),
          reason: 'the registered Rect must track the item as it scrolls, '
              'not stay frozen at its build-time position -- the item never '
              'rebuilt (ListView does not rebuild already-built children '
              'purely because the scroll offset changed), so only a '
              'scroll-position listener (not build()) can catch this');
      expect(afterScroll.top, closeTo(beforeScroll.top - 400, 1),
          reason: 'the Rect should move up by exactly the scroll delta');
    },
  );

  testWidgets(
    'unregisters cleanly when scrolled far enough to be disposed (lazy list)',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 200,
            itemBuilder: (context, i) {
              if (i == 5) {
                return IveExclusionRegion(
                  child: Container(height: 80, color: Colors.red),
                );
              }
              return SizedBox(height: 80, child: Text('item $i'));
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(iveExclusionRegionsNotifier.value, hasLength(1));

      // Scroll far past item 5 so it's disposed by the lazy list.
      await tester.fling(find.byType(ListView), const Offset(0, -20000), 4000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'dispose-while-scrolling must never throw (build-phase '
              'mutation safety, same class fixed earlier this session)');
      expect(iveExclusionRegionsNotifier.value, isEmpty,
          reason: 'a disposed exclusion region must not permanently occupy '
              'the registry with a now-meaningless off-screen Rect');
    },
  );
}
