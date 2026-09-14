import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';

// IVE-COMMERCIAL-FOUNDATION-11 — covers selectProjectFocus(), the pure
// function extracted from iveContextDataProvider specifically so the
// Project Context Contract's central guarantee is testable without
// mocking the whole ecosystem-provider chain (same convention already
// used by ive_context_provider_test.dart for selectKnowledgeForGrounding
// — see that file's own scope note).
//
// This guards the root-cause bug documented in docs/commercial/
// PROJECT_CONTEXT_CONTRACT.md: before this mission, iveContextDataProvider
// ALWAYS computed "the project" as whichever project had the highest
// ecosystem score system-wide, regardless of which project the caller
// actually meant. selectProjectFocus is the fix: given an explicit
// projectId, it must return THAT project — never silently substitute
// the top-scored one — and must fail safe (not crash, not leak) when the
// requested project can't be found.

Project _project(String id, String name) => Project(
      id: id,
      userId: 'user-1',
      name: name,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

EcosystemScore _score(String id, String name, int ecosystemScore) => EcosystemScore(
      project: _project(id, name),
      opportunityScore: 0,
      strategicFit: 0,
      synergyScore: 0,
      roiScore: 0,
      momentumScore: 0,
      ecosystemScore: ecosystemScore,
      recommendation: 'MANTER',
      strengths: const [],
      risks: const [],
      quickWins: const [],
      totalRoi: 0,
      actionCount: 0,
      completedActions: 0,
      labItemCount: 0,
    );

void main() {
  group('selectProjectFocus', () {
    test('Projeto A explícito retorna o contexto do Projeto A, não o de maior score', () {
      final scores = [
        _score('project-a', 'Projeto A', 20), // menor score
        _score('project-b', 'Projeto B', 90), // maior score do sistema
      ];

      final result = selectProjectFocus(scores, 'project-a');

      expect(result.unavailable, isFalse);
      expect(result.focus?.project.id, 'project-a');
      // Regressão central: NÃO deve retornar o Projeto B só porque ele
      // tem o maior score do sistema todo.
      expect(result.focus?.project.id, isNot('project-b'));
    });

    test('trocar de Projeto A para Projeto B retorna o contexto de B, sem vazamento de A', () {
      final scores = [
        _score('project-a', 'Projeto A', 50),
        _score('project-b', 'Projeto B', 10),
      ];

      final resultA = selectProjectFocus(scores, 'project-a');
      final resultB = selectProjectFocus(scores, 'project-b');

      expect(resultA.focus?.project.id, 'project-a');
      expect(resultB.focus?.project.id, 'project-b');
      // As duas chamadas são independentes — nenhum estado do projeto A
      // vaza para o resultado do projeto B.
      expect(resultB.focus?.project.name, isNot(resultA.focus?.project.name));
    });

    test('projectId null preserva o comportamento ecosystem-wide original (maior score)', () {
      final scores = [
        _score('project-a', 'Projeto A', 20),
        _score('project-b', 'Projeto B', 90),
        _score('project-c', 'Projeto C', 55),
      ];

      final result = selectProjectFocus(scores, null);

      expect(result.unavailable, isFalse);
      expect(result.focus?.project.id, 'project-b');
    });

    test('projeto pedido não encontrado falha seguro — NUNCA cai para o de maior score', () {
      final scores = [
        _score('project-b', 'Projeto B', 90),
        _score('project-c', 'Projeto C', 70),
      ];

      final result = selectProjectFocus(scores, 'project-deleted');

      expect(result.unavailable, isTrue);
      expect(result.focus, isNull);
    });

    test('lista de scores vazia com projectId null retorna foco nulo, não erro', () {
      final result = selectProjectFocus(const [], null);
      expect(result.unavailable, isFalse);
      expect(result.focus, isNull);
    });

    test('lista de scores vazia com projectId explícito é "não encontrado", não "sem projeto"', () {
      final result = selectProjectFocus(const [], 'project-a');
      expect(result.unavailable, isTrue);
      expect(result.focus, isNull);
    });
  });

  group('selectEcosystemWideFields (Codex Gate 1, round 1, P1 — regressão)', () {
    test(
      'com projectId explícito, topProjectsSnapshot e bottleneck NÃO vazam '
      'dados de outros projetos — ficam vazios/nulos',
      () {
        final scores = [
          _score('project-a', 'Projeto A', 20),
          _score('project-b', 'Projeto B', 90), // maior score do sistema
          _score('project-c', 'Projeto C', 5),
        ];

        final result = selectEcosystemWideFields(scores, 'project-a');

        expect(result.topProjectsSnapshot, isEmpty);
        expect(result.bottleneck, isNull);
        // Regressão central: nem "Projeto B" (maior score) nem "Projeto C"
        // (pior execução) devem aparecer em NENHUM campo quando a
        // interação é sobre o Projeto A.
      },
    );

    test('com projectId null, preserva o resumo ecosystem-wide original (top 3 + gargalo)', () {
      final scores = [
        _score('project-a', 'Projeto A', 20),
        _score('project-b', 'Projeto B', 90),
        _score('project-c', 'Projeto C', 55),
      ];

      final result = selectEcosystemWideFields(scores, null);

      expect(result.topProjectsSnapshot, hasLength(3));
      expect(result.topProjectsSnapshot.first['name'], 'Projeto B');
      expect(result.bottleneck, isNotNull);
    });
  });

  group('selectPendingOpportunitiesCount (Codex Gate 2, round 2 — regressão)', () {
    test('com projectId explícito, usa a contagem escopada, não a global', () {
      final result = selectPendingOpportunitiesCount(
        projectId: 'project-a',
        scopedPendingCount: 2,
        globalPendingCount: 50, // agregado de TODOS os projetos do usuário
      );
      expect(result, 2);
    });

    test('com projectId null, preserva a contagem global original', () {
      final result = selectPendingOpportunitiesCount(
        projectId: null,
        scopedPendingCount: 2,
        globalPendingCount: 50,
      );
      expect(result, 50);
    });
  });
}
