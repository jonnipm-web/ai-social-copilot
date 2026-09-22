import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/data/models/ive_issue.dart';
import 'package:ai_social_copilot/data/models/ive_state.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/ive_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/context_copilot_widget.dart'
    show iveChatOpenNotifier, IveInlineAskPresence;
import 'package:ai_social_copilot/shared/widgets/ive_exclusion_region.dart';
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

// COMMERCIAL-EXPERIENCE-CLOSURE-17A — same reason test E already gives:
// a plain message with no activeIssue renders the bubble's fixed
// "Conversar com a IVE" CTA Row, whose static localized text overflows
// under the test binding's non-proportional fallback font at mobile test
// widths -- a test-harness-only artifact, not a real rendering defect
// (never reproduced physically). Routing through activeIssue instead
// renders `_IssueActions` (a Wrap) below the message, which doesn't hit
// this. Tests P/Q/R below only care about the MESSAGE's own geometry
// (rendered the same regardless of which branch follows it), not this
// specific issue's content.
IveIssue _testIssue() => IveIssue(
      errorCode:        'TEST_ISSUE',
      stage:            IveIssueStage.unknown,
      severity:         IveIssueSeverity.warning,
      recoverable:      true,
      userMessage:      'irrelevant -- _IveBubble renders IveState.message, not this',
      technicalMessage: 'irrelevant',
      occurredAt:       DateTime(2026, 1, 1),
      recommendedActions: const [
        IveIssueAction(label: 'Tentar novamente', actionKey: 'retry'),
      ],
    );

void main() {
  // COMMERCIAL-EXPERIENCE-CLOSURE-16 — iveChatOpenNotifier is a top-level
  // singleton (module-level state persists across testWidgets calls within
  // this same file/isolate); test F opens a chat sheet and never closes it
  // before the test ends, which would otherwise leave the notifier `true`
  // and incorrectly hide every subsequent test's IveOverlay. Reset before
  // each test so ordering never matters.
  setUp(() {
    iveChatOpenNotifier.value = false;
    // Test H below balances its own push/pop, so the internal counter
    // self-resets to 0 -- this just also resets the public notifier in
    // case a future test in this file leaves it unbalanced.
    iveModalOpenNotifier.value = false;
    // GATE-17-FINAL-CLOSURE (Section 03) -- same cross-test-pollution risk
    // as the two notifiers above: a top-level singleton test I/J could
    // leave `true` for a later test in this file if not reset here.
    iveScrollingNotifier.value = false;
    // COMMERCIAL-EXPERIENCE-CLOSURE-17A -- same cross-test-pollution risk;
    // a test that registers IveExclusionRegions should already leave this
    // empty via normal widget disposal, but reset explicitly so ordering
    // never matters here either.
    iveExclusionRegionsNotifier.value = const [];
  });

  // STABILITY-10 -- IveOverlay now requires a navigatorKey (see its own
  // constructor doc). A-D below only exercise auth-gating/rendering, not
  // chat-opening, so a plain unattached key is enough to satisfy the
  // constructor without changing what these tests actually verify.
  Widget harness({required Override profileOverride, required Override authOverride}) {
    return ProviderScope(
      overrides: [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
        profileOverride,
        authOverride,
      ],
      child: MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(child: ColoredBox(color: Colors.black)),
              IveOverlay(navigatorKey: GlobalKey<NavigatorState>()),
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

  // E — IVE-EXPERIENCE-V1-06QA (live-QA gate-2 defect, Codex-confirmed P1).
  // Real desktop-width QA (MediaQuery 1536x639, matching the owner's actual
  // browser viewport) found the floating avatar rendered ~130px past the
  // right edge of the screen whenever the alert bubble was wide enough to
  // hit its `maxWidth: 220` -- unreachable/unclickable, despite the auth
  // gate correctly allowing the overlay to render at all. Root cause:
  // `_defaultPosition()` computed a `left:` coordinate assuming the column
  // was only ~88px wide (avatar + margin), not accounting for the wider
  // bubble. Fixed by anchoring with `right:` instead, so the column's
  // right-aligned avatar is always a fixed distance from the right edge
  // regardless of bubble width.
  //
  // Uses an `activeIssue` (rather than a plain alert message) to widen the
  // bubble to its real maxWidth: 220 -- the exact condition that exposed
  // the bug -- while going through `_IssueActions` (a `Wrap`) instead of
  // the plain-message branch's fixed "Conversar com a IVE" `Row`, which
  // overflows under the test binding's non-proportional fallback font at
  // this width (a test-harness-only artifact never seen in the real,
  // live-QA'd rendering) and would otherwise mask this test's own
  // assertion. The bug and its fix are about the Column's geometry, not
  // which bubble content variant is showing.
  testWidgets(
    'E. desktop width (1536x639) com bolha larga (issue ativo): o avatar da IVE permanece inteiramente dentro da viewport',
    (tester) async {
      tester.view.physicalSize = const Size(1536, 639);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final wideIssueState = IveState(
        bubbleVisible: true,
        message: 'Não consegui analisar "Apresentação Profissional do Projeto".',
        activeIssue: IveIssue(
          errorCode:        'KNOWLEDGE_ANALYSIS_FAILED',
          stage:            IveIssueStage.analysis,
          severity:         IveIssueSeverity.error,
          recoverable:      true,
          userMessage:      'Não consegui analisar "Apresentação Profissional do Projeto".',
          technicalMessage: 'timeout',
          occurredAt:       DateTime(2026, 1, 1),
          recommendedActions: const [
            IveIssueAction(label: 'Tentar novamente', actionKey: 'retry'),
            IveIssueAction(label: 'Ver detalhes',     actionKey: 'view_details'),
          ],
        ),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
          iveProvider.overrideWith((ref) => _FixedIveNotifier(ref, wideIssueState)),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(child: ColoredBox(color: Colors.black)),
                IveOverlay(navigatorKey: GlobalKey<NavigatorState>()),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // find.bySemanticsLabel walks the compiled SemanticsNode tree, which
      // this harness's explicit `tester.view.physicalSize` override leaves
      // out of sync with; the *widget* is unambiguously present (confirmed
      // via debugDumpApp during investigation), so match it directly by
      // its Semantics properties instead of relying on the semantics tree.
      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsOneWidget);

      final avatarRect = tester.getRect(avatarFinder);
      final viewport = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;

      // Scoped to the exact regression this mission verified live: the
      // avatar rendering past the RIGHT edge, unreachable, at real desktop
      // widths. (A separate, much smaller ~9px vertical clip surfaced by
      // this same fixture when it carries two wrapped issue-action chips —
      // never observed in the live QA session, whose real alert bubble fit
      // fully within the viewport vertically — is a distinct, out-of-scope
      // finding for a follow-up mission, not this fix.)
      expect(avatarRect.left, greaterThanOrEqualTo(viewport.left));
      expect(avatarRect.right, lessThanOrEqualTo(viewport.right));
    },
  );

  // F — IVE-EXPERIENCE-V1-06QA (live-QA gate-2 defect). The positioning fix
  // (test E) proves the avatar is on-screen; this proves tapping it actually
  // does something -- live-QA browser automation could not conclusively
  // settle this itself (repeated coordinate clicks landed on the right
  // widget per pixel inspection, yet the viewport kept resizing between
  // screenshots in a way unrelated to app code, making manual click
  // coordinates unreliable evidence either way). `tester.tap` hit-tests
  // through the real widget tree, sidestepping that entirely: it proves
  // whether `_IveOverlayState`'s `onTap` (bubbleVisible ? dismissBubble :
  // _openChat) actually fires and opens the real Context Copilot sheet,
  // not just that the GestureDetector exists in the tree.
  //
  // STABILITY-10 -- this test ORIGINALLY used MaterialApp(home:
  // Scaffold(body: Stack(children: [..., IveOverlay()]))), which places
  // IveOverlay BELOW an implicit Navigator MaterialApp builds internally --
  // a structurally different, easier topology than production's real
  // MaterialApp.router (see app.dart), where IveOverlay is a Stack SIBLING
  // of the Router's own child, never a descendant of it. That mismatch is
  // exactly why this test kept passing while a real, symbolicated
  // production crash (same signature as STABILITY-09: "Null check operator
  // used on a null value" -> showModalBottomSheet -> Navigator.of) was
  // live in _openChat. Rebuilt around a real GoRouter + MaterialApp.router
  // whose `builder` mirrors app.dart's exact Stack(children: [child!,
  // IveOverlay(navigatorKey: ...), ...]) structure.
  testWidgets(
    'F. toque no avatar da IVE (sem bolha ativa) abre o Context Copilot',
    (tester) async {
      // Tall enough that the opened sheet's empty-state content doesn't
      // itself overflow -- irrelevant to what this test checks (that the
      // tap opens the sheet at all), but an unrelated overflow warning
      // would otherwise clutter the run.
      tester.view.physicalSize = const Size(1536, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [
              child!,
              IveOverlay(navigatorKey: navigatorKey),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      expect(find.text(l10n.iveChatAskCta), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(avatarFinder, warnIfMissed: false);
      // Not pumpAndSettle: the opened sheet's empty state has a
      // continuously-repeating animation that never settles. A handful of
      // bounded pumps is enough for the modal route's own entrance
      // transition to finish and the sheet's content to build.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i opening the chat sheet');
      }

      expect(find.text(l10n.iveChatAskCta), findsOneWidget);
    },
  );

  // G — STABILITY-10 regression: the pathological case where the
  // navigatorKey has genuinely never attached to any Navigator (mirrors
  // IveIntroGate's own equivalent test). _openChat must no-op safely
  // rather than crash -- there is nothing to bound-retry here (unlike
  // IveIntroGate's app-boot race, this fires from a synchronous user tap,
  // so a permanently-unattached key is the pathological case, not the
  // reproduced one).
  testWidgets(
    'G. toque no avatar quando o navigatorKey nunca se anexou a nenhum Navigator: nenhuma exceção, sheet não abre',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                const SizedBox.expand(child: ColoredBox(color: Colors.black)),
                IveOverlay(navigatorKey: navigatorKey),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder, warnIfMissed: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'threw on pump #$i with navigatorKey never attached');
      }
      expect(find.text('Pergunte à IVE'), findsNothing);
    },
  );

  // H — COMMERCIAL-EXPERIENCE-CLOSURE-16R (mission Section 07) — owner-
  // supplied physical evidence (Performance -> Nova Métrica): IveOverlay
  // covered the primary "Salvar" button of a plain showModalBottomSheet
  // that has NOTHING to do with the copilot chat. Proves the generic
  // fix -- IveRouteObserver counting PopupRoute push/pop -- hides
  // IveOverlay for ANY modal, not just showCopilotChat's own sheet/dialog.
  testWidgets(
    'H. IveOverlay some enquanto QUALQUER modal genérico (não relacionado ao chat) está aberto',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (_) => const SizedBox(height: 200, child: Center(child: Text('Salvar'))),
                  ),
                  child: const Text('open unrelated sheet'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [
              child!,
              IveOverlay(navigatorKey: navigatorKey),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsOneWidget, reason: 'IVE avatar visible before the unrelated sheet opens');

      // Not pumpAndSettle: IveAvatar's ring-pulse animation never settles
      // on its own (same caveat as test F above) -- bounded pumps instead.
      await tester.tap(find.text('open unrelated sheet'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(avatarFinder, findsNothing, reason: 'IVE avatar must hide while ANY modal covers the screen');
      expect(find.text('Salvar'), findsOneWidget);

      // Close it -- IveOverlay must reappear.
      Navigator.of(tester.element(find.text('Salvar')), rootNavigator: true).pop();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(avatarFinder, findsOneWidget, reason: 'IVE avatar must reappear once the modal closes');
      expect(tester.takeException(), isNull);
    },
  );

  // I — GATE-17-FINAL-CLOSURE (Section 03/04, "react correctly to keyboard").
  // A form's Save/submit button routinely sits directly above an open
  // keyboard; the floating avatar has no safe place there, so it hides
  // entirely rather than guess a position. MediaQuery.viewInsets.bottom is
  // the framework's own signal for "a keyboard (or similar bottom inset) is
  // currently showing" -- true on every screen with a focused text field,
  // with no per-screen wiring required.
  //
  // Deliberately does NOT use the shared harness() above: harness() nests
  // IveOverlay inside a Scaffold's `body`, but Scaffold's default
  // resizeToAvoidBottomInset:true strips bottom viewInsets from its OWN
  // body subtree (Scaffold.build -> `data.removeViewInsets(removeBottom:
  // true)`, scaffold.dart) precisely so body content doesn't ALSO try to
  // dodge a keyboard Scaffold is already resizing around -- a real Flutter
  // behavior, not a test bug, but one that would silently zero the very
  // signal this test means to exercise. app.dart's real topology mounts
  // IveOverlay OUTSIDE every screen's own Scaffold (a Stack sibling of the
  // router's content, see the STABILITY-10 doc comment on IveOverlay
  // itself), so this harness mirrors that instead: no Scaffold ancestor.
  testWidgets(
    'I. teclado aberto (viewInsets.bottom > 0): overlay esconde completamente e reaparece ao fechar',
    (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Stack(
            children: [
              const SizedBox.expand(child: ColoredBox(color: Colors.black)),
              IveOverlay(navigatorKey: GlobalKey<NavigatorState>()),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel('IVE, assistente executiva'), findsOneWidget);

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      expect(
        find.bySemanticsLabel('IVE, assistente executiva'),
        findsNothing,
        reason: 'must hide while a keyboard/bottom inset is showing, not guess a position above it',
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.bySemanticsLabel('IVE, assistente executiva'),
        findsOneWidget,
        reason: 'must reappear once the keyboard closes',
      );
    },
  );

  // J — GATE-17-FINAL-CLOSURE (Section 03) -- ivePageScrollNotification's
  // own reaction, not Flutter's ScrollNotification bubbling itself (a
  // framework guarantee, not this app's logic to re-test). Drives
  // iveScrollingNotifier directly, the same signal app.dart's
  // NotificationListener<ScrollNotification> sets from any real Scrollable
  // in the app -- see that notifier's doc comment in ive_overlay.dart.
  testWidgets(
    'J. rolagem ativa sem bolha aberta: avatar recua (opacidade/escala reduzidas) mas nunca desaparece; volta ao normal ao parar',
    (tester) async {
      await tester.pumpWidget(harness(
        profileOverride: currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
        authOverride: authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacityFinder = find.byKey(const ValueKey('iveScrollCompactionOpacity'));
      expect(
        tester.widget<AnimatedOpacity>(opacityFinder).opacity,
        1.0,
        reason: 'at rest, fully visible',
      );

      iveScrollingNotifier.value = true;
      await tester.pump();

      expect(find.bySemanticsLabel('IVE, assistente executiva'), findsOneWidget,
          reason: 'recedes during scroll, but must never fully disappear (unlike the keyboard/modal cases)');
      expect(
        tester.widget<AnimatedOpacity>(opacityFinder).opacity,
        lessThan(1.0),
        reason: 'visually recedes while content is actively scrolling underneath it',
      );

      iveScrollingNotifier.value = false;
      await tester.pump();

      expect(
        tester.widget<AnimatedOpacity>(opacityFinder).opacity,
        1.0,
        reason: 'returns to full visibility once scrolling stops',
      );
    },
  );

  // K — GATE-17-FINAL-CLOSURE (physical Android feedback, 2026-09-21): a
  // screen's own dedicated "Perguntar à IVE" CTA is redundant with the
  // floating avatar sitting on top of it. `flutter test` runs with
  // kIsWeb == false, so this exercises exactly the Android-only branch the
  // owner asked for; the web behavior is unchanged by construction (the
  // `!kIsWeb &&` guard in ive_overlay.dart), not something a non-web test
  // binary can flip to verify directly.
  testWidgets(
    'K. IveOverlay some enquanto um IveInlineAskPresence (CTA própria de '
    '"Perguntar à IVE" da tela) está visível — redundante com o avatar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(
            path: '/',
            builder: (context, __) => const Scaffold(
              body: Center(
                child: IveInlineAskPresence(
                  child: Text('Perguntar à IVE sobre esta ação'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [
              child!,
              IveOverlay(navigatorKey: navigatorKey),
            ],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsNothing,
          reason: 'must already be hidden: the CTA mounts in the same frame as the route');
      expect(find.text('Perguntar à IVE sobre esta ação'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // ── IVE Adaptive Resting Placement (GATE-17-FINAL-CLOSURE) ────────────────
  // L-O below exercise the placement engine (ive_placement_engine.dart) as
  // actually wired into the real IveOverlay widget, on top of the pure
  // computeRestingPosition unit tests in
  // test/shared/widgets/ive_placement_engine_test.dart -- those already
  // cover the algorithm's own edge cases (viewport clamp, safeArea insets,
  // no-valid-candidate fallback, determinism) exhaustively, so these focus
  // on what only a real widget tree can prove: that IveExclusionRegion's
  // reported geometry actually reaches the overlay, that mounting/
  // unmounting one doesn't throw (the same class of Riverpod/build-phase
  // crash this session already found and fixed once -- 9df6c4f), and that
  // a manual drag is re-validated once released rather than silently
  // fighting the user's placement forever.

  testWidgets(
    'L. sem exclusion regions: avatar repousa no canto inferior-direito padrão',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [child!, IveOverlay(navigatorKey: navigatorKey)],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      expect(avatarFinder, findsOneWidget);
      final rect = tester.getRect(avatarFinder);
      expect(rect.right, closeTo(400, 16),
          reason: 'no exclusions -> the bottom-right candidate, near the right edge');
      expect(rect.bottom, greaterThan(400),
          reason: 'no exclusions -> still the BOTTOM-right candidate (lower half '
              'of the screen), not pushed all the way up');
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(800.5),
          reason: 'regression guard: the whole bubble+avatar column (the bubble '
              'is always laid out above the avatar, even hidden) must stay '
              'on-screen -- previously verticalReserve was missing and the '
              'avatar rendered fully off the bottom edge, unreachable by any '
              'pointer (see ive_placement_engine.dart verticalReserve)');
    },
  );

  testWidgets(
    'M. IveExclusionRegion cobrindo o canto padrão: avatar se desloca para um canto seguro '
    'e permanece lá (sem jitter) depois que a região é removida',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      // The block's Rect is filled in AFTER the first render, from wherever
      // the avatar actually rested (see below) -- deterministic regardless
      // of the placement engine's exact numbers (footprint, verticalReserve,
      // bubble content height), unlike a widget positioned at a hardcoded
      // guess of where the default corner "should" be.
      final blockRect = ValueNotifier<Rect?>(null);
      addTearDown(blockRect.dispose);
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => _ToggleableBottomRightBlock(blockRect: blockRect),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [child!, IveOverlay(navigatorKey: navigatorKey)],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      final restRect = tester.getRect(avatarFinder);
      blockRect.value = restRect.inflate(24);

      // Turn the block on — it covers exactly the zone the avatar was just
      // resting in (essential-content stand-in, e.g. Action Engine's
      // "Concluir" or Dashboard's "Campanhas" card).
      await tester.tap(find.text('toggle block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // IveExclusionRegion only publishes its geometry post-frame.
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'mounting an IveExclusionRegion mid-tree must never throw '
              '(same lifecycle-safety class as the build-phase-mutation crash fixed earlier this session)');

      final blockedRect = tester.getRect(avatarFinder);
      expect(blockedRect, isNot(equals(restRect)),
          reason: 'avatar must move away from the now-blocked corner it was resting in');
      final blockFinder = find.byKey(const ValueKey('ive-test-block'));
      expect(tester.getRect(blockFinder).overlaps(blockedRect), isFalse,
          reason: 'must not rest on top of the newly-registered exclusion region');

      // Turn the block back off. The avatar's current spot is already safe
      // (no exclusions left at all) -- continuity means it stays exactly
      // there rather than springing back to the original corner. This is
      // the engine's deliberate anti-jitter behavior (mission Section 3/4:
      // "evitar movimento visual constante"; also covered at the pure
      // computeRestingPosition level by the "previous position preserved
      // when still safe" unit test), not a missed return-to-origin.
      await tester.tap(find.text('toggle block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'unmounting (disposing) an IveExclusionRegion must never throw either');
      final freedRect = tester.getRect(avatarFinder);
      expect(freedRect, equals(blockedRect),
          reason: 'no exclusions left -> the already-safe position is kept as-is, no jitter');
    },
  );

  // O — mission Section 6 ("re-validar ao final do drag"): a manual drag is
  // never fought mid-gesture (the engine is skipped entirely while
  // `_dragging`), but once released, a drop directly onto a registered
  // exclusion region must be corrected rather than left stuck there
  // permanently blocking essential content.
  testWidgets(
    'O. drop do drag exatamente sobre uma exclusion region: reposicionado ao soltar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: IveExclusionRegion(
                  key: ValueKey('ive-test-drop-target'),
                  child: SizedBox(width: 120, height: 120),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [child!, IveOverlay(navigatorKey: navigatorKey)],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(); // let the region's post-frame geometry publish land

      final avatarFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );
      final dropTarget = tester.getRect(find.byKey(const ValueKey('ive-test-drop-target')));

      // Drag the avatar from its resting corner to the center of the
      // exclusion region and release it there.
      final start = tester.getCenter(avatarFinder);
      final gesture = await tester.startGesture(start);
      await gesture.moveTo(dropTarget.center);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final finalRect = tester.getRect(avatarFinder);
      expect(finalRect.overlaps(dropTarget), isFalse,
          reason: 'dropped directly onto essential content -- must be corrected on release, '
              'not left permanently blocking it');
    },
  );

  // ── IVE Full-Footprint Collision Closure (COMMERCIAL-EXPERIENCE-CLOSURE-17A) ──
  // P-R below exercise the Codex final-audit P1 fix: "avatar safe" is not
  // the same as "the whole visible IVE is safe" (bubble/actions were
  // previously excluded from collision testing entirely). These focus on
  // what only a real widget tree with a real IveState/bubble can prove;
  // the underlying placement ALGORITHM's own edge cases (multiple
  // exclusions, no-perfect-candidate, viewport clamp, safeArea, small
  // viewport) are already exhaustively covered at the pure
  // computeRestingPosition level in ive_placement_engine_test.dart --
  // footprint is just a Size there, so those don't need duplicating for
  // an avatar+bubble-shaped Size specifically.

  Finder bubbleFinder() =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_IveBubble');

  Finder avatarFinder() => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'IVE, assistente executiva',
      );

  testWidgets(
    'P. bolha visível: "avatar seguro" não implica "IVE seguro" -- uma exclusion '
    'region coberta apenas pela bolha (não pelo avatar 56x56) também força o '
    'reposicionamento (Codex final audit, full-footprint fix)',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final blockRect = ValueNotifier<Rect?>(null);
      addTearDown(blockRect.dispose);
      final shortBubbleState =
          IveState(bubbleVisible: true, message: 'Oi!', activeIssue: _testIssue());

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => _ToggleableBottomRightBlock(blockRect: blockRect),
          ),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
          iveProvider.overrideWith((ref) => _FixedIveNotifier(ref, shortBubbleState)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [child!, IveOverlay(navigatorKey: navigatorKey)],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(); // let the bubble's own post-frame measurement land

      expect(avatarFinder(), findsOneWidget);
      expect(bubbleFinder(), findsOneWidget);

      final avatarRect = tester.getRect(avatarFinder());
      final bubbleRect = tester.getRect(bubbleFinder());
      // Sanity: the bubble must genuinely sit apart from the avatar's own
      // box, above it -- otherwise this test isn't exercising what it
      // claims to.
      expect(bubbleRect.top, lessThan(avatarRect.top));

      // Register a block over exactly where the BUBBLE sits, deliberately
      // NOT covering the avatar's own 56x56 rect.
      blockRect.value = bubbleRect.inflate(4);
      await tester.tap(find.text('toggle block'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final newBubbleRect = tester.getRect(bubbleFinder());
      final newAvatarRect = tester.getRect(avatarFinder());
      final blockActualRect = tester.getRect(find.byKey(const ValueKey('ive-test-block')));

      expect(blockActualRect.overlaps(newBubbleRect), isFalse,
          reason: 'the bubble itself -- not just the 56x56 avatar -- must steer clear of '
              'a registered exclusion region; the pre-fix engine only ever tested the '
              'avatar-sized footprint, so a block positioned exactly like this one would '
              'have been incorrectly accepted as safe');
      expect(blockActualRect.overlaps(newAvatarRect), isFalse);
    },
  );

  testWidgets(
    'Q. bolha desaparece: a posição permanece estável (sem jitter) quando o mesmo '
    'canto continua seguro só com o footprint do avatar',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      _FixedIveNotifier? notifier;
      final withBubble = IveState(
          bubbleVisible: true, message: 'Uma mensagem qualquer.', activeIssue: _testIssue());

      final router = GoRouter(
        navigatorKey: navigatorKey,
        initialLocation: '/',
        observers: [IveRouteObserver()],
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
        ],
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
          iveProvider.overrideWith((ref) {
            notifier = _FixedIveNotifier(ref, withBubble);
            return notifier!;
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Stack(
            children: [child!, IveOverlay(navigatorKey: navigatorKey)],
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      final withBubbleRect = tester.getRect(avatarFinder());

      // message and activeIssue both kept identical, only bubbleVisible
      // flips: the bubble is ALWAYS laid out (just invisible -- see
      // IgnorePointer/AnimatedOpacity in ive_overlay.dart), so keeping its
      // content the same isolates "did closing the bubble alone move the
      // avatar" from "did the content changing size also move it" (a
      // different, and separately valid, concern). Also avoids the same
      // test-binding-only CTA-Row overflow artifact `_testIssue`'s own
      // doc comment explains, which an empty message would otherwise
      // still hit via that unrelated branch.
      notifier!.updateForTest(withBubble.copyWith(bubbleVisible: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(tester.takeException(), isNull);
      final withoutBubbleRect = tester.getRect(avatarFinder());
      expect(withoutBubbleRect, equals(withBubbleRect),
          reason: 'continuity: the corner the bubble+avatar rested in is still safe using '
              'just the avatar footprint alone, so it must not jump/spring anywhere once '
              'the bubble closes -- same anti-jitter guarantee the pure engine tests '
              'already prove at the algorithm level, now confirmed through the real '
              'bubble-visibility transition');
    },
  );

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A -- PT and EN each get their own
  // testWidgets (not a loop reusing one `tester`): pumpWidget with a
  // structurally-similar tree updates the existing Element/State in place
  // rather than a clean remount, which risked the second iteration
  // observing state left over from the first.
  Future<void> expectBoundedBubble(WidgetTester tester, String message) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigatorKey = GlobalKey<NavigatorState>();
    final longState =
        IveState(bubbleVisible: true, message: message, activeIssue: _testIssue());

    final router = GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      observers: [IveRouteObserver()],
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SizedBox.shrink())),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
        currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
        authStateProvider.overrideWith((ref) => Stream.value(_authState(session: MockSession()))),
        iveProvider.overrideWith((ref) => _FixedIveNotifier(ref, longState)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Stack(
          children: [child!, IveOverlay(navigatorKey: navigatorKey)],
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'message: $message');

    // `find.byType(RichText)` alone would also match the plain `Text`
    // widgets used elsewhere in the bubble (e.g. the issue-action chip's
    // label -- `Text` builds a RichText internally too), so this matches
    // specifically on the message's own content.
    final richTextFinder = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(message),
    );
    expect(richTextFinder, findsOneWidget, reason: 'message: $message');
    final richText = tester.widget<RichText>(richTextFinder);
    expect(richText.maxLines, 5, reason: 'message: $message');

    final bubbleRect = tester.getRect(bubbleFinder());
    expect(bubbleRect.height, lessThan(260),
        reason: 'message: $message -- bounded by maxLines: 5, must not grow unbounded '
            'regardless of message length');

    final avatarRect = tester.getRect(avatarFinder());
    expect(avatarRect.bottom, lessThanOrEqualTo(800.5), reason: 'message: $message');
    expect(avatarRect.top, greaterThanOrEqualTo(-0.5), reason: 'message: $message');
  }

  testWidgets(
    'R1. mensagem longa em português permanece com altura limitada (maxLines: 5) e a '
    'IVE inteira nunca lança exceção nem sai da viewport',
    (tester) => expectBoundedBubble(
      tester,
      'Esta é uma mensagem deliberadamente muito longa em português, escrita com '
      'várias frases adicionais, para garantir que o texto ultrapasse as cinco '
      'linhas visuais permitidas pela bolha da IVE em qualquer largura de tela '
      'razoável, testando assim se o limite realmente contém a altura.',
    ),
  );

  testWidgets(
    'R2. long message in English stays height-bounded (maxLines: 5) and the whole '
    'IVE never throws or leaves the viewport',
    (tester) => expectBoundedBubble(
      tester,
      'This is a deliberately very long message in English, written with several '
      'additional sentences, to make sure the text goes past the five visual lines '
      'the IVE bubble allows at any reasonable screen width, testing whether the '
      'bound genuinely contains the height.',
    ),
  );
}

class _ToggleableBottomRightBlock extends StatefulWidget {
  const _ToggleableBottomRightBlock({required this.blockRect});

  /// Set by the test, after the first render, to wherever the avatar
  /// actually rested -- not a hardcoded guess -- so the block is
  /// guaranteed to cover it regardless of the placement engine's exact
  /// numbers.
  final ValueListenable<Rect?> blockRect;

  @override
  State<_ToggleableBottomRightBlock> createState() => _ToggleableBottomRightBlockState();
}

class _ToggleableBottomRightBlockState extends State<_ToggleableBottomRightBlock> {
  bool _blocked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<Rect?>(
        valueListenable: widget.blockRect,
        builder: (context, rect, _) => Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: () => setState(() => _blocked = !_blocked),
                child: const Text('toggle block'),
              ),
            ),
            if (_blocked && rect != null)
              Positioned.fromRect(
                rect: rect,
                child: const IveExclusionRegion(
                  key: ValueKey('ive-test-block'),
                  child: SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FixedIveNotifier extends IveNotifier {
  _FixedIveNotifier(super.ref, IveState fixed) {
    state = fixed;
  }

  // COMMERCIAL-EXPERIENCE-CLOSURE-17A — lets a test change the bubble's
  // visibility/content mid-test (e.g. "bubble disappears") without
  // needing a second pumpWidget. `state =` is only accessible from within
  // IveNotifier's own class hierarchy (StateNotifier.state is @protected),
  // which this method satisfies since it's defined here.
  void updateForTest(IveState next) => state = next;
}
