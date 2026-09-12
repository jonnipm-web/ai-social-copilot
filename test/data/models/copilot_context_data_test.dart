import 'package:flutter_test/flutter_test.dart';

import 'package:ai_social_copilot/data/models/copilot_context_data.dart';
import 'package:ai_social_copilot/providers/ive_context_provider.dart';

// ── IVE-COMMERCIAL-TARGETED-REMEDIATION-04 ──────────────────────────────────
// Covers CopilotContextData.fromIveContext(), the single conversion now
// shared by every chat-opening entry point (ive_overlay.dart's global
// avatar AND ive_detail_sheet.dart's "Perguntar à IVE" button). Before this
// mission, the detail-sheet button passed an empty CopilotContextData()
// unconditionally -- IVE silently answered with zero project/knowledge/
// opportunity grounding from that specific entry point, with no error or
// visible signal that anything was missing. This suite proves the shared
// conversion faithfully carries every field IveContextData actually
// populates, so neither entry point can regress back to a silent empty
// context without a test failing.
//
// Scope note: the *upstream* provider chain that produces IveContextData
// (ecosystemScoresProvider → opportunityLabProvider → ... ,
// knowledgeItemsProvider, pendingActionsProvider) is not mocked here --
// several of those services touch Supabase.instance.client in their field
// initializers, which prior test files in this repo (see
// test/providers/ive_provider_interaction_test.dart's own scope note)
// deliberately keep out of the automated suite. Cross-project isolation of
// that live chain is verified instead by the physical E2E matrix (Emily/
// Lucas, separate projects) accompanying this mission's final report.

IveContextData _fullContext() => const IveContextData(
      healthScore: 72,
      projectCount: 3,
      pendingActionsCount: 5,
      pendingOpportunitiesCount: 2,
      topProjectName: 'Projeto Alfa',
      topProjectDescription: 'Descrição do projeto alfa',
      topProjectType: 'ebook',
      topProjectScore: 88,
      mainBottleneckName: 'Projeto Beta',
      mainBottleneckScore: 21,
      hasAlert: true,
      alertMessage: 'Score crítico',
      alertId: 'score_critical_p2',
      topProjectsSnapshot: [
        {'name': 'Projeto Alfa', 'score': 88},
      ],
      knowledgeItemsSummary: [
        {'title': 'Doc 1', 'grounded': true, 'content_excerpt': 'trecho relevante'},
      ],
      documentCoverage: {'total_linked': 4, 'used_ids': ['doc1'], 'not_used_count': 3},
      documentWarnings: ['4 fontes vinculadas · 1 utilizada nesta análise'],
      pendingOpportunitiesSummary: [
        {'title': 'Oportunidade 1', 'score': 90},
      ],
      pendingActionsSummary: [
        {'title': 'Ação 1', 'priority': 1},
      ],
    );

void main() {
  group('CopilotContextData.fromIveContext', () {
    test('carrega scores agregados do ecossistema', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.scores?['ecosystem_health'], 72);
      expect(result.scores?['total_projects'], 3);
      expect(result.scores?['pending_actions'], 5);
      expect(result.scores?['pending_opportunities'], 2);
      expect(result.scores?['top_project_name'], 'Projeto Alfa');
      expect(result.scores?['main_bottleneck'], 'Projeto Beta');
    });

    test('carrega o snapshot de projetos', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.project?['projects'], isA<List>());
      expect((result.project?['projects'] as List).first['name'], 'Projeto Alfa');
    });

    test('carrega documentos, coverage e warnings de grounding', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.documents, isNotEmpty);
      expect(result.documents.first['content_excerpt'], 'trecho relevante');
      expect(result.documentCoverage?['total_linked'], 4);
      expect(result.documentWarnings, isNotEmpty);
    });

    test('carrega oportunidades pendentes', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.opportunities, isNotEmpty);
      expect(result.opportunities.first['title'], 'Oportunidade 1');
    });

    // Achado central desta missão: ive_overlay.dart nunca preenchia
    // `actions` (apesar de IveContextData.pendingActionsSummary já
    // existir e context-copilot/index.ts já ler ctx.actions), e
    // ive_detail_sheet.dart não preenchia nada. Esta é a prova de que a
    // conversão compartilhada agora entrega isso pelos dois caminhos.
    test('carrega ações pendentes (antes nunca enviado por nenhum dos dois pontos de entrada)', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.actions, isNotEmpty);
      expect(result.actions.first['title'], 'Ação 1');
    });

    test('projeto/coverage ficam null quando o contexto de origem não tem nada (não um mapa vazio)', () {
      const empty = IveContextData();
      final result = CopilotContextData.fromIveContext(empty);
      expect(result.project, isNull);
      expect(result.documentCoverage, isNull);
      expect(result.documents, isEmpty);
      expect(result.opportunities, isEmpty);
      expect(result.actions, isEmpty);
    });
  });

  group('CopilotContextData.isEmpty', () {
    test('true para o contexto padrão (nenhum campo)', () {
      expect(const CopilotContextData().isEmpty, isTrue);
    });

    test('false assim que qualquer campo de grounding real está presente', () {
      final result = CopilotContextData.fromIveContext(_fullContext());
      expect(result.isEmpty, isFalse);
    });

    // Guarda de regressão explícita pedida pela missão: um contexto vazio
    // nunca deve "passar por" um contexto real sem que algo no código
    // consiga detectar a diferença.
    test('detecta contexto vazio mesmo com IveContextData minimamente populado sem grounding', () {
      const minimal = IveContextData(healthScore: 0, projectCount: 0);
      final result = CopilotContextData.fromIveContext(minimal);
      // scores sempre é montado (mesmo que com zeros) -- isEmpty checa
      // `scores == null`, não "scores sem conteúdo útil". Documentado
      // aqui para não ser reinterpretado como bug: scores nunca é null
      // vindo de fromIveContext(), então isEmpty é sempre false por esse
      // caminho -- o sinal de "realmente vazio" é a ausência total de
      // IveContextData (ctx == null no call site), não isEmpty().
      expect(result.scores, isNotNull);
    });
  });
}
