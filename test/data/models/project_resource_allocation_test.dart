import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/project_resource_allocation.dart';

void main() {
  // ── ProjectResourceAllocation.empty / fromMap / toUpsertMap ────────────────
  group('ProjectResourceAllocation', () {
    test('empty() é o estado zero para um projeto sem alocação salva', () {
      final a = ProjectResourceAllocation.empty('p1');
      expect(a.projectId, 'p1');
      expect(a.hoursAllocated, 0);
      expect(a.budgetAllocatedCents, 0);
      expect(a.currency, 'BRL');
    });

    test('fromMap/toUpsertMap fazem round-trip dos campos persistidos', () {
      final map = {
        'project_id': 'p1',
        'hours_allocated': 40,
        'budget_allocated_cents': 150000,
        'currency': 'USD',
        'updated_at': '2026-09-14T10:00:00Z',
      };
      final a = ProjectResourceAllocation.fromMap(map);
      expect(a.hoursAllocated, 40);
      expect(a.budgetAllocatedCents, 150000);
      expect(a.currency, 'USD');

      final upsert = a.toUpsertMap();
      expect(upsert['project_id'], 'p1');
      expect(upsert['hours_allocated'], 40);
      expect(upsert['budget_allocated_cents'], 150000);
      expect(upsert['currency'], 'USD');
      // updated_at nunca é enviado pelo cliente — o trigger da migration
      // é a fonte de verdade (mission Section 09).
      expect(upsert.containsKey('updated_at'), isFalse);
    });

    test('budgetAllocatedDisplay converte cents para valor decimal exato', () {
      final a = ProjectResourceAllocation.empty('p1').copyWith(budgetAllocatedCents: 123456);
      expect(a.budgetAllocatedDisplay, 1234.56);
    });

    test('copyWith preserva projectId/updatedAt quando não sobrescritos', () {
      final a = ProjectResourceAllocation.empty('p1');
      final updated = a.copyWith(hoursAllocated: 10);
      expect(updated.projectId, 'p1');
      expect(updated.updatedAt, a.updatedAt);
      expect(updated.hoursAllocated, 10);
      expect(updated.budgetAllocatedCents, 0);
    });
  });

  // ── validateHoursAllocated — Section 11: não-negativo, limite superior ─────
  group('validateHoursAllocated', () {
    test('aceita zero e valores dentro do limite', () {
      expect(validateHoursAllocated(0), isNull);
      expect(validateHoursAllocated(100000), isNull);
      expect(validateHoursAllocated(40), isNull);
    });

    test('rejeita negativo', () {
      expect(validateHoursAllocated(-1), isNotNull);
    });

    test('rejeita acima do limite máximo', () {
      expect(validateHoursAllocated(100001), isNotNull);
    });
  });

  // ── validateBudgetAllocatedCents ────────────────────────────────────────────
  group('validateBudgetAllocatedCents', () {
    test('aceita zero e valores positivos', () {
      expect(validateBudgetAllocatedCents(0), isNull);
      expect(validateBudgetAllocatedCents(999999), isNull);
    });

    test('rejeita negativo', () {
      expect(validateBudgetAllocatedCents(-1), isNotNull);
    });

    test('rejeita acima do limite máximo (Codex Gate 1 P2)', () {
      expect(
        validateBudgetAllocatedCents(ProjectResourceAllocation.maxBudgetAllocatedCents),
        isNull,
      );
      expect(
        validateBudgetAllocatedCents(ProjectResourceAllocation.maxBudgetAllocatedCents + 1),
        isNotNull,
      );
    });
  });

  // ── parseMoneyInputToCents — Section 10: nunca via double intermediário ────
  group('parseMoneyInputToCents', () {
    test('converte valor com duas casas decimais exatamente', () {
      expect(parseMoneyInputToCents('1234.56'), 123456);
    });

    test('aceita vírgula como separador decimal', () {
      expect(parseMoneyInputToCents('10,10'), 1010);
    });

    test('não sofre o erro clássico de ponto-flutuante para valores como 10.10', () {
      // O parser nunca passa pelo intermediário double — compara dígito a
      // dígito via regex, então produz exatamente 1010, nunca 1009 ou 1011
      // por causa de arredondamento binário.
      expect(parseMoneyInputToCents('10.10'), 1010);
      expect(parseMoneyInputToCents('0.10'), 10);
      expect(parseMoneyInputToCents('19.99'), 1999);
    });

    test('preenche uma casa decimal faltante', () {
      expect(parseMoneyInputToCents('5.5'), 550);
    });

    test('aceita valor inteiro sem parte decimal', () {
      expect(parseMoneyInputToCents('200'), 20000);
    });

    test('string vazia retorna zero', () {
      expect(parseMoneyInputToCents(''), 0);
      expect(parseMoneyInputToCents('   '), 0);
    });

    test('rejeita entrada inválida retornando null', () {
      expect(parseMoneyInputToCents('abc'), isNull);
      expect(parseMoneyInputToCents('-10'), isNull);
      expect(parseMoneyInputToCents('10.999'), isNull);
      expect(parseMoneyInputToCents('R\$ 10'), isNull);
      expect(parseMoneyInputToCents('1e10'), isNull);
    });

    test(
      'Codex Gate 1 P2 — aplica um limite máximo em vez de deixar '
      'int.parse/aritmética estourar em entrada arbitrariamente grande',
      () {
        // No limite exato: aceito.
        expect(
          parseMoneyInputToCents('9999999999.99'),
          ProjectResourceAllocation.maxBudgetAllocatedCents,
        );
        // Um dígito acima do limite de dígitos da parte inteira: rejeitado
        // pela própria regex (nunca chega a int.parse).
        expect(parseMoneyInputToCents('1${'0' * 12}'), isNull); // 13 dígitos
        // Uma string de centenas de dígitos — o caso que antes não tinha
        // limite nenhum antes de int.parse — também é rejeitada com
        // segurança, sem lançar exceção.
        expect(() => parseMoneyInputToCents('9' * 300), returnsNormally);
        expect(parseMoneyInputToCents('9' * 300), isNull);
      },
    );
  });
}
