import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/asset.dart';
import '../data/models/asset_score.dart';
import '../data/services/asset_score_service.dart';
import 'asset_provider.dart';

// ── Service provider ──────────────────────────────────────────────────────────

final assetScoreServiceProvider =
    Provider<AssetScoreService>((_) => AssetScoreService());

// ── Score de um asset individual ─────────────────────────────────────────────

/// Computa o score de um único asset.
/// Tenta o cache em metadata['score_cache'] primeiro; se ausente, computa.
final assetScoreProvider =
    Provider.autoDispose.family<AssetScore?, Asset>((ref, asset) {
  final svc = ref.read(assetScoreServiceProvider);
  final cached = svc.fromCache(asset);
  if (cached != null) return cached;
  return svc.compute(asset);
});

// ── Scores de todos os assets de um projeto ───────────────────────────────────

/// Retorna scores computados para todos os assets de um projeto.
/// Depende de assetsForProjectProvider — recomputa quando os assets recarregam.
final assetScoresForProjectProvider =
    FutureProvider.autoDispose.family<List<AssetScore>, String>(
  (ref, projectId) async {
    final assets =
        await ref.watch(assetsForProjectProvider(projectId).future);
    final svc = ref.read(assetScoreServiceProvider);
    return svc.computeAll(assets);
  },
);

// ── Notifier de score com reload explícito ────────────────────────────────────

class AssetScoreNotifier
    extends StateNotifier<AsyncValue<List<AssetScore>>> {
  AssetScoreNotifier(this._svc, this._assets)
      : super(const AsyncValue.loading()) {
    _compute();
  }

  final AssetScoreService    _svc;
  final List<Asset>          _assets;

  void _compute() {
    try {
      state = AsyncValue.data(_svc.computeAll(_assets));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Recomputa todos os scores (ex: após persistir novos dados de metadata).
  void recompute(List<Asset> updatedAssets) {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(_svc.computeAll(updatedAssets));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final assetScoreNotifierProvider = StateNotifierProvider.autoDispose
    .family<AssetScoreNotifier, AsyncValue<List<AssetScore>>, List<Asset>>(
  (ref, assets) => AssetScoreNotifier(
    ref.read(assetScoreServiceProvider),
    assets,
  ),
);
