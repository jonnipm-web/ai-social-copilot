import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/ive_interaction_request.dart';
import 'package:ai_social_copilot/data/models/quota_info.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/quota_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ai_execution_confirmation.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — diagnosticLoggerProvider's real
// definition eagerly reads `Supabase.instance.client`, which throws in
// any test process that never called Supabase.initialize(). Overriding
// it with a mock (rather than routing AiExecutionController through the
// ambient `diagnosticLogger` top-level getter, which reads from a
// separate module-level ProviderContainer this test's ProviderScope
// cannot reach at all) is exactly why AiExecutionController takes `ref`
// and uses `ref.read(diagnosticLoggerProvider)` instead of that getter.
class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

// IVE-COMMERCIAL-FOUNDATION-11 — covers the reusable AI-execution
// confirmation mechanism (mission Sections 07-08). This is the ONLY
// mechanism in the app that gates an AI-consuming button behind an
// explicit "this will use 1 analysis" confirmation with a synchronous
// double-submit guard — these tests are the regression suite for that
// guarantee across all future call sites, not just the one screen
// (gap_analysis_screen.dart) migrated to it in this mission.
void main() {
  // Captures a real BuildContext + WidgetRef from inside the widget tree
  // so tests can call controller.run(...) directly and await its result,
  // in addition to exercising it via a real button tap.
  late BuildContext capturedContext;
  late WidgetRef capturedRef;

  Widget harness() {
    return ProviderScope(
      overrides: [
        currentQuotaProvider.overrideWith(
          (ref) async => const QuotaInfo(role: 'free', limit: 5, used: 2),
        ),
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              capturedContext = context;
              capturedRef = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  IveInteractionRequest req() =>
      IveInteractionRequest(sourceModule: 'test', operationType: IveOperationType.analyze);

  testWidgets('CANCELAR: nenhuma chamada de ação é feita, estado volta a idle', (tester) async {
    var calls = 0;
    final controller = AiExecutionController();
    await tester.pumpWidget(harness());

    final future = controller.run<int>(
      context: capturedContext,
      ref: capturedRef,
      analysisLabel: 'Teste',
      request: req(),
      action: (idempotencyKey) async {
        calls++;
        return 1;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('CANCELAR'), findsOneWidget);
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(await future, isNull);
    expect(calls, 0);
    expect(controller.state, AiExecutionState.idle);
  });

  testWidgets('CONFIRMAR: exatamente uma chamada de ação é feita, estado vira success',
      (tester) async {
    var calls = 0;
    final controller = AiExecutionController();
    await tester.pumpWidget(harness());

    final future = controller.run<int>(
      context: capturedContext,
      ref: capturedRef,
      analysisLabel: 'Teste',
      request: req(),
      action: (idempotencyKey) async {
        calls++;
        return 42;
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    expect(await future, 42);
    expect(calls, 1);
    expect(controller.state, AiExecutionState.success);
  });

  testWidgets(
    'chamar run() uma segunda vez enquanto a primeira ainda está em andamento '
    'não dispara uma segunda execução (guarda síncrona)',
    (tester) async {
      var calls = 0;
      final controller = AiExecutionController();
      await tester.pumpWidget(harness());

      // Primeira chamada: guarda síncrona já marca isBusy=true antes de
      // qualquer await (ver AiExecutionController.run).
      final first = controller.run<int>(
        context: capturedContext,
        ref: capturedRef,
        analysisLabel: 'Teste',
        request: req(),
        action: (idempotencyKey) async {
          calls++;
          return 1;
        },
      );

      // IVE-COMMERCIAL-FOUNDATION-11 (Codex round 1, P1, ACCEPTED) — a
      // segunda chamada síncrona, antes de qualquer pump/await, deve ser
      // recusada imediatamente porque a guarda já foi setada pela
      // primeira chamada antes do primeiro `await` dela mesma.
      expect(controller.isBusy, isTrue);
      final second = controller.run<int>(
        context: capturedContext,
        ref: capturedRef,
        analysisLabel: 'Teste',
        request: req(),
        action: (idempotencyKey) async {
          calls++;
          return 2;
        },
      );
      expect(await second, isNull);

      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();
      await first;

      // Apenas a PRIMEIRA ação foi executada — a segunda nunca chamou action().
      expect(calls, 1);
    },
  );

  testWidgets('ERRO na ação: estado vira error e a exceção propaga para quem chamou run()',
      (tester) async {
    final controller = AiExecutionController();
    await tester.pumpWidget(harness());

    final future = controller.run<int>(
      context: capturedContext,
      ref: capturedRef,
      analysisLabel: 'Teste',
      request: req(),
      action: (idempotencyKey) async => throw Exception('falhou'),
    );
    // IMPORTANTE: anexa o matcher assíncrono ANTES de qualquer outro
    // await — se `future` rejeitar enquanto nada está "escutando" ainda
    // (ex.: durante os awaits de pump/tap abaixo), o Dart trata como
    // exceção não tratada na zone do teste, mesmo que um `expectLater`
    // mais tardio fosse eventualmente vê-la.
    final expectation = expectLater(future, throwsA(isA<Exception>()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    await expectation;
    expect(controller.state, AiExecutionState.error);
  });

  // ── IVE-COMMERCIAL-QUOTA-HARDENING-13 — idempotency key contract ────────
  testWidgets(
    'run() passa para action() exatamente o idempotencyKey da request confirmada',
    (tester) async {
      final controller = AiExecutionController();
      await tester.pumpWidget(harness());
      final request = req();
      String? receivedKey;

      final future = controller.run<int>(
        context: capturedContext,
        ref: capturedRef,
        analysisLabel: 'Teste',
        request: request,
        action: (idempotencyKey) async {
          receivedKey = idempotencyKey;
          return 1;
        },
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR'));
      await tester.pumpAndSettle();
      await future;

      expect(receivedKey, isNotNull);
      expect(receivedKey, request.idempotencyKey);
    },
  );

  testWidgets(
    'duas execuções confirmadas sucessivas (duas requests novas) recebem '
    'idempotencyKeys diferentes — cada uma é uma operação nova',
    (tester) async {
      final controller = AiExecutionController();
      await tester.pumpWidget(harness());
      final keys = <String>[];

      for (var i = 0; i < 2; i++) {
        final future = controller.run<int>(
          context: capturedContext,
          ref: capturedRef,
          analysisLabel: 'Teste',
          request: req(), // uma IveInteractionRequest NOVA a cada chamada
          action: (idempotencyKey) async {
            keys.add(idempotencyKey);
            return 1;
          },
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR'));
        await tester.pumpAndSettle();
        await future;
      }

      expect(keys.length, 2);
      expect(keys[0], isNot(keys[1]));
    },
  );

  testWidgets('isBusy é false antes de run() e volta a false após success/cancel',
      (tester) async {
    final controller = AiExecutionController();
    await tester.pumpWidget(harness());
    expect(controller.isBusy, isFalse);

    final future = controller.run<int>(
      context: capturedContext,
      ref: capturedRef,
      analysisLabel: 'Teste',
      request: req(),
      action: (idempotencyKey) async => 1,
    );
    await tester.pump();
    expect(controller.isBusy, isTrue);

    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();
    await future;

    expect(controller.isBusy, isFalse);
  });

  // ── confirm() — Codex Gate 1 / mission 13, Seção 12 (auto-bootstrap) ────
  testWidgets(
    'confirm() com estimatedUnits > 1 mostra o custo real ("até N"), não o texto de 1 unidade',
    (tester) async {
      final controller = AiExecutionController();
      await tester.pumpWidget(harness());

      final future = controller.confirm(
        context: capturedContext,
        ref: capturedRef,
        analysisLabel: 'Bootstrap automático',
        request: req(),
        estimatedUnits: 3,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('até 3'), findsOneWidget);
      expect(find.textContaining('vai consumir 1 das'), findsNothing);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
    },
  );

  testWidgets(
    'confirm() com estimatedUnits padrão (1) mantém o texto original de 1 unidade',
    (tester) async {
      final controller = AiExecutionController();
      await tester.pumpWidget(harness());

      final future = controller.confirm(
        context: capturedContext,
        ref: capturedRef,
        analysisLabel: 'Análise simples',
        request: req(),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('vai consumir 1 das suas análises mensais'), findsOneWidget);

      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      await future;
    },
  );
}
