import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/ecosystem_score.dart';
import 'package:ai_social_copilot/data/models/knowledge_item.dart';
import 'package:ai_social_copilot/data/models/project.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';

// ── IVE-COMMERCIAL-TARGETED-REMEDIATION-04 ──────────────────────────────────
// Covers selectKnowledgeForGrounding(), the pure function extracted from
// iveContextDataProvider specifically so this project-isolation guarantee is
// testable without mocking the Supabase-backed provider chain (that chain
// stays out of the automated suite per this repo's existing convention --
// see test/data/models/copilot_context_data_test.dart's own scope note).
//
// Regression this guards: the previous inline logic
// (`projectItems.isNotEmpty ? projectItems : knowledgeRaw`) fell back to
// EVERY knowledge item the user owns -- across ALL of their projects --
// whenever the active project had zero linked items, leaking Project B's
// knowledge into Project A's IVE grounding. Codex's adversarial review
// flagged this as P1 against this mission's own acceptance criterion
// ("Project B knowledge -> not leaked into Project A").

KnowledgeItem _item({required String id, String? projectId}) {
  final now = DateTime(2026, 1, 1);
  return KnowledgeItem(
    id:        id,
    userId:    'user-1',
    projectId: projectId,
    title:     'Item $id',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('selectKnowledgeForGrounding', () {
    test('sem projeto ativo, retorna todo o conhecimento do usuário', () {
      final all = [
        _item(id: '1', projectId: 'project-a'),
        _item(id: '2', projectId: 'project-b'),
        _item(id: '3'),
      ];
      final result = selectKnowledgeForGrounding(all, null);
      expect(result, hasLength(3));
    });

    test('com projeto ativo, retorna apenas itens vinculados a esse projeto', () {
      final all = [
        _item(id: '1', projectId: 'project-a'),
        _item(id: '2', projectId: 'project-b'),
      ];
      final result = selectKnowledgeForGrounding(all, 'project-a');
      expect(result, hasLength(1));
      expect(result.single.id, '1');
    });

    // Este é o teste de regressão central: o bug corrigido caía de volta em
    // `all` (vazando Projeto B) quando o Projeto A não tinha nada vinculado.
    test(
      'com projeto ativo sem nenhum item vinculado, NÃO vaza conhecimento de outros projetos',
      () {
        final all = [
          _item(id: '1', projectId: 'project-b'),
          _item(id: '2', projectId: 'project-c'),
        ];
        final result = selectKnowledgeForGrounding(all, 'project-a');
        expect(result, isEmpty);
      },
    );

    test('lista vazia de entrada retorna lista vazia independentemente do projeto', () {
      expect(selectKnowledgeForGrounding(<KnowledgeItem>[], 'project-a'), isEmpty);
      expect(selectKnowledgeForGrounding(<KnowledgeItem>[], null), isEmpty);
    });
  });

  // ── selectEcosystemAlert — IVE-EXPERIENCE-V1-06QA (live-QA defect) ──────────
  // Regressão central: ecosystemHealthProvider devolve 0 quando `scores` está
  // vazio (nenhum dado carregado — inclusive a janela pré-autenticação em que
  // uma consulta protegida por RLS retorna lista vazia). Antes desta correção,
  // esse 0 virava a alegação textual "Saúde do ecossistema em 0/100. Ação
  // imediata recomendada." — um diagnóstico real sobre um usuário para o qual
  // não existe nenhum dado autorizado. UNKNOWN != ZERO.
  group('selectEcosystemAlert', () {
    Project buildProject({String id = 'p1'}) => Project(
          id: id,
          userId: 'user-1',
          name: 'Projeto $id',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    EcosystemScore buildScore({required String projectId, required int ecosystemScore}) => EcosystemScore(
          project: buildProject(id: projectId),
          opportunityScore: 0,
          strategicFit: 0,
          synergyScore: 0,
          roiScore: 0,
          momentumScore: 0,
          ecosystemScore: ecosystemScore,
          recommendation: '',
          strengths: const [],
          risks: const [],
          quickWins: const [],
          totalRoi: 0,
          actionCount: 0,
          completedActions: 0,
          labItemCount: 0,
        );

    ActionQueueItem buildAction({String id = 'a1'}) => ActionQueueItem(
          id: id,
          userId: 'user-1',
          title: 'Ação $id',
          createdAt: DateTime(2026, 1, 1),
        );

    // Teste E — a regressão exata reportada pelo dono: sem projetos
    // carregados (pré-autenticação, RLS vazio, ou usuário genuinamente novo
    // sem projetos ainda), health=0 NUNCA pode virar um alerta de "saúde
    // baixa" — isso seria um diagnóstico factual sobre dados que não existem.
    test('E: scores vazio + health=0 (sentinela "sem dados") NÃO gera alerta de saúde baixa', () {
      final alert = selectEcosystemAlert(scores: const [], health: 0, pending: const []);
      expect(alert.hasAlert, isFalse);
      expect(alert.alertMessage, isEmpty);
    });

    test('E (variante): scores vazio + health=0 + muitas ações pendentes ainda pode alertar por outro motivo real', () {
      // Verifica que o guard não é "hasAlert sempre false quando scores
      // vazio" -- apenas o ramo de SAÚDE (dependente de scores) é
      // desativado; ações pendentes são um sinal genuinamente independente.
      final manyPending = List.generate(6, (i) => buildAction(id: 'a$i'));
      final alert = selectEcosystemAlert(scores: const [], health: 0, pending: manyPending);
      expect(alert.hasAlert, isTrue);
      expect(alert.alertId, startsWith('actions_overdue_'));
    });

    // Teste F — um score REAL e genuinamente baixo (projetos existem, dados
    // carregados) deve continuar gerando o alerta normalmente.
    test('F: scores não-vazio + health<40 genuíno preserva o alerta de saúde baixa', () {
      final scores = [buildScore(projectId: 'p1', ecosystemScore: 35)];
      final alert = selectEcosystemAlert(scores: scores, health: 35, pending: const []);
      expect(alert.hasAlert, isTrue);
      expect(alert.alertId, 'health_low_35');
      expect(alert.alertMessage, contains('35/100'));
    });

    test('F (variante): scores não-vazio com ecosystemScore genuinamente 0 ainda alerta (zero real != zero desconhecido)', () {
      final scores = [buildScore(projectId: 'p1', ecosystemScore: 0)];
      final alert = selectEcosystemAlert(scores: scores, health: 0, pending: const []);
      expect(alert.hasAlert, isTrue);
      expect(alert.alertId, 'health_low_0');
    });

    test('scores não-vazio + health>=40 sem críticos nem pendências acumuladas: nenhum alerta', () {
      final scores = [buildScore(projectId: 'p1', ecosystemScore: 80)];
      final alert = selectEcosystemAlert(scores: scores, health: 80, pending: const []);
      expect(alert.hasAlert, isFalse);
    });

    test('projeto com score crítico (<30) gera alerta específico mesmo com health>=40', () {
      final scores = [
        buildScore(projectId: 'ok', ecosystemScore: 90),
        buildScore(projectId: 'critico', ecosystemScore: 20),
      ];
      final alert = selectEcosystemAlert(scores: scores, health: 55, pending: const []);
      expect(alert.hasAlert, isTrue);
      expect(alert.alertId, 'score_critical_critico');
    });
  });
}
