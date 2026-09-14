import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ive_interaction_request.dart';
import 'package:ai_social_copilot/data/models/quota_info.dart';
import 'package:ai_social_copilot/providers/quota_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ai_execution_confirmation.dart';

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
      action: () async {
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
      action: () async {
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
        action: () async {
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
        action: () async {
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
      action: () async => throw Exception('falhou'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();

    await expectLater(future, throwsA(isA<Exception>()));
    expect(controller.state, AiExecutionState.error);
  });

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
      action: () async => 1,
    );
    await tester.pump();
    expect(controller.isBusy, isTrue);

    await tester.pumpAndSettle();
    await tester.tap(find.text('CONFIRMAR'));
    await tester.pumpAndSettle();
    await future;

    expect(controller.isBusy, isFalse);
  });
}
