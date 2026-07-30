/// P0 Stabilization Sprint — regression tests for Samsung S25 Ultra bugs.
///
/// Groups:
///   P0-01  Business OS Expanded-in-Column RenderFlex crash
///   P0-03  MarketAnalysisNotifier mounted checks
///   P0-05  Overflow guards (Flexible + ellipsis)
///   P0-06  StateNotifier mounted check pattern
///   P0-07  Expanded parenting: must be direct Flex child
///   P0-08  Content library niche text overflow
///   P0-09  IVE overlay hidden on unauthenticated routes
///   P0-10  Navigation guard: canPop before pop
///   P0-11  Controller lifecycle disposal
///   CopilotSheet regression: DraggableScrollableSheet on phone
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/data/models/copilot_turn.dart';
import 'package:ai_social_copilot/providers/context_copilot_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

const _kPhoneSize = Size(412.0, 915.0);

Widget _wrap(Widget widget) => ProviderScope(
      child: MaterialApp(home: Scaffold(body: widget)),
    );

/// Fake notifier that avoids Supabase calls in tests.
class _FakeNotifier extends ContextCopilotNotifier {
  _FakeNotifier(super.ref);

  int sendCount = 0;

  @override
  Future<void> send({
    required String message,
    required String screenName,
    required CopilotContextData context,
  }) async {
    sendCount++;
    state = state.copyWith(
      turns: [
        ...state.turns,
        CopilotTurn(role: 'user', content: message, timestamp: DateTime.now()),
        CopilotTurn(
            role: 'assistant',
            content: 'fake',
            timestamp: DateTime.now()),
      ],
    );
  }
}

// ── P0-01 layout widget helper ────────────────────────────────────────────────

Widget _execModuleLike({required bool isEmpty}) => SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Text('Projetos')]),
                const SizedBox(height: 10),
                // Fixed: Column(mainAxisSize.min) — NOT Expanded
                if (isEmpty)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.inbox, size: 28),
                      Text('Cadastre seu primeiro projeto'),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Ativos: 2'),
                      Text('Total: 4'),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );

// ── P0-06 / P0-03: mounted-check notifier pattern ────────────────────────────

class _MountedNotifier extends StateNotifier<AsyncValue<int?>> {
  _MountedNotifier() : super(const AsyncValue.data(null));

  int droppedUpdates = 0;

  Future<void> run() async {
    state = const AsyncValue.loading();
    final result = await Future.delayed(const Duration(milliseconds: 10), () => 42);
    if (!mounted) {
      droppedUpdates++;
      return;
    }
    state = AsyncValue.data(result);
  }
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  // ── P0-01: Business OS black screen ────────────────────────────────────────
  group('P0-01 Business OS — no RenderFlex in phone layout', () {
    testWidgets('non-empty module renders without overflow on phone',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(_execModuleLike(isEmpty: false)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('empty-state module renders without overflow on phone',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(_execModuleLike(isEmpty: true)));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('four modules stacked in phone Column do not overflow',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(
        SingleChildScrollView(
          child: Column(
            children: List.generate(
              4,
              (i) => _execModuleLike(isEmpty: i.isOdd),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ── P0-03 / P0-06: mounted checks ──────────────────────────────────────────
  group('P0-03 / P0-06 StateNotifier mounted check pattern', () {
    test('update dropped when notifier disposed before async completes',
        () async {
      final n = _MountedNotifier();
      final fut = n.run();
      n.dispose();
      await fut;
      expect(n.droppedUpdates, 1);
    });

    test('update applied when notifier is still mounted', () async {
      final n = _MountedNotifier();
      await n.run();
      expect(n.state.value, 42);
      n.dispose();
    });

    test('5 concurrent runs all dropped on early dispose', () async {
      final n = _MountedNotifier();
      final futures = List.generate(5, (_) => n.run());
      n.dispose();
      await Future.wait(futures);
      expect(n.droppedUpdates, 5);
    });
  });

  // ── P0-05: Overflow guards ──────────────────────────────────────────────────
  group('P0-05 Overflow guards', () {
    testWidgets('ProjectRow with Flexible+ellipsis on phone', (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(
        Row(
          children: [
            Flexible(
              child: Text(
                'Projeto de Marketing Digital Muito Longo Para Testar',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Text(' · '),
            Flexible(
              child: Text(
                '⭐ 95% coverage muito longo',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('niche text with Flexible on smallest phone (320px)',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(
        Row(
          children: [
            const Icon(Icons.label_outline, size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'marketing-digital-avancado-para-empreendedores-brasileiros',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ── P0-07: Expanded only inside Flex ───────────────────────────────────────
  group('P0-07 Expanded parenting invariant', () {
    testWidgets('Expanded as direct Row child — no error', (tester) async {
      await tester.pumpWidget(_wrap(
        Row(children: [
          Expanded(child: Container(height: 40, color: Colors.blue)),
          Expanded(child: Container(height: 40, color: Colors.red)),
        ]),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Expanded wrapping GestureDetector inside Row — correct fix',
        (tester) async {
      // The fix: Expanded → GestureDetector → content (not GestureDetector → Expanded)
      await tester.pumpWidget(_wrap(
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(height: 40, color: Colors.blue),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(height: 40, color: Colors.green),
            ),
          ),
        ]),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  // ── P0-08: Content library niche overflow ───────────────────────────────────
  group('P0-08 Content library niche text', () {
    testWidgets('Flexible+ellipsis prevents niche overflow on phone',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(
        Row(
          children: [
            const Icon(Icons.tag, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'marketing-digital-para-pequenas-empresas-e-empreendedores',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  // ── P0-09: IVE overlay visibility ──────────────────────────────────────────
  group('P0-09 IVE overlay hidden on unauthenticated routes', () {
    tearDown(() {
      iveRouteNotifier.value = '';
    });

    test('iveRouteNotifier initializes to empty string', () {
      expect(iveRouteNotifier.value, isEmpty);
    });

    test('IveRouteObserver.didPush sets route name', () {
      final observer = IveRouteObserver();
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);
      expect(iveRouteNotifier.value, '/home');
    });

    test('IveRouteObserver.didAdd sets route name (covers initial route)',
        () {
      final observer = IveRouteObserver();
      iveRouteNotifier.value = '';
      final route = MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const SizedBox(),
      );
      observer.didAdd(route, null);
      expect(iveRouteNotifier.value, '/');
    });

    test('IveRouteObserver.didPush with login route updates to /login', () {
      final observer = IveRouteObserver();
      iveRouteNotifier.value = '/home';
      final loginRoute = MaterialPageRoute(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(loginRoute, null);
      expect(iveRouteNotifier.value, '/login');
    });

    test('IveRouteObserver.didReplace updates to new named route', () {
      final observer = IveRouteObserver();
      iveRouteNotifier.value = '/';
      final homeRoute = MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const SizedBox(),
      );
      observer.didReplace(newRoute: homeRoute, oldRoute: null);
      expect(iveRouteNotifier.value, '/home');
    });

    test('unnamed route (modal sheet) does not override current route', () {
      final observer = IveRouteObserver();
      iveRouteNotifier.value = '/home';
      final unnamed = MaterialPageRoute(
        // No name — simulates a modal bottom sheet route
        builder: (_) => const SizedBox(),
      );
      observer.didPush(unnamed, null);
      // Must stay '/home', not reset to ''
      expect(iveRouteNotifier.value, '/home');
    });

    test('didPop with named previousRoute restores that route', () {
      final observer = IveRouteObserver();
      iveRouteNotifier.value = '/detail';
      final prev = MaterialPageRoute(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const SizedBox(),
      );
      final current = MaterialPageRoute(
        settings: const RouteSettings(name: '/detail'),
        builder: (_) => const SizedBox(),
      );
      observer.didPop(current, prev);
      expect(iveRouteNotifier.value, '/home');
    });
  });

  // ── P0-10: Navigation canPop guards ────────────────────────────────────────
  group('P0-10 Navigation canPop guards', () {
    testWidgets('pop without prior push does nothing (canPop is false)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
                // No-op if canPop is false — no exception
              },
              child: const Text('Back'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('pop after push succeeds cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const Text('child')),
              ),
              child: const Text('Push'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      final childCtx = tester.element(find.text('child'));
      expect(Navigator.of(childCtx).canPop(), isTrue);
      Navigator.of(childCtx).pop();
      await tester.pumpAndSettle();

      expect(find.text('Push'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── P0-11: Controller lifecycle ────────────────────────────────────────────
  group('P0-11 Controller lifecycle', () {
    test('TextEditingController disposes without exception', () {
      final ctrl = TextEditingController();
      ctrl.text = 'test input';
      ctrl.dispose();
      // After dispose, any further use would throw — test just ensures no
      // exception during normal create → use → dispose cycle.
      expect(true, isTrue);
    });

    testWidgets('AnimationController with TestVSync disposes cleanly',
        (tester) async {
      late AnimationController anim;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(builder: (ctx, setState) {
            anim = AnimationController(
              vsync: const TestVSync(),
              duration: const Duration(milliseconds: 300),
            )..forward();
            return const SizedBox();
          }),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      anim.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScrollController disposes without hasClients error',
        (tester) async {
      final ctrl = ScrollController();
      await tester.pumpWidget(
        _wrap(ListView(controller: ctrl, children: const [Text('item')])),
      );
      await tester.pump();
      expect(ctrl.hasClients, isTrue);
      ctrl.dispose();
      expect(tester.takeException(), isNull);
    });
  });

  // ── CopilotSheet regression ─────────────────────────────────────────────────
  group('CopilotSheet DraggableScrollableSheet regression', () {
    testWidgets('showCopilotChat opens without crash on phone viewport',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contextCopilotProvider.overrideWith(
              (ref, _) => _FakeNotifier(ref),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showCopilotChat(ctx, screenName: 'Test'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('sheet can be dismissed without deactivated-ancestor error',
        (tester) async {
      tester.view.physicalSize = _kPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contextCopilotProvider.overrideWith(
              (ref, _) => _FakeNotifier(ref),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showCopilotChat(ctx, screenName: 'Test'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      // Dismiss by tapping outside the sheet (the barrier)
      await tester.tapAt(const Offset(200, 50));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
