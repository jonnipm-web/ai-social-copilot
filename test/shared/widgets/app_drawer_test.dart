import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/diagnostics/diagnostic_logger_service.dart';
import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/data/models/profile.dart';
import 'package:ai_social_copilot/l10n/app_localizations.dart';
import 'package:ai_social_copilot/providers/auth_provider.dart';
import 'package:ai_social_copilot/providers/diagnostic_session_provider.dart';
import 'package:ai_social_copilot/providers/profile_provider.dart';
import 'package:ai_social_copilot/shared/widgets/app_drawer.dart';

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

AuthState _authState() => AuthState(AuthChangeEvent.signedIn, MockSession());

// IVE-COMMERCIAL-FOUNDATION-11 — covers the "Planos/Plano" drawer
// duplicate fix (docs/commercial/MODULE_LIFECYCLE_MATRIX.md §3) and, per
// Codex adversarial review (Architecture-10 mission, round 1, P2,
// ACCEPTED), a coverage test for app_drawer.dart's separately-maintained
// icon map so a future commercially-enabled module doesn't silently fall
// back to a generic icon.
void main() {
  group('visibleDrawerModules — Planos/Plano duplicate fix', () {
    test('nenhum módulo do loop do registro aponta para routeUpgrade', () {
      for (final isAdmin in [false, true]) {
        for (final isPro in [false, true]) {
          final visible = visibleDrawerModules(isAdmin: isAdmin, isPro: isPro);
          expect(
            visible.where((m) => m.route == AppConstants.routeUpgrade),
            isEmpty,
            reason: 'routeUpgrade deve aparecer apenas via o item fixo '
                '"Plano / Upgrade", nunca via o loop do registro '
                '(isAdmin=$isAdmin, isPro=$isPro)',
          );
        }
      }
    });

    test(
      'o módulo plans-upgrade realmente existe no registro '
      '(prova que a exclusão não é vazia/sem efeito)',
      () {
        final planUpgradeEntries =
            kModuleRegistry.where((m) => m.route == AppConstants.routeUpgrade);
        expect(
          planUpgradeEntries,
          isNotEmpty,
          reason: 'se este teste falhar porque o módulo foi removido do '
              'registro, o teste acima perde sentido (estaria testando '
              'uma exclusão que não exclui nada) — revisar junto.',
        );
      },
    );
  });

  group('drawerIconFor — cobertura de ícones (Codex round 1, P2)', () {
    test(
      'todo módulo que pode aparecer na gaveta (commercialEnabled + com rota) '
      'tem um ícone dedicado, não o fallback genérico',
      () {
        // União da visibilidade em todas as combinações de plano/admin —
        // qualquer módulo que possa aparecer para QUALQUER usuário real
        // deve ter um ícone próprio.
        final everCommerciallyVisible = kModuleRegistry.where((m) {
          if (m.route == null) return false;
          if (m.route == AppConstants.routeUpgrade) return false;
          if (!m.commercialEnabled) return false;
          return m.visibleFor(isAdmin: false, isPro: false) ||
              m.visibleFor(isAdmin: false, isPro: true);
        }).toList();

        final missingIcon = everCommerciallyVisible
            .where((m) => drawerIconFor(m.moduleId) == Icons.circle_outlined)
            .map((m) => m.moduleId)
            .toList();

        expect(
          missingIcon,
          isEmpty,
          reason: 'módulo(s) comercialmente visíveis sem ícone dedicado em '
              'drawerIconFor: $missingIcon — adicione uma entrada no mapa '
              'de ícones de app_drawer.dart junto com qualquer novo módulo '
              'comercial.',
        );
      },
    );
  });

  // COMMERCIAL-EXPERIENCE-CLOSURE-16 (mission Section 27/35) — regression
  // test for a real bug found during this mission's physical Android E2E
  // (Samsung SM-S938B, Android 16): opening "Conta e Configurações" from
  // the drawer left Navigator.canPop() false (drawer used context.go(),
  // which replaces GoRouter's whole route stack), so the AppBar showed no
  // back arrow and the system back button closed the app instead of
  // returning to the previous screen.
  group('drawer settings-style items push (Section 27/35 — Android back regression)', () {
    Widget harness() {
      final router = GoRouter(
        initialLocation: AppConstants.routeHome,
        routes: [
          GoRoute(
            path: AppConstants.routeHome,
            builder: (_, __) => Scaffold(
              appBar: AppBar(title: const Text('Home')),
              drawer: const AppDrawer(),
              body: const Center(child: Text('home body')),
            ),
          ),
          GoRoute(
            path: AppConstants.routeAccount,
            builder: (context, __) => Scaffold(
              appBar: AppBar(), // auto back arrow iff Navigator.canPop(context)
              body: Center(child: Text('canPop=${Navigator.canPop(context)}')),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          diagnosticLoggerProvider.overrideWithValue(MockDiagnosticLoggerService()),
          currentProfileProvider.overrideWith((ref) async => _fakeProfile()),
          authStateProvider.overrideWith((ref) => Stream.value(_authState())),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
    }

    testWidgets('opening "Conta e Configurações" from the drawer leaves a poppable back-stack entry', (tester) async {
      // Tall enough that the drawer's full item list (7 modules + 5 fixed
      // items) actually lays out -- the default ~800x600 test surface is
      // too short, and a Sliver-based ListView never builds items outside
      // its viewport, which is what made the Account item unreachable
      // when this test was first written against the default size.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pump();
      // Let currentProfileProvider's FutureProvider resolve before opening
      // the drawer -- AppDrawer shows only a loading spinner until then.
      await tester.pump(const Duration(milliseconds: 50));

      // Open the drawer, then tap the Account item.
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
      await tester.tap(find.text(l10n.navAccount));
      await tester.pumpAndSettle();

      // The screen's own build() reads Navigator.canPop(context) --
      // before this fix this rendered "canPop=false" (drawer used
      // context.go()); after the fix it must be true (context.push()).
      expect(find.text('canPop=true'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
