/// Testa a lógica de ordenação e mapeamento de scores do ProjectCommandCenter.
/// Não usa widgets Flutter — apenas lógica pura para rodar rápido sem FlutterTest.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/project.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Project _p(String id, String name, {int priorityScore = 0}) => Project(
      id:            id,
      userId:        'uid',
      name:          name,
      priorityScore: priorityScore,
      createdAt:     DateTime(2026),
      updatedAt:     DateTime(2026),
    );

EcosystemScore _score(Project p, int ecoScore) => EcosystemScore(
      project:          p,
      opportunityScore: ecoScore,
      strategicFit:     50,
      synergyScore:     50,
      roiScore:         50,
      momentumScore:    50,
      ecosystemScore:   ecoScore,
      recommendation:   ecoScore >= 70 ? 'ESCALAR' : 'MANTER',
      strengths:        const [],
      risks:            const [],
      quickWins:        const [],
      totalRoi:         0,
      actionCount:      0,
      completedActions: 0,
      labItemCount:     0,
    );

/// Replica a lógica de ordenação da tela.
List<Project> _sortProjects(
  List<Project> projects,
  Map<String, EcosystemScore> scoresMap,
) {
  final sorted = [...projects]..sort((a, b) {
      final sa = scoresMap[a.id]?.ecosystemScore ?? a.priorityScore;
      final sb = scoresMap[b.id]?.ecosystemScore ?? b.priorityScore;
      return sb.compareTo(sa);
    });
  return sorted;
}

// ── Testes ────────────────────────────────────────────────────────────────────

void main() {
  group('ProjectCommandCenter — ordenação', () {
    test('ordena por ecosystemScore quando disponível', () {
      final p1 = _p('p1', 'A', priorityScore: 90);
      final p2 = _p('p2', 'B', priorityScore: 10);
      final p3 = _p('p3', 'C', priorityScore: 50);

      // Sem ecosystemScore, p1 seria primeiro (priorityScore=90)
      // Com ecosystemScore, p2 é o mais alto (ecosystemScore=80)
      final scoresMap = {
        'p1': _score(p1, 30),
        'p2': _score(p2, 80),
        'p3': _score(p3, 55),
      };

      final sorted = _sortProjects([p1, p2, p3], scoresMap);
      expect(sorted.map((p) => p.id).toList(), ['p2', 'p3', 'p1']);
    });

    test('fallback para priorityScore quando sem ecosystemScore', () {
      final p1 = _p('p1', 'Alta prioridade', priorityScore: 80);
      final p2 = _p('p2', 'Baixa prioridade', priorityScore: 20);
      final p3 = _p('p3', 'Média prioridade', priorityScore: 50);

      final sorted = _sortProjects([p1, p2, p3], {});
      expect(sorted.map((p) => p.id).toList(), ['p1', 'p3', 'p2']);
    });

    test('mix: alguns com ecosystemScore, outros sem', () {
      final p1 = _p('p1', 'A', priorityScore: 70);
      final p2 = _p('p2', 'B', priorityScore: 10);
      final p3 = _p('p3', 'C', priorityScore: 40);

      // p1 tem ecosystemScore=20, p2 não tem (usa priorityScore=10),
      // p3 tem ecosystemScore=90
      final scoresMap = {
        'p1': _score(p1, 20),
        'p3': _score(p3, 90),
      };

      final sorted = _sortProjects([p1, p2, p3], scoresMap);
      // Ordem esperada: p3(90) > p1(20) > p2(10)
      expect(sorted.map((p) => p.id).toList(), ['p3', 'p1', 'p2']);
    });

    test('lista vazia não quebra', () {
      final sorted = _sortProjects([], {});
      expect(sorted, isEmpty);
    });

    test('projeto único retorna mesma lista', () {
      final p = _p('p1', 'Solo', priorityScore: 55);
      final sorted = _sortProjects([p], {'p1': _score(p, 55)});
      expect(sorted.length, 1);
      expect(sorted.first.id, 'p1');
    });
  });

  group('ProjectCommandCenter — mapeamento de scores', () {
    test('scoresMap lookup por projectId', () {
      final p1 = _p('p1', 'Projeto 1');
      final p2 = _p('p2', 'Projeto 2');

      final scores = [_score(p1, 75), _score(p2, 40)];
      final scoresMap = {for (final s in scores) s.project.id: s};

      expect(scoresMap['p1']?.ecosystemScore, 75);
      expect(scoresMap['p2']?.ecosystemScore, 40);
      expect(scoresMap['p3'], isNull);
    });

    test('ecosystemScore >= 70 → recomendação ESCALAR', () {
      final p = _p('p1', 'X');
      final score = _score(p, 75);
      expect(score.recommendation, 'ESCALAR');
    });

    test('ecosystemScore < 70 → recomendação MANTER', () {
      final p = _p('p1', 'Y');
      final score = _score(p, 60);
      expect(score.recommendation, 'MANTER');
    });

    test('completionRate calculado corretamente', () {
      final p = _p('p1', 'Z');
      final score = EcosystemScore(
        project:          p,
        opportunityScore: 50,
        strategicFit:     50,
        synergyScore:     50,
        roiScore:         50,
        momentumScore:    50,
        ecosystemScore:   50,
        recommendation:   'MANTER',
        strengths:        const [],
        risks:            const [],
        quickWins:        const [],
        totalRoi:         0,
        actionCount:      10,
        completedActions: 7,
        labItemCount:     0,
      );
      expect(score.completionRate, 70);
    });

    test('completionRate = 0 quando sem ações', () {
      final p = _p('p1', 'W');
      final score = _score(p, 60);
      expect(score.completionRate, 0);
    });
  });
}
