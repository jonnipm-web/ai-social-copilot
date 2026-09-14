import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/core/constants/app_constants.dart';
import 'package:ai_social_copilot/core/modules/module_registry.dart';
import 'package:ai_social_copilot/shared/widgets/app_drawer.dart';

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
}
