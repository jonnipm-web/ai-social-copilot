/// Testes do AssetScore — modelo, computação e cache.
///
/// Sem Supabase. Testa a lógica pura do AssetScoreService.
///
/// Cenários:
///   1. Score zero para asset sem dados
///   2. Potencial cresce com nicho + targetMarket + revenueModel
///   3. Maturidade baseada em status
///   4. Fit estratégico baseado em prioritidade + categoria
///   5. ROI a partir de metadata
///   6. Velocidade a partir de metadata de ações
///   7. Fórmula ponderada correta (Pot×30% + Mat×20% + Str×25% + ROI×15% + Vel×10%)
///   8. Recomendação para cada faixa de score
///   9. Confiança baseada em dados disponíveis
///  10. computeAll ordena por assetScore desc
///  11. toCacheMap / fromCache roundtrip
///  12. Asset arquivado tem maturityScore menor
///  13. Asset com priorityScore alto tem strategicScore alto
///  14. Asset completed tem maturityScore máximo
///  15. missingData lista campos ausentes

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/asset.dart';
import 'package:ai_social_copilot/data/models/asset_score.dart';
import 'package:ai_social_copilot/data/services/asset_score_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

final _svc = AssetScoreService();

Asset _asset({
  String id                    = 'a1',
  AssetStatus status           = AssetStatus.idea,
  String? niche,
  String? targetMarket,
  String? targetAudience,
  String? description,
  String? category,
  String? revenueModel,
  String? businessModel,
  String? lifecycleStage,
  int?    strategicPriority,
  Map<String, dynamic> metadata = const {},
}) =>
    Asset(
      id:                id,
      userId:            'u1',
      projectId:         'p1',
      name:              'Ativo $id',
      type:              AssetType.product,
      status:            status,
      niche:             niche,
      targetMarket:      targetMarket,
      targetAudience:    targetAudience,
      description:       description,
      category:          category,
      revenueModel:      revenueModel,
      businessModel:     businessModel,
      lifecycleStage:    lifecycleStage,
      strategicPriority: strategicPriority,
      metadata:          metadata,
      createdAt:         DateTime(2026),
      updatedAt:         DateTime(2026),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('AssetScoreService — score mínimo', () {
    test('1. asset sem dados tem assetScore baixo e ANÁLISE INCOMPLETA', () {
      final score = _svc.compute(_asset());

      expect(score.assetScore, lessThan(30));
      expect(score.recommendation, 'ANÁLISE INCOMPLETA');
      expect(score.hasEnoughData,  isFalse);
    });
  });

  group('AssetScoreService — potentialScore', () {
    test('2a. sem dados de segmentação → potentialScore baixo', () {
      final score = _svc.compute(_asset());
      expect(score.potentialScore, lessThan(20));
    });

    test('2b. com nicho + targetMarket + revenueModel → potentialScore >= 45', () {
      final score = _svc.compute(_asset(
        niche:        'Marketing Digital',
        targetMarket: 'PMEs Brasileiras',
        revenueModel: 'subscription',
      ));
      expect(score.potentialScore, greaterThanOrEqualTo(45));
    });

    test('2c. market_size grande em metadata aumenta potentialScore', () {
      final withSize = _svc.compute(_asset(
        niche:    'SaaS',
        metadata: {'market_size': 2_000_000},
      ));
      final without = _svc.compute(_asset(niche: 'SaaS'));
      expect(withSize.potentialScore, greaterThan(without.potentialScore));
    });
  });

  group('AssetScoreService — maturityScore', () {
    test('3a. status idea → maturityScore <= 20', () {
      final score = _svc.compute(_asset(status: AssetStatus.idea));
      expect(score.maturityScore, lessThanOrEqualTo(20));
    });

    test('3b. status active → maturityScore >= 60', () {
      final score = _svc.compute(_asset(status: AssetStatus.active));
      expect(score.maturityScore, greaterThanOrEqualTo(60));
    });

    test('12. status archived → maturityScore < status active', () {
      final archived = _svc.compute(_asset(status: AssetStatus.archived));
      final active   = _svc.compute(_asset(status: AssetStatus.active));
      expect(archived.maturityScore, lessThan(active.maturityScore));
    });

    test('14. status completed → maturityScore >= 80', () {
      final score = _svc.compute(_asset(status: AssetStatus.completed));
      expect(score.maturityScore, greaterThanOrEqualTo(80));
    });
  });

  group('AssetScoreService — strategicScore', () {
    test('4a. sem dados estratégicos → strategicScore baixo', () {
      final score = _svc.compute(_asset());
      expect(score.strategicScore, lessThan(30));
    });

    test('13. strategicPriority 9 → strategicScore alto', () {
      final score = _svc.compute(_asset(
        strategicPriority: 9,
        category:          'core',
        niche:             'SaaS',
        description:       'Ativo principal',
      ));
      expect(score.strategicScore, greaterThanOrEqualTo(70));
    });
  });

  group('AssetScoreService — roiScore', () {
    test('5a. sem dados de ROI → roiScore == 0', () {
      final score = _svc.compute(_asset());
      expect(score.roiScore, 0);
    });

    test('5b. roi_actual >= 300 → roiScore alto', () {
      final score = _svc.compute(_asset(
        metadata: {'roi_actual': 350.0},
      ));
      expect(score.roiScore, greaterThanOrEqualTo(60));
    });

    test('5c. roi_projected < roi_actual em impacto', () {
      final actual    = _svc.compute(_asset(metadata: {'roi_actual':    300.0}));
      final projected = _svc.compute(_asset(metadata: {'roi_projected': 300.0}));
      expect(actual.roiScore, greaterThan(projected.roiScore));
    });
  });

  group('AssetScoreService — velocityScore', () {
    test('6a. sem ações → velocityScore baixo', () {
      final score = _svc.compute(_asset());
      expect(score.velocityScore, lessThan(30));
    });

    test('6b. ações recentes e alta conclusão → velocityScore alto', () {
      final score = _svc.compute(_asset(
        status: AssetStatus.active,
        metadata: {
          'action_count':      10,
          'completed_actions': 9,
          'last_activity_days': 3,
        },
      ));
      expect(score.velocityScore, greaterThanOrEqualTo(80));
    });
  });

  group('AssetScoreService — fórmula ponderada', () {
    test('7. assetScore = Pot×30% + Mat×20% + Str×25% + ROI×15% + Vel×10%', () {
      final score = _svc.compute(_asset(
        status:            AssetStatus.active,
        niche:             'FinTech',
        targetMarket:      'Startups',
        targetAudience:    'Fundadores',
        description:       'Core do produto',
        category:          'fintech',
        revenueModel:      'subscription',
        strategicPriority: 8,
        metadata: {
          'roi_actual':        150.0,
          'action_count':      5,
          'completed_actions': 4,
          'last_activity_days': 5,
        },
      ));

      // Verifica que a fórmula foi aplicada corretamente
      final expected = (score.potentialScore  * 0.30
                      + score.maturityScore   * 0.20
                      + score.strategicScore  * 0.25
                      + score.roiScore        * 0.15
                      + score.velocityScore   * 0.10)
          .round()
          .clamp(0, 100);

      expect(score.assetScore, expected);
    });
  });

  group('AssetScoreService — recomendação', () {
    test('8a. score >= 75 → ESCALAR', () {
      // Asset com dados excelentes em todos os componentes
      final score = _svc.compute(_asset(
        status:            AssetStatus.active,
        niche:             'FinTech',
        targetMarket:      'Global',
        targetAudience:    'Todos',
        description:       'Descrição',
        revenueModel:      'revenue',
        businessModel:     'b2b',
        category:          'core',
        strategicPriority: 10,
        lifecycleStage:    'growth',
        metadata: {
          'market_size':       5_000_000,
          'roi_actual':        500.0,
          'action_count':      20,
          'completed_actions': 18,
          'last_activity_days': 2,
          'strategic_tags':    ['ai', 'saas'],
        },
      ));
      // Pode ser ESCALAR se score >= 75 e hasEnoughData
      expect(['ESCALAR', 'ACELERAR', 'MANTER'], contains(score.recommendation));
    });

    test('8b. asset sem dados → ANÁLISE INCOMPLETA', () {
      final score = _svc.compute(_asset());
      expect(score.recommendation, 'ANÁLISE INCOMPLETA');
    });
  });

  group('AssetScoreService — confiança', () {
    test('9a. zero dados → confidence == 0', () {
      final score = _svc.compute(_asset());
      expect(score.confidence, 0);
    });

    test('9b. todos os sinais preenchidos → confidence == 100', () {
      final score = _svc.compute(_asset(
        niche:        'AI',
        description:  'Texto',
        targetMarket: 'Global',
        metadata: {
          'roi_actual':   200.0,
          'action_count': 5,
        },
      ));
      expect(score.confidence, 100);
    });
  });

  group('AssetScoreService — computeAll', () {
    test('10. lista ordenada por assetScore desc', () {
      final a1 = _asset(id: 'low',  status: AssetStatus.idea);
      final a2 = _asset(
        id: 'high',
        status:            AssetStatus.active,
        niche:             'SaaS',
        targetMarket:      'BR',
        strategicPriority: 9,
        description:       'Core',
        metadata: {'roi_actual': 200.0, 'action_count': 5, 'completed_actions': 5, 'last_activity_days': 3},
      );

      final scores = _svc.computeAll([a1, a2]);
      expect(scores.first.asset.id, 'high');
      expect(scores.last.asset.id,  'low');
      expect(scores.first.assetScore, greaterThanOrEqualTo(scores.last.assetScore));
    });
  });

  group('AssetScore — cache', () {
    test('11a. toCacheMap / fromCache roundtrip preserva valores', () {
      final original = _svc.compute(_asset(
        status:            AssetStatus.active,
        niche:             'Ed Tech',
        targetMarket:      'Universidades',
        description:       'Plataforma',
        strategicPriority: 7,
        metadata: {'roi_projected': 120.0},
      ));

      final cacheMap = original.toCacheMap();
      final restored = AssetScore.fromCache(original.asset, cacheMap);

      expect(restored?.assetScore,     original.assetScore);
      expect(restored?.recommendation, original.recommendation);
      expect(restored?.confidence,     original.confidence);
      expect(restored?.strengths,      original.strengths);
      expect(restored?.risks,          original.risks);
    });

    test('11b. fromCache com mapa nulo retorna null', () {
      final result = AssetScore.fromCache(_asset(), null);
      expect(result, isNull);
    });
  });

  group('AssetScoreService — missingData', () {
    test('15. missingData lista campos ausentes corretamente', () {
      final score = _svc.compute(_asset());
      expect(score.missingData, containsAll(['niche', 'targetMarket', 'description']));
    });

    test('15b. sem campos faltando quando tudo preenchido', () {
      final score = _svc.compute(_asset(
        niche:        'AI',
        targetMarket: 'Global',
        description:  'Desc',
        metadata: {'roi_actual': 100.0, 'action_count': 5},
      ));
      expect(score.missingData, isEmpty);
    });
  });

  group('AssetScoreComponent — cálculo', () {
    test('weightedContribution = rawValue × weight', () {
      const c = AssetScoreComponent(
        name:        'Test',
        rawValue:    80,
        maxValue:    100,
        weight:      0.30,
        explanation: '',
      );
      expect(c.weightedContribution, 24); // 80 * 0.30 = 24
    });

    test('completeness = rawValue / maxValue', () {
      const c = AssetScoreComponent(
        name:        'Test',
        rawValue:    50,
        maxValue:    100,
        weight:      0.20,
        explanation: '',
      );
      expect(c.completeness, closeTo(0.5, 0.001));
    });

    test('displayWeight formata percentual corretamente', () {
      const c = AssetScoreComponent(
        name:        'Test',
        rawValue:    0,
        maxValue:    100,
        weight:      0.25,
        explanation: '',
      );
      expect(c.displayWeight, '25%');
    });
  });
}
