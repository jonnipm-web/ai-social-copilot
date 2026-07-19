/// Testes do AssetService e assetsForProjectProvider.
///
/// Cobre:
///   - autenticação obrigatória
///   - filtro por user_id
///   - filtro por project_id
///   - create injeta uid da sessão
///   - project inválido rejeitado
///   - parent de outro projeto rejeitado
///   - parent self-reference rejeitado
///   - projeto sem assets retorna lista vazia
///   - hierarquia parent-child
///   - archive / restore
///   - metadata preservada
///   - compatibilidade com asset sem campos opcionais

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_social_copilot/data/models/asset.dart';
import 'package:ai_social_copilot/data/services/asset_service.dart';
import 'package:ai_social_copilot/providers/asset_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockAssetService extends Mock implements AssetServiceInterface {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _uid       = 'user-test';
const _projectId = 'proj-test';

Asset _asset({
  String id            = 'asset-1',
  String? parentAssetId,
  AssetType  type      = AssetType.product,
  AssetStatus status   = AssetStatus.idea,
  Map<String, dynamic> metadata = const {},
}) =>
    Asset(
      id:            id,
      userId:        _uid,
      projectId:     _projectId,
      parentAssetId: parentAssetId,
      name:          'Ativo $id',
      type:          type,
      status:        status,
      metadata:      metadata,
      createdAt:     DateTime(2026),
      updatedAt:     DateTime(2026),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAssetService svc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url:     'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
    registerFallbackValue(_asset());
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    svc = MockAssetService();
  });

  ProviderContainer _container() => ProviderContainer(
    overrides: [assetServiceProvider.overrideWithValue(svc)],
  );

  // ── 6. Usuário não autenticado não faz fetch ─────────────────────────────
  group('Autenticação obrigatória — fetchAll', () {
    test('fetchAll sem sessão lança exceção', () {
      when(() => svc.fetchAll(any()))
          .thenThrow(Exception('Não autenticado'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).fetchAll(_projectId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('autenticado'),
        )),
      );
    });
  });

  // ── 7. Usuário não autenticado não faz create ────────────────────────────
  group('Autenticação obrigatória — create', () {
    test('create sem sessão lança exceção', () {
      when(() => svc.create(any()))
          .thenThrow(Exception('Não autenticado'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).create({'project_id': _projectId, 'name': 'x', 'type': 'product'}),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('autenticado'),
        )),
      );
    });
  });

  // ── 8. fetchAll filtra user_id ───────────────────────────────────────────
  group('fetchAll filtra por usuário', () {
    test('retorna apenas assets do usuário autenticado', () async {
      final a1 = _asset(id: 'a1');
      final a2 = _asset(id: 'a2');

      when(() => svc.fetchAll(_projectId)).thenAnswer((_) async => [a1, a2]);

      final c = _container();
      addTearDown(c.dispose);

      final result = await c.read(assetServiceProvider).fetchAll(_projectId);
      expect(result.map((a) => a.userId), everyElement(equals(_uid)));
    });
  });

  // ── 9. fetchAll filtra project_id ───────────────────────────────────────
  group('fetchAll filtra por projeto', () {
    test('retorna apenas assets do projeto solicitado', () async {
      final a = _asset(id: 'a1');
      when(() => svc.fetchAll(_projectId)).thenAnswer((_) async => [a]);
      when(() => svc.fetchAll('outro-projeto')).thenAnswer((_) async => []);

      final c = _container();
      addTearDown(c.dispose);

      final resultA = await c.read(assetServiceProvider).fetchAll(_projectId);
      final resultB = await c.read(assetServiceProvider).fetchAll('outro-projeto');

      expect(resultA, hasLength(1));
      expect(resultB, isEmpty);
    });
  });

  // ── 10. create injeta uid da sessão ─────────────────────────────────────
  group('create injeta uid da sessão', () {
    test('asset criado tem userId consistente com sessão', () async {
      final created = _asset(id: 'novo');
      when(() => svc.create(any())).thenAnswer((_) async => created);

      final c = _container();
      addTearDown(c.dispose);

      final result = await c.read(assetServiceProvider).create({
        'project_id': _projectId,
        'name':       'Novo',
        'type':       'product',
      });

      expect(result.userId, _uid);
    });
  });

  // ── 11. Project inválido rejeitado ───────────────────────────────────────
  group('Validação de projeto', () {
    test('create com project_id inválido lança exceção', () {
      when(() => svc.create(any()))
          .thenThrow(Exception('Projeto não pertence ao usuário ou não existe'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).create({
          'project_id': 'projeto-de-outro-usuario',
          'name':       'X',
          'type':       'product',
        }),
        throwsA(isA<Exception>().having(
          (e) => e.toString(), 'message', contains('Projeto'),
        )),
      );
    });
  });

  // ── 12. Parent de outro projeto rejeitado ────────────────────────────────
  group('Validação de parent — outro projeto', () {
    test('parent_asset_id de outro projeto é rejeitado', () {
      when(() => svc.create(any()))
          .thenThrow(Exception('Asset pai não pertence ao mesmo usuário/projeto'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).create({
          'project_id':     _projectId,
          'parent_asset_id': 'asset-de-outro-projeto',
          'name':            'Filho',
          'type':            'book',
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── 13. Parent de outro usuário rejeitado ────────────────────────────────
  group('Validação de parent — outro usuário', () {
    test('parent_asset_id de outro usuário é rejeitado', () {
      when(() => svc.create(any()))
          .thenThrow(Exception('Asset pai não pertence ao mesmo usuário/projeto'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).create({
          'project_id':      _projectId,
          'parent_asset_id': 'asset-de-outro-usuario',
          'name':            'Filho',
          'type':            'book',
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── 14. Parent self-reference rejeitado ─────────────────────────────────
  group('Validação de parent — self-reference', () {
    test('asset não pode ser pai de si mesmo', () {
      when(() => svc.create(any()))
          .thenThrow(Exception('Asset não pode referenciar a si mesmo'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(assetServiceProvider).create({
          'project_id':      _projectId,
          'parent_asset_id': 'asset-1',
          'name':            'Circular',
          'type':            'product',
          'id':              'asset-1',
        }),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ── 15. Projeto sem assets retorna lista vazia ───────────────────────────
  group('Projeto sem assets', () {
    test('fetchAll de projeto vazio retorna lista vazia', () async {
      when(() => svc.fetchAll('proj-sem-assets'))
          .thenAnswer((_) async => []);

      final c = _container();
      addTearDown(c.dispose);

      final result =
          await c.read(assetServiceProvider).fetchAll('proj-sem-assets');
      expect(result, isEmpty);
    });
  });

  // ── 16. Hierarquia parent-child ──────────────────────────────────────────
  group('Hierarquia parent-child', () {
    test('fetchChildren retorna filhos do asset pai', () async {
      final child1 = _asset(id: 'c1', parentAssetId: 'parent-1');
      final child2 = _asset(id: 'c2', parentAssetId: 'parent-1');

      when(() => svc.fetchChildren('parent-1'))
          .thenAnswer((_) async => [child1, child2]);

      final c = _container();
      addTearDown(c.dispose);

      final children =
          await c.read(assetServiceProvider).fetchChildren('parent-1');
      expect(children, hasLength(2));
      expect(children.every((a) => a.parentAssetId == 'parent-1'), isTrue);
    });
  });

  // ── 17. Archive ──────────────────────────────────────────────────────────
  group('Archive', () {
    test('archive altera status para archived', () async {
      final archived = _asset(id: 'a1', status: AssetStatus.archived);
      when(() => svc.archive('a1')).thenAnswer((_) async => archived);

      final c = _container();
      addTearDown(c.dispose);

      final result = await c.read(assetServiceProvider).archive('a1');
      expect(result.status, AssetStatus.archived);
    });
  });

  // ── 18. Restore ──────────────────────────────────────────────────────────
  group('Restore', () {
    test('restore altera status para active', () async {
      final active = _asset(id: 'a1', status: AssetStatus.active);
      when(() => svc.restore('a1')).thenAnswer((_) async => active);

      final c = _container();
      addTearDown(c.dispose);

      final result = await c.read(assetServiceProvider).restore('a1');
      expect(result.status, AssetStatus.active);
    });
  });

  // ── 19. Metadata JSONB preservada ────────────────────────────────────────
  group('Metadata JSONB', () {
    test('metadata complexa é preservada intacta', () async {
      final meta = {'score': 95, 'tags': ['ai', 'saas'], 'nested': {'k': 'v'}};
      final a    = _asset(id: 'a1', metadata: meta);

      when(() => svc.fetchAll(_projectId)).thenAnswer((_) async => [a]);

      final c = _container();
      addTearDown(c.dispose);

      final list = await c.read(assetServiceProvider).fetchAll(_projectId);
      expect(list.first.metadata['score'], 95);
      expect(list.first.metadata['tags'], contains('ai'));
      expect(list.first.metadata['nested']['k'], 'v');
    });
  });

  // ── 20. Compatibilidade com asset sem campos opcionais ───────────────────
  group('Compatibilidade', () {
    test('asset sem campos opcionais é processado sem erros', () async {
      final minimal = Asset(
        id:        'm1',
        userId:    _uid,
        projectId: _projectId,
        name:      'Mínimo',
        type:      AssetType.other,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      when(() => svc.fetchAll(_projectId)).thenAnswer((_) async => [minimal]);

      final c = _container();
      addTearDown(c.dispose);

      final list = await c.read(assetServiceProvider).fetchAll(_projectId);
      expect(list.first.parentAssetId,    isNull);
      expect(list.first.subtype,          isNull);
      expect(list.first.niche,            isNull);
      expect(list.first.strategicPriority, isNull);
    });
  });
}
