import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ai_social_copilot/shared/widgets/canonical_back_button.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — covers the canonical back-navigation
// helper (mission Section 13). Regression target: website_analysis_
// result_screen.dart had NO leading override at all, so Flutter's
// default AppBar showed a drawer hamburger instead of a back arrow, and
// every entry point used `context.go()` (replacing history), so even a
// default back arrow would have had nothing to pop.
void main() {
  Widget appWithRouter(GoRouter router) => MaterialApp.router(routerConfig: router);

  testWidgets('quando há histórico para voltar (canPop), usa pop()', (tester) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Tela A'))),
        GoRoute(
          path: '/a/detail',
          builder: (_, __) => Scaffold(
            appBar: AppBar(leading: const CanonicalBackButton(fallbackRoute: '/fallback')),
            body: const Text('Detalhe'),
          ),
        ),
        GoRoute(path: '/fallback', builder: (_, __) => const Scaffold(body: Text('Fallback'))),
      ],
    );

    await tester.pumpWidget(appWithRouter(router));
    router.push('/a/detail');
    await tester.pumpAndSettle();

    expect(find.text('Detalhe'), findsOneWidget);
    await tester.tap(find.byType(CanonicalBackButton));
    await tester.pumpAndSettle();

    // Voltou para a tela anterior (pop), não para o fallback.
    expect(find.text('Tela A'), findsOneWidget);
    expect(find.text('Fallback'), findsNothing);
  });

  testWidgets(
    'quando NÃO há histórico para voltar (ex.: chegou via go()), usa o fallback',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/a/detail',
        routes: [
          GoRoute(path: '/a', builder: (_, __) => const Scaffold(body: Text('Tela A'))),
          GoRoute(
            path: '/a/detail',
            builder: (_, __) => Scaffold(
              appBar: AppBar(leading: const CanonicalBackButton(fallbackRoute: '/fallback')),
              body: const Text('Detalhe'),
            ),
          ),
          GoRoute(path: '/fallback', builder: (_, __) => const Scaffold(body: Text('Fallback'))),
        ],
      );

      await tester.pumpWidget(appWithRouter(router));
      await tester.pumpAndSettle();

      expect(find.text('Detalhe'), findsOneWidget);
      await tester.tap(find.byType(CanonicalBackButton));
      await tester.pumpAndSettle();

      // Sem histórico para pop — vai para o fallback determinístico, não
      // fica preso na mesma tela nem quebra.
      expect(find.text('Fallback'), findsOneWidget);
    },
  );
}
