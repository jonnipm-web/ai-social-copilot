/// Testes do AssetScoreProvider — integração com Riverpod.
///
/// Cenários:
///   1. assetScoreProvider retorna score para asset sem cache
///   2. assetScoreProvider usa cache quando disponível
///   3. assetScoreNotifierProvider computa lista ordenada
///   4. assetScoreNotifierProvider.recompute atualiza estado
///   5. lista vazia resulta em lista de scores vazia
///   6. dois containers são independentes

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_social_copilot/data/models/asset.dart';
import 'package:ai_social_copilot/data/models/asset_score.dart';
import 'package:ai_social_copilot/data/services/asset_score_service.dart';
import 'package:ai_social_copilot/providers/asset_score_provider.dart';

// ── Mock ──────────────────────────────────────────────────────────────────────

class MockAssetScoreService extends Mock implements AssetScoreService {}

// ── Helpers ───────────────────────────────────────────────────────────────────

Asset _asset({
  String id    = 'a1',
  AssetStatus status = AssetStatus.idea,
  Map<String, dynamic> metadata = const {},
}) =>
    Asset(
      id:        id,
      userId:    'u1',
      projectId: 'p1',
      name:      'Ativo $id',
      type:      AssetType.product,
      status:    status,
      metadata:  metadata,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

AssetScore _score(Asset asset, {int score = 50}) => AssetScore(
      asset:          asset,
      potentialScore: score,
      maturityScore:  score,
      strategicScore: score,
      roiScore:       score,
      velocityScore:  score,
      assetScore:     score,
      recommendation: 'MANTER',
      confidence:     80,
      hasEnoughData:  true,
      strengths:      const ['Força A'],
      risks:          const [],
      missingData:    const [],
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late MockAssetScoreService svc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url:     'http://localhost:54321',
        anonKey: 'test-anon-key',
      );
    } catch (_) {}
    registerFallbackValue(_asset());
    registerFallbackValue(<Asset>[]);
  });

  setUp(() {
    svc = MockAssetScoreService();
  });

  ProviderContainer _container() => ProviderContainer(
    overrides: [assetScoreServiceProvider.overrideWithValue(svc)],
  );

  // ── 1. assetScoreProvider sem cache ──────────────────────────────────────
  group('assetScoreProvider — sem cache', () {
    test('computa score quando fromCache retorna null', () {
      final asset = _asset();
      final expected = _score(asset, score: 42);

      when(() => svc.fromCache(asset)).thenReturn(null);
      when(() => svc.compute(asset)).thenReturn(expected);

      final c = _container();
      addTearDown(c.dispose);

      final result = c.read(assetScoreProvider(asset));
      expect(result?.assetScore, 42);
      verify(() => svc.compute(asset)).called(1);
    });
  });

  // ── 2. assetScoreProvider com cache ──────────────────────────────────────
  group('assetScoreProvider — com cache', () {
    test('usa cache quando disponível sem chamar compute', () {
      final asset   = _asset();
      final cached  = _score(asset, score: 77);

      when(() => svc.fromCache(asset)).thenReturn(cached);

      final c = _container();
      addTearDown(c.dispose);

      final result = c.read(assetScoreProvider(asset));
      expect(result?.assetScore, 77);
      verifyNever(() => svc.compute(any()));
    });
  });

  // ── 3. assetScoreNotifierProvider — lista ordenada ───────────────────────
  group('AssetScoreNotifier — computeAll', () {
    test('estado inicial chama computeAll e retorna lista', () {
      final a1     = _asset(id: 'a1');
      final a2     = _asset(id: 'a2', status: AssetStatus.active);
      final s1     = _score(a1, score: 30);
      final s2     = _score(a2, score: 70);
      final assets = [a1, a2];

      when(() => svc.computeAll(assets)).thenReturn([s2, s1]);

      final c = _container();
      addTearDown(c.dispose);

      final state = c.read(assetScoreNotifierProvider(assets));
      expect(state.valueOrNull?.first.assetScore, 70);
      expect(state.valueOrNull?.last.assetScore,  30);
    });
  });

  // ── 4. recompute atualiza estado ─────────────────────────────────────────
  group('AssetScoreNotifier — recompute', () {
    test('recompute substitui estado com lista atualizada', () {
      final a1       = _asset(id: 'a1');
      final original = _score(a1, score: 20);
      final updated  = _score(a1, score: 80);

      // Usa a mesma referência de lista para garantir o mesmo provider instance
      final assets = [a1];
      when(() => svc.computeAll(assets)).thenReturn([original]);

      final c = _container();
      addTearDown(c.dispose);

      final notifier = c.read(assetScoreNotifierProvider(assets).notifier);
      expect(
        c.read(assetScoreNotifierProvider(assets)).valueOrNull?.first.assetScore,
        20,
      );

      when(() => svc.computeAll(assets)).thenReturn([updated]);
      notifier.recompute(assets);

      final state = c.read(assetScoreNotifierProvider(assets));
      expect(state.valueOrNull?.first.assetScore, 80);
    });
  });

  // ── 5. lista vazia ────────────────────────────────────────────────────────
  group('AssetScoreNotifier — lista vazia', () {
    test('lista de assets vazia resulta em scores vazia', () {
      when(() => svc.computeAll([])).thenReturn([]);

      final c = _container();
      addTearDown(c.dispose);

      final state = c.read(assetScoreNotifierProvider([]));
      expect(state.valueOrNull, isEmpty);
    });
  });

  // ── 6. containers independentes ──────────────────────────────────────────
  group('Isolamento de containers', () {
    test('dois containers com assets diferentes não compartilham estado', () {
      final a1 = _asset(id: 'x1');
      final a2 = _asset(id: 'x2', status: AssetStatus.active);
      final s1 = _score(a1, score: 10);
      final s2 = _score(a2, score: 90);

      when(() => svc.computeAll([a1])).thenReturn([s1]);
      when(() => svc.computeAll([a2])).thenReturn([s2]);

      final c1 = _container();
      final c2 = _container();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      final r1 = c1.read(assetScoreNotifierProvider([a1]));
      final r2 = c2.read(assetScoreNotifierProvider([a2]));

      expect(r1.valueOrNull?.first.assetScore, 10);
      expect(r2.valueOrNull?.first.assetScore, 90);
    });
  });
}
