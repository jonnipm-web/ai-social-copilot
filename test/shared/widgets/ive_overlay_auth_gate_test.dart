import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/ive_overlay.dart';

// IVE-EXPERIENCE-V1-06QA (live-QA defect) — the owner's real authenticated
// QA session found IveOverlay rendering its operational avatar/bubble/CTA
// on the UNAUTHENTICATED /login screen, with a false "Saúde do ecossistema
// em 0/100" claim. Root cause: IveOverlay had no auth gate at all — it is
// mounted globally in app.dart's Stack regardless of route. These tests
// prove the fix: gated on BOTH authStateProvider's session (Codex
// adversarial review, P1 ACCEPTED — closes the in-flight sign-out race,
// see test D below) AND currentProfileProvider (the same "authenticated
// and app-state stable" signal IveIntroGate already used) — failing
// closed for unauthenticated, loading/unknown, AND mid-sign-out alike,
// never leaking the operational surface.
//
// diagnosticLoggerProvider is overridden with a mock — same pattern as
// test/shared/widgets/ai_execution_confirmation_test.dart — its real
// definition eagerly reads Supabase.instance.client, which throws in a
// plain test process. Session is a mocktail Mock (a plain data holder
// class here — only object identity/non-nullness matters, no behavior
// to stub).
class MockDiagnosticLoggerService extends Mock implements DiagnosticLoggerService {}

class MockSession extends Mock implements Session {}

Profile _fakeProfile() => Profile(
      id: 'user-1',
      role: 'free',
      monthlyLimit: 5,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

AuthState _authState({Session? session}) =>
    AuthState(session != null ? AuthChangeEvent.signedIn : AuthChangeEvent.signedOut, session);

void main() {
  Widget harness({required Override profileOverride, required Override authOverride}) {
    return ProviderScope(
      overrides: [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
        profileOverride,
        authOverride,
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              SizedBox.expand(child: ColoredBox(color: Colors.black)),
              IveOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('A. não-autenticado (sessão e profile null): nenhuma superfície operacional da IVE é exibida', (tester) async {
    await tester.pumpWidget(harness(
      profileOverride: currentProfileProvider.overrideWith((ref) async => null),
      authOverride: authStateProvider.overrideWith((ref) => Stream.value(_authState())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Positioned), findsNothing);
    expect(find.bySemanticsLabel('IVE, assistente executiva'), findsNothing);
    expect(find.textContaining('Saúde do ecossistema'), findsNothing);
    expect(find.text('Conversar com a IVE'), findsNothing);
  });

  testWidgets('B. auth loading/desconhecido (nem sessão nem profile resolvem): nenhuma superfície operacional da IVE é exibida (fail-closed)', (tester) async {
    // Nunca resolve — simula o estado "carregando/desconhecido" em ambos.
    await tester.pumpWidget(harness(
      profileOverride: currentProfileProvider.overrideWith((ref) => Completer<Profile?>().future),
      authOverride: authStateProvider.overrideWith((ref) => const Stream.empty()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(Positioned), findsNothing);
    expect(find.bySemanticsLabel('IVE, assistente executiva'), findsNothing);
  });

  testWidgets('C. autenticado (sessão e profile resolvidos): a IVE global canônica permanece disponível', (tester) async {
    await tester.pumpWidget(harness(
      profileOverride: currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
      authOverride: authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Não conta Positioned por tipo (o Scaffold/MaterialApp já monta o seu
    // próprio internamente) -- o rótulo de Semantics é a prova inequívoca
    // de que o avatar operacional da IVE realmente renderizou.
    expect(find.bySemanticsLabel('IVE, assistente executiva'), findsOneWidget);
  });

  // D — Codex adversarial review (P1, ACCEPTED): regressão exata da corrida
  // de sign-out. AuthNotifier.signOut() aguarda a chamada assíncrona ao
  // Supabase ANTES de invalidar currentProfileProvider — então por uma
  // janela real, o profile ainda resolve para um valor não-nulo (stale)
  // mesmo depois que a sessão real já foi encerrada. Simula exatamente essa
  // janela: profile ainda "autenticado" (stale), mas authStateProvider já
  // reporta session null. O overlay deve desaparecer IMEDIATAMENTE, sem
  // esperar a invalidação do profile alcançar o mesmo estado.
  testWidgets('D. corrida de sign-out: sessão já null mas profile ainda stale (não-invalidado) — overlay some mesmo assim', (tester) async {
    await tester.pumpWidget(harness(
      profileOverride: currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
      authOverride: authStateProvider.overrideWith((ref) => Stream.value(_authState())), // session: null
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.bySemanticsLabel('IVE, assistente executiva'), findsNothing);
    expect(find.textContaining('Saúde do ecossistema'), findsNothing);
  });
}
