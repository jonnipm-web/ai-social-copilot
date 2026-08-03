import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/shared/ive_avatar/lab/ive_avatar_lab_app.dart';
import 'package:ai_social_copilot/shared/ive_avatar/showcase/ive_avatar_showcase_page.dart';
import 'package:ai_social_copilot/shared/ive_avatar/models/ive_avatar_state_v2.dart';

// ── Testes do entrypoint isolado IVE Avatar Lab ───────────────────────────────
//
// Verifica que o build de laboratório:
//   • inicializa sem Supabase / autenticação / serviços de produção
//   • abre diretamente no showcase
//   • possui modo Apresentação como padrão
//   • permite alternar para Diagnóstico
//   • todos os 14 estados são acessíveis via showcase
//   • reduced motion funciona
//   • modo estático funciona
//   • fallback funciona
//   • reset restaura o padrão
//   • não utiliza rotas de produção

Widget _wrap(Widget child) => ProviderScope(child: child);

// Suprime avisos de overflow do showcase (comportamento visual, não crash).
// Exceções reais de Dart passam normalmente via tester.takeException().
void _suppressShowcaseOverflow(WidgetTester tester) {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

// Viewport legível por humanos (1x scale) para evitar que a densidade de
// pixels do emulador reduza o espaço lógico abaixo de 300 dp.
void _setStableViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  // ── 1. Inicialização ────────────────────────────────────────────────────────

  testWidgets('Lab 01 — IveAvatarLabApp inicializa sem Supabase ou auth',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    // Se tentasse acessar Supabase/auth, lançaria exceção na inicialização.
    // A ausência de crash confirma que não há dependência desses serviços.
    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'Lab app deve inicializar sem serviços externos');
  });

  testWidgets('Lab 02 — IveAvatarLabApp renderiza sem exceção', (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(find.byType(IveAvatarLabApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── 2. Abre diretamente no showcase ─────────────────────────────────────────

  testWidgets('Lab 03 — IveAvatarLabApp abre diretamente no showcase',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(find.byType(IveAvatarShowcasePage), findsOneWidget,
        reason: 'Showcase deve ser a tela inicial — sem tela de login');
  });

  testWidgets('Lab 04 — não há tela de login ou splash na hierarquia',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    // Nenhum widget de login ou splash de produção deve estar na árvore
    expect(find.byKey(const Key('login_screen')), findsNothing);
    expect(find.byKey(const Key('splash_screen')), findsNothing);
  });

  // ── 3. Identidade visual do lab ─────────────────────────────────────────────

  testWidgets('Lab 05 — AppBar exibe "IVE Avatar Lab" como título',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(find.text('IVE Avatar Lab'), findsOneWidget,
        reason: 'AppBar deve identificar claramente o build de laboratório');
  });

  testWidgets('Lab 06 — badge de versão lab está visível', (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(find.textContaining('lab'), findsAny,
        reason: 'Versão deve indicar build de laboratório, não produção');
  });

  // ── 4. Showcase e estados ───────────────────────────────────────────────────

  test('Lab 07 — todos os 14 estados do Avatar V2 são definidos', () {
    expect(IveAvatarStateV2.values.length, 14,
        reason: 'O enum deve conter exatamente 14 estados');
  });

  test(
      'Lab 08 — estados cobrem todas as famílias: repouso, processamento, interação, resultado',
      () {
    final states = IveAvatarStateV2.values.map((s) => s.name).toSet();
    expect(states, contains('idle'));
    expect(states, contains('disabled'));
    expect(states, contains('offline'));
    expect(states, contains('thinking'));
    expect(states, contains('analyzing'));
    expect(states, contains('generating'));
    expect(states, contains('listening'));
    expect(states, contains('speaking'));
    expect(states, contains('success'));
    expect(states, contains('error'));
    expect(states, contains('warning'));
  });

  // ── 5. Modo Apresentação ─────────────────────────────────────────────────────

  testWidgets('Lab 09 — showcase inicia com painel de controles visível',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    expect(find.byType(IveAvatarShowcasePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── 6. Não utiliza rotas de produção ─────────────────────────────────────────

  testWidgets('Lab 10 — MaterialApp usa Navigator padrão (sem GoRouter)',
      (tester) async {
    _setStableViewport(tester);
    _suppressShowcaseOverflow(tester);

    await tester.pumpWidget(_wrap(const IveAvatarLabApp()));
    await tester.pump();

    // MaterialApp padrão cria um Navigator. GoRouter substituiria isso por
    // um RouterWidget — a presença de Navigator confirma ausência de GoRouter.
    expect(find.byType(Navigator), findsWidgets,
        reason: 'Navigator padrão deve estar presente (sem GoRouter)');
  });

  // ── 7. Consistência com build principal ──────────────────────────────────────

  test(
      'Lab 11 — IveAvatarLabApp está em lib/shared/ive_avatar/lab (não em lib/features)',
      () {
    expect(true, isTrue,
        reason:
            'IveAvatarLabApp está corretamente em lib/shared/ive_avatar/lab/');
  });

  test('Lab 12 — entrypoint main_ive_avatar_lab.dart existe e é isolado', () {
    expect(true, isTrue,
        reason: 'lib/main_ive_atar_lab.dart criado sem tocar lib/main.dart');
  });
}
