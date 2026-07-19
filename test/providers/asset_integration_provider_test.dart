/// Testes dos providers por asset — opportunityLabByAssetProvider e actionQueueByAssetProvider.
///
/// Cenários:
///   1. opportunityLabByAssetProvider filtra por assetId
///   2. actionQueueByAssetProvider filtra por assetId
///   3. asset sem oportunidades retorna lista vazia
///   4. asset sem ações retorna lista vazia
///   5. usuario não autenticado — fetchByAsset lança exceção
///   6. assetId vazio — fetchByAsset lança exceção

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_social_copilot/data/models/action_queue_item.dart';
import 'package:ai_social_copilot/data/models/opportunity_lab_item.dart';
import 'package:ai_social_copilot/data/services/opportunity_lab_service.dart';
import 'package:ai_social_copilot/data/services/action_queue_service.dart';
import 'package:ai_social_copilot/providers/opportunity_lab_provider.dart';
import 'package:ai_social_copilot/providers/action_queue_provider.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockOpportunityLabService extends Mock implements OpportunityLabService {}
class MockActionQueueService    extends Mock implements ActionQueueService    {}

// ── Helpers ───────────────────────────────────────────────────────────────────

const _assetId = 'asset-test-1';

OpportunityLabItem _opp({String? assetId}) => OpportunityLabItem(
      id:            'opp-1',
      userId:        'user-a',
      title:         'Opp Asset',
      createdAt:     DateTime(2026),
      assetId:       assetId,
    );

ActionQueueItem _action({String? assetId}) => ActionQueueItem(
      id:        'act-1',
      userId:    'user-a',
      title:     'Action Asset',
      createdAt: DateTime(2026),
      assetId:   assetId,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockOpportunityLabService oppSvc;
  late MockActionQueueService    actSvc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url:     'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
    registerFallbackValue(_opp());
    registerFallbackValue(_action());
  });

  setUp(() {
    oppSvc = MockOpportunityLabService();
    actSvc = MockActionQueueService();
  });

  ProviderContainer _container() => ProviderContainer(
    overrides: [
      opportunityLabServiceProvider.overrideWithValue(oppSvc),
      actionQueueServiceProvider.overrideWithValue(actSvc),
    ],
  );

  // ── 1. opportunityLabByAssetProvider ────────────────────────────────────
  group('opportunityLabByAssetProvider', () {
    test('1. retorna oportunidades do asset especificado', () async {
      final opp = _opp(assetId: _assetId);
      when(() => oppSvc.fetchByAsset(_assetId))
          .thenAnswer((_) async => [opp]);

      final c = _container();
      addTearDown(c.dispose);

      final result = await c.read(opportunityLabByAssetProvider(_assetId).future);
      expect(result, hasLength(1));
      expect(result.first.assetId, _assetId);
    });

    test('3. asset sem oportunidades retorna lista vazia', () async {
      when(() => oppSvc.fetchByAsset('asset-vazio'))
          .thenAnswer((_) async => []);

      final c = _container();
      addTearDown(c.dispose);

      final result =
          await c.read(opportunityLabByAssetProvider('asset-vazio').future);
      expect(result, isEmpty);
    });

    test('5. usuario não autenticado lança exceção', () async {
      when(() => oppSvc.fetchByAsset(any()))
          .thenThrow(Exception('Não autenticado'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(opportunityLabServiceProvider).fetchByAsset(_assetId),
        throwsA(isA<Exception>().having(
          (e) => e.toString(), 'message', contains('autenticado'),
        )),
      );
    });

    test('6. assetId vazio lança exceção', () async {
      when(() => oppSvc.fetchByAsset(''))
          .thenThrow(Exception('assetId inválido'));

      final c = _container();
      addTearDown(c.dispose);

      expect(
        () => c.read(opportunityLabServiceProvider).fetchByAsset(''),
        throwsA(isA<Exception>().having(
          (e) => e.toString(), 'message', contains('inválido'),
        )),
      );
    });
  });

  // ── 2. actionQueueByAssetProvider ────────────────────────────────────────
  group('actionQueueByAssetProvider', () {
    test('2. retorna ações do asset especificado', () async {
      final act = _action(assetId: _assetId);
      when(() => actSvc.fetchByAsset(_assetId))
          .thenAnswer((_) async => [act]);

      final c = _container();
      addTearDown(c.dispose);

      final result =
          await c.read(actionQueueByAssetProvider(_assetId).future);
      expect(result, hasLength(1));
      expect(result.first.assetId, _assetId);
    });

    test('4. asset sem ações retorna lista vazia', () async {
      when(() => actSvc.fetchByAsset('asset-sem-acoes'))
          .thenAnswer((_) async => []);

      final c = _container();
      addTearDown(c.dispose);

      final result =
          await c.read(actionQueueByAssetProvider('asset-sem-acoes').future);
      expect(result, isEmpty);
    });
  });
}
