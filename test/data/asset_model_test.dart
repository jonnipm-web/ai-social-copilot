/// Testes do modelo Asset — fromMap, toMap, copyWith, enums.
///
/// Sem Supabase, sem providers. Apenas lógica de modelo.

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_social_copilot/data/models/asset.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseMap({
  String id            = 'asset-1',
  String userId        = 'user-a',
  String projectId     = 'proj-1',
  String? parentAssetId,
  String name          = 'Meu Ativo',
  String type          = 'product',
  String? subtype,
  String? description,
  String status        = 'idea',
  String? niche,
  String? category,
  String? targetMarket,
  String? targetAudience,
  String? businessModel,
  String? revenueModel,
  String? lifecycleStage,
  int?    strategicPriority,
  Map<String, dynamic> metadata = const {},
  String createdAt     = '2026-01-01T00:00:00.000Z',
  String updatedAt     = '2026-01-01T00:00:00.000Z',
}) =>
    {
      'id':                id,
      'user_id':           userId,
      'project_id':        projectId,
      'parent_asset_id':   parentAssetId,
      'name':              name,
      'type':              type,
      'subtype':           subtype,
      'description':       description,
      'status':            status,
      'niche':             niche,
      'category':          category,
      'target_market':     targetMarket,
      'target_audience':   targetAudience,
      'business_model':    businessModel,
      'revenue_model':     revenueModel,
      'lifecycle_stage':   lifecycleStage,
      'strategic_priority': strategicPriority,
      'metadata':          metadata,
      'created_at':        createdAt,
      'updated_at':        updatedAt,
    };

Asset _asset({
  String id        = 'asset-1',
  String userId    = 'user-a',
  String projectId = 'proj-1',
  AssetType  type   = AssetType.product,
  AssetStatus status = AssetStatus.idea,
}) =>
    Asset(
      id:        id,
      userId:    userId,
      projectId: projectId,
      name:      'Meu Ativo',
      type:      type,
      status:    status,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('Asset.fromMap — campos obrigatórios', () {
    test('parseia campos básicos corretamente', () {
      final a = Asset.fromMap(_baseMap());

      expect(a.id,        'asset-1');
      expect(a.userId,    'user-a');
      expect(a.projectId, 'proj-1');
      expect(a.name,      'Meu Ativo');
      expect(a.type,      AssetType.product);
      expect(a.status,    AssetStatus.idea);
      expect(a.metadata,  isEmpty);
    });

    test('campos opcionais nulos ficam null', () {
      final a = Asset.fromMap(_baseMap());

      expect(a.parentAssetId,    isNull);
      expect(a.subtype,          isNull);
      expect(a.description,      isNull);
      expect(a.category,         isNull);
      expect(a.niche,            isNull);
      expect(a.targetMarket,     isNull);
      expect(a.targetAudience,   isNull);
      expect(a.businessModel,    isNull);
      expect(a.revenueModel,     isNull);
      expect(a.lifecycleStage,   isNull);
      expect(a.strategicPriority, isNull);
    });

    test('parseia todos os campos opcionais quando presentes', () {
      final a = Asset.fromMap(_baseMap(
        parentAssetId:     'parent-1',
        subtype:           'ebook',
        description:       'Descrição do ativo',
        category:          'digital',
        niche:             'marketing',
        targetMarket:      'PMEs',
        targetAudience:    'Empreendedores',
        businessModel:     'SaaS',
        revenueModel:      'subscription',
        lifecycleStage:    'growth',
        strategicPriority: 5,
        metadata:          {'score': 80, 'tags': ['ai']},
      ));

      expect(a.parentAssetId,    'parent-1');
      expect(a.subtype,          'ebook');
      expect(a.description,      'Descrição do ativo');
      expect(a.category,         'digital');
      expect(a.niche,            'marketing');
      expect(a.targetMarket,     'PMEs');
      expect(a.targetAudience,   'Empreendedores');
      expect(a.businessModel,    'SaaS');
      expect(a.revenueModel,     'subscription');
      expect(a.lifecycleStage,   'growth');
      expect(a.strategicPriority, 5);
      expect(a.metadata['score'], 80);
    });

    test('metadata é mapa vazio quando nulo no banco', () {
      final map = _baseMap();
      map['metadata'] = null;
      final a = Asset.fromMap(map);
      expect(a.metadata, isEmpty);
    });

    test('parseia datas via DateParser (sem lançar exceção)', () {
      final a = Asset.fromMap(_baseMap(
        createdAt: '2026-01-15T10:30:00.000Z',
        updatedAt: '2026-06-20T08:00:00.000Z',
      ));
      expect(a.createdAt.year, 2026);
      expect(a.updatedAt.month, 6);
    });
  });

  group('Asset.toInsertMap', () {
    test('inclui user_id, project_id, name, type, status, metadata', () {
      final a = _asset();
      final map = a.toInsertMap();

      expect(map['user_id'],    'user-a');
      expect(map['project_id'], 'proj-1');
      expect(map['name'],       'Meu Ativo');
      expect(map['type'],       'product');
      expect(map['status'],     'idea');
      expect(map['metadata'],   isEmpty);
    });

    test('não inclui campos opcionais nulos no insert', () {
      final a = _asset();
      final map = a.toInsertMap();

      expect(map.containsKey('parent_asset_id'), isFalse);
      expect(map.containsKey('subtype'),         isFalse);
      expect(map.containsKey('description'),     isFalse);
      expect(map.containsKey('niche'),           isFalse);
    });

    test('inclui parent_asset_id quando presente', () {
      final a = Asset(
        id:            'a1',
        userId:        'u1',
        projectId:     'p1',
        parentAssetId: 'parent-99',
        name:          'Filho',
        type:          AssetType.book,
        createdAt:     DateTime(2026),
        updatedAt:     DateTime(2026),
      );
      final map = a.toInsertMap();
      expect(map['parent_asset_id'], 'parent-99');
    });
  });

  group('Asset.copyWith', () {
    test('retorna cópia com campos alterados', () {
      final original = _asset();
      final copy = original.copyWith(
        name:   'Novo Nome',
        status: AssetStatus.active,
      );

      expect(copy.name,   'Novo Nome');
      expect(copy.status, AssetStatus.active);
      expect(copy.id,     original.id);
    });

    test('sem argumentos retorna cópia idêntica', () {
      final a = _asset();
      final copy = a.copyWith();

      expect(copy.id,        a.id);
      expect(copy.userId,    a.userId);
      expect(copy.projectId, a.projectId);
      expect(copy.name,      a.name);
      expect(copy.type,      a.type);
      expect(copy.status,    a.status);
    });

    test('clearParent remove parentAssetId', () {
      final a = Asset(
        id:            'a1',
        userId:        'u1',
        projectId:     'p1',
        parentAssetId: 'pai',
        name:          'Filho',
        type:          AssetType.book,
        createdAt:     DateTime(2026),
        updatedAt:     DateTime(2026),
      );
      final copy = a.copyWith(clearParent: true);
      expect(copy.parentAssetId, isNull);
    });
  });

  group('AssetType enum', () {
    test('todos os valores têm dbValue definido', () {
      for (final t in AssetType.values) {
        expect(t.dbValue, isNotEmpty);
      }
    });

    test('conversão roundtrip: enum → db → enum', () {
      for (final t in AssetType.values) {
        expect(AssetType.fromDb(t.dbValue), t);
      }
    });

    test('content_property e intellectual_property usam snake_case', () {
      expect(AssetType.contentProperty.dbValue,     'content_property');
      expect(AssetType.intellectualProperty.dbValue, 'intellectual_property');
    });

    test('valor desconhecido retorna AssetType.other', () {
      expect(AssetType.fromDb('xyz_unknown'), AssetType.other);
      expect(AssetType.fromDb(null),          AssetType.other);
    });
  });

  group('AssetStatus enum', () {
    test('todos os valores têm dbValue definido', () {
      for (final s in AssetStatus.values) {
        expect(s.dbValue, isNotEmpty);
      }
    });

    test('conversão roundtrip: enum → db → enum', () {
      for (final s in AssetStatus.values) {
        expect(AssetStatus.fromDb(s.dbValue), s);
      }
    });

    test('valor desconhecido retorna AssetStatus.idea', () {
      expect(AssetStatus.fromDb('xyz'), AssetStatus.idea);
      expect(AssetStatus.fromDb(null),  AssetStatus.idea);
    });

    test('archived permanece archived após roundtrip', () {
      expect(AssetStatus.fromDb('archived'), AssetStatus.archived);
    });
  });

  group('Asset sem campos opcionais — compatibilidade', () {
    test('fromMap com mínimo de campos não lança exceção', () {
      final map = {
        'id':         'a1',
        'user_id':    'u1',
        'project_id': 'p1',
        'name':       'Mínimo',
        'type':       'other',
        'status':     'idea',
        'metadata':   <String, dynamic>{},
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };
      expect(() => Asset.fromMap(map), returnsNormally);
    });
  });
}
