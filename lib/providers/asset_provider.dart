import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/asset.dart';
import '../data/services/asset_service.dart';

// ── Service provider ──────────────────────────────────────────────────────────

final assetServiceProvider =
    Provider<AssetServiceInterface>((_) => AssetService());

// ── Read-only providers ───────────────────────────────────────────────────────

/// Todos os assets de um projeto. Escopo: sessão (user_id) + project_id.
final assetsForProjectProvider =
    FutureProvider.autoDispose.family<List<Asset>, String>((ref, projectId) {
  return ref.read(assetServiceProvider).fetchAll(projectId);
});

/// Asset por ID. Retorna null se não encontrado ou não pertence ao usuário.
final assetByIdProvider =
    FutureProvider.autoDispose.family<Asset?, String>((ref, assetId) {
  return ref.read(assetServiceProvider).fetchById(assetId);
});

/// Filhos diretos de um asset pai.
final assetChildrenProvider =
    FutureProvider.autoDispose.family<List<Asset>, String>((ref, parentAssetId) {
  return ref.read(assetServiceProvider).fetchChildren(parentAssetId);
});

// ── Mutation notifier ─────────────────────────────────────────────────────────

/// Notifier de assets com suporte a CRUD para um projeto específico.
/// Padrão: StateNotifier<AsyncValue<...>> — consistente com o resto do projeto.
class AssetsNotifier extends StateNotifier<AsyncValue<List<Asset>>> {
  AssetsNotifier(this._svc, this._projectId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final AssetServiceInterface _svc;
  final String _projectId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _svc.fetchAll(_projectId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Asset> create(Map<String, dynamic> data) async {
    final asset = await _svc.create({...data, 'project_id': _projectId});
    state = AsyncValue.data([...?state.valueOrNull, asset]);
    return asset;
  }

  Future<Asset> update(String assetId, Map<String, dynamic> data) async {
    final asset = await _svc.update(assetId, data);
    state = state.whenData(
      (list) => [for (final a in list) a.id == assetId ? asset : a],
    );
    return asset;
  }

  Future<void> archive(String assetId) async {
    final asset = await _svc.archive(assetId);
    state = state.whenData(
      (list) => [for (final a in list) a.id == assetId ? asset : a],
    );
  }

  Future<void> restore(String assetId) async {
    final asset = await _svc.restore(assetId);
    state = state.whenData(
      (list) => [for (final a in list) a.id == assetId ? asset : a],
    );
  }

  Future<void> delete(String assetId) async {
    final list = state.valueOrNull ?? [];
    state = AsyncValue.data(list.where((a) => a.id != assetId).toList());
    try {
      await _svc.delete(assetId);
    } catch (e) {
      state = AsyncValue.data(list);
      rethrow;
    }
  }
}

final assetsNotifierProvider = StateNotifierProvider.autoDispose
    .family<AssetsNotifier, AsyncValue<List<Asset>>, String>(
  (ref, projectId) => AssetsNotifier(
    ref.read(assetServiceProvider),
    projectId,
  ),
);
