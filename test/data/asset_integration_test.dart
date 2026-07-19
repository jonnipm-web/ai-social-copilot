/// Testes da Fase C — integração de assetId em OpportunityLabItem e ActionQueueItem.
///
/// Cenários:
///   1.  OpportunityLabItem.fromMap com asset_id preenchido
///   2.  OpportunityLabItem.fromMap sem asset_id → null
///   3.  OpportunityLabItem.toInsertMap inclui asset_id quando presente
///   4.  OpportunityLabItem.toInsertMap omite asset_id quando null
///   5.  OpportunityLabItem.copyWith com assetId
///   6.  OpportunityLabItem.copyWith com clearAsset remove assetId
///   7.  ActionQueueItem.fromMap com asset_id preenchido
///   8.  ActionQueueItem.fromMap sem asset_id → null
///   9.  ActionQueueItem.toInsertMap inclui asset_id quando presente
///  10.  ActionQueueItem.toInsertMap omite asset_id quando null
///  11.  Compatibilidade retroativa — fromMap sem campo asset_id
///  12.  Oportunidade com assetId null não quebra fluxo existente
///  13.  Ação com assetId null não quebra fluxo existente

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _oppMap({String? assetId}) => {
  'id':               'opp-1',
  'user_id':          'user-a',
  'project_id':       'proj-1',
  'market_analysis_id': null,
  'asset_id':         assetId,
  'opportunity_type': 'expansão',
  'title':            'Nova Oportunidade',
  'description':      'Descrição',
  'market_score':     80,
  'revenue_score':    70,
  'competition_score': 60,
  'synergy_score':    50,
  'strategic_fit':    75,
  'final_score':      67,
  'status':           'pending',
  'created_at':       '2026-01-01T00:00:00.000Z',
  'origin':           'manual',
  'sources':          <dynamic>[],
  'rationale':        null,
  'confidence':       80,
  'risks':            <dynamic>[],
  'action_steps':     <dynamic>[],
};

Map<String, dynamic> _actionMap({String? assetId}) => {
  'id':                'action-1',
  'user_id':           'user-a',
  'project_id':        'proj-1',
  'opportunity_lab_id': null,
  'asset_id':          assetId,
  'action_type':       'task',
  'title':             'Executar ação',
  'priority':          5,
  'impact_score':      80,
  'effort_score':      40,
  'roi_score':         70,
  'status':            'pending',
  'created_at':        '2026-01-01T00:00:00.000Z',
  'description':       'Descrição',
  'origin':            'manual',
  'sources':           <dynamic>[],
  'rationale':         null,
  'plan':              <dynamic>[],
  'risks':             <dynamic>[],
  'updated_at':        null,
  'market_score':      60,
  'confidence':        75,
  'market_analysis_id': null,
};

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── OpportunityLabItem ────────────────────────────────────────────────────

  group('OpportunityLabItem — assetId', () {
    test('1. fromMap com asset_id preenchido parsia corretamente', () {
      final item = OpportunityLabItem.fromMap(_oppMap(assetId: 'asset-42'));
      expect(item.assetId, 'asset-42');
    });

    test('2. fromMap sem asset_id resulta em null', () {
      final item = OpportunityLabItem.fromMap(_oppMap());
      expect(item.assetId, isNull);
    });

    test('3. toInsertMap inclui asset_id quando presente', () {
      final item = OpportunityLabItem.fromMap(_oppMap(assetId: 'asset-42'));
      final map  = item.toInsertMap();
      expect(map['asset_id'], 'asset-42');
    });

    test('4. toInsertMap omite asset_id quando null', () {
      final item = OpportunityLabItem.fromMap(_oppMap());
      final map  = item.toInsertMap();
      expect(map.containsKey('asset_id'), isFalse);
    });

    test('5. copyWith com assetId substitui o valor', () {
      final original = OpportunityLabItem.fromMap(_oppMap());
      final copy     = original.copyWith(assetId: 'novo-asset');
      expect(copy.assetId, 'novo-asset');
      expect(original.assetId, isNull); // original não muda
    });

    test('6. copyWith com clearAsset remove o assetId', () {
      final original = OpportunityLabItem.fromMap(_oppMap(assetId: 'asset-42'));
      final copy     = original.copyWith(clearAsset: true);
      expect(copy.assetId, isNull);
      expect(original.assetId, 'asset-42'); // original não muda
    });

    test('11. fromMap sem campo asset_id no mapa não lança exceção', () {
      final map = _oppMap()..remove('asset_id');
      expect(() => OpportunityLabItem.fromMap(map), returnsNormally);
      final item = OpportunityLabItem.fromMap(map);
      expect(item.assetId, isNull);
    });

    test('12. oportunidade com assetId null mantém fluxo existente', () {
      final item = OpportunityLabItem.fromMap(_oppMap());
      expect(item.id,           'opp-1');
      expect(item.title,        'Nova Oportunidade');
      expect(item.finalScore,   67);
      expect(item.assetId,      isNull);
    });
  });

  // ── ActionQueueItem ───────────────────────────────────────────────────────

  group('ActionQueueItem — assetId', () {
    test('7. fromMap com asset_id preenchido parseia corretamente', () {
      final item = ActionQueueItem.fromMap(_actionMap(assetId: 'asset-99'));
      expect(item.assetId, 'asset-99');
    });

    test('8. fromMap sem asset_id resulta em null', () {
      final item = ActionQueueItem.fromMap(_actionMap());
      expect(item.assetId, isNull);
    });

    test('9. toInsertMap inclui asset_id quando presente', () {
      final item = ActionQueueItem.fromMap(_actionMap(assetId: 'asset-99'));
      final map  = item.toInsertMap();
      expect(map['asset_id'], 'asset-99');
    });

    test('10. toInsertMap omite asset_id quando null', () {
      final item = ActionQueueItem.fromMap(_actionMap());
      final map  = item.toInsertMap();
      expect(map.containsKey('asset_id'), isFalse);
    });

    test('11b. fromMap sem campo asset_id no mapa não lança exceção', () {
      final map = _actionMap()..remove('asset_id');
      expect(() => ActionQueueItem.fromMap(map), returnsNormally);
      final item = ActionQueueItem.fromMap(map);
      expect(item.assetId, isNull);
    });

    test('13. ação com assetId null mantém fluxo existente', () {
      final item = ActionQueueItem.fromMap(_actionMap());
      expect(item.id,       'action-1');
      expect(item.title,    'Executar ação');
      expect(item.priority, 5);
      expect(item.assetId,  isNull);
    });
  });

  // ── Invariantes de compatibilidade ───────────────────────────────────────

  group('Compatibilidade retroativa', () {
    test('oportunidade existente sem asset_id passa toInsertMap sem chave asset_id', () {
      final map = _oppMap();
      map.remove('asset_id');
      final item    = OpportunityLabItem.fromMap(map);
      final insert  = item.toInsertMap();
      expect(insert.containsKey('asset_id'), isFalse,
          reason: 'Não deve inserir asset_id = null no banco');
    });

    test('ação existente sem asset_id passa toInsertMap sem chave asset_id', () {
      final map    = _actionMap();
      map.remove('asset_id');
      final item   = ActionQueueItem.fromMap(map);
      final insert = item.toInsertMap();
      expect(insert.containsKey('asset_id'), isFalse,
          reason: 'Não deve inserir asset_id = null no banco');
    });
  });
}
