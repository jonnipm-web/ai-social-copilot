/// Testes de autenticação e defesa em profundidade para MarketAnalysisService.
///
/// Valida que:
///   - Todos os métodos de fetch de sub-entidades lançam exceção sem sessão
///   - delete() lança exceção sem sessão
///   - Operações de criação (analyze, discoverCompetitors, etc.) lançam exceção
///
/// RLS no banco é a segunda camada; esses testes validam a primeira (service).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_social_copilot/data/services/market_analysis_service.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Matcher throwsNotAuthenticated() => throwsA(
      isA<Exception>().having(
        (e) => e.toString(),
        'message',
        anyOf(
          contains('autenticado'),
          contains('Autenticado'),
          contains('authenticated'),
        ),
      ),
    );

const _fakeId = 'fake-market-analysis-id';

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: 'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
  });

  group('MarketAnalysisService — exige autenticação (sem sessão)', () {
    test('fetchAll() lança exceção', () {
      expect(MarketAnalysisService().fetchAll(), throwsNotAuthenticated());
    });

    test('fetchAllRevenuePlans() lança exceção', () {
      expect(MarketAnalysisService().fetchAllRevenuePlans(), throwsNotAuthenticated());
    });

    test('delete() lança exceção', () {
      expect(MarketAnalysisService().delete(_fakeId), throwsNotAuthenticated());
    });

    test('analyze() lança exceção', () {
      expect(
        MarketAnalysisService().analyze('https://example.com'),
        throwsNotAuthenticated(),
      );
    });
  });

  group('MarketAnalysisService — sub-entidades exigem autenticação', () {
    test('fetchCompetitors() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchCompetitors(_fakeId),
        throwsNotAuthenticated(),
      );
    });

    test('fetchGapAnalysis() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchGapAnalysis(_fakeId),
        throwsNotAuthenticated(),
      );
    });

    test('fetchOpportunities() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchOpportunities(_fakeId),
        throwsNotAuthenticated(),
      );
    });

    test('fetchNiches() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchNiches(_fakeId),
        throwsNotAuthenticated(),
      );
    });

    test('fetchContentCluster() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchContentCluster(_fakeId),
        throwsNotAuthenticated(),
      );
    });

    test('fetchRevenuePlan() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().fetchRevenuePlan(_fakeId),
        throwsNotAuthenticated(),
      );
    });
  });

  group('MarketAnalysisService — operações de mutação exigem autenticação', () {
    test('discoverCompetitors() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().discoverCompetitors(_fakeId, 'input'),
        throwsNotAuthenticated(),
      );
    });

    test('runGapAnalysis() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().runGapAnalysis(_fakeId, 'input'),
        throwsNotAuthenticated(),
      );
    });

    test('discoverOpportunities() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().discoverOpportunities(_fakeId, 'input'),
        throwsNotAuthenticated(),
      );
    });

    test('discoverNiches() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().discoverNiches(_fakeId, 'input'),
        throwsNotAuthenticated(),
      );
    });

    test('buildContentCluster() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().buildContentCluster(_fakeId, 'input', 'keyword'),
        throwsNotAuthenticated(),
      );
    });

    test('buildRevenuePlan() lança exceção sem sessão', () {
      expect(
        MarketAnalysisService().buildRevenuePlan(_fakeId, 'input', 'Projeto'),
        throwsNotAuthenticated(),
      );
    });
  });

  group('MarketAnalysisService — delete() valida propriedade', () {
    test('delete() sem sessão lança exceção antes de acessar o banco', () {
      // Sem sessão, _requireUid() dispara antes de qualquer consulta.
      // Em runtime com sessão mas análise de outro usuário, o filtro
      // .eq('user_id', uid) no fetchById prévio retornará null → exceção.
      expect(
        MarketAnalysisService().delete(_fakeId),
        throwsA(isA<Exception>()),
      );
    });
  });
}
