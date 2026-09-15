import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/ive_intro_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_intro_sheet.dart';

// IVE-EXPERIENCE-V1-06 (Section 31) — "Meet IVE" sheet coverage: display,
// skip, complete, EN/PT-BR, accessibility semantics, and the no-video path
// (this suite never references a video asset/dependency at all — the sheet
// is proven to work correctly without one, per mission Section 13).
//
// diagnosticLoggerProvider is overridden with a mock, same pattern as
// test/shared/widgets/ai_execution_confirmation_test.dart: its real
// definition eagerly reads Supabase.instance.client, which throws in a
// plain test process.
class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness({Locale locale = const Locale('pt')}) {
    return ProviderScope(
      overrides: [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showIveIntroSheet(context, trigger: 'test'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('exibe título e conteúdo em PT-BR por padrão', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.text(l10n.ivIntroTitle), findsOneWidget);
    expect(find.text(l10n.ivIntroWhoBody), findsOneWidget);
    expect(find.text(l10n.ivIntroContinueButton), findsOneWidget);
    expect(find.text(l10n.ivIntroSkipButton), findsOneWidget);
  });

  testWidgets('exibe conteúdo em inglês quando o locale é en', (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('en')));
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.ivIntroTitle), findsOneWidget);
    expect(find.text('Meet IVE'), findsOneWidget);
  });

  testWidgets('Semantics carrega o rótulo de introdução para leitor de tela', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    expect(find.bySemanticsLabel(l10n.ivIntroSemanticLabel), findsOneWidget);
  });

  testWidgets('tocar em "Entendi" marca a introdução como completada e fecha o sheet', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    await tester.tap(find.text(l10n.ivIntroContinueButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.ivIntroTitle), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );
    final state = container.read(iveIntroProvider);
    expect(state.completed, isTrue);
    expect(state.skipped, isFalse);
  });

  testWidgets('tocar em "Pular" marca a introdução como pulada e fecha o sheet', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    await tester.tap(find.text(l10n.ivIntroSkipButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.ivIntroTitle), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.text('open')),
    );
    final state = container.read(iveIntroProvider);
    expect(state.skipped, isTrue);
    expect(state.completed, isFalse);
  });

  testWidgets('nenhum widget/dependência de vídeo é referenciado (caminho sem vídeo)', (tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('open'));
    // IveAvatar keeps a repeating pulse AnimationController alive even with
    // showStatusRing:false (see ive_visual_runtime_test.dart's own pattern)
    // — pumpAndSettle() would hang forever waiting for it to stop, so this
    // suite always uses bounded pumps.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // A prova do "no-video path" é estrutural: este pacote não declara
    // video_player/chewie em pubspec.yaml (ver relatório da missão) e este
    // widget não referencia nenhum desses tipos — o sheet renderiza
    // completamente a partir de texto/l10n e do IveAvatar (fallback já
    // existente), sem qualquer estado de carregamento de mídia.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
