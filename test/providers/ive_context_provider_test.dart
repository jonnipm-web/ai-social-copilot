import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/knowledge_item.dart';
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
}
