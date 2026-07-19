import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/asset.dart';

// ── Interface ─────────────────────────────────────────────────────────────────

abstract class AssetServiceInterface {
  Future<List<Asset>> fetchAll(String projectId);
  Future<Asset?> fetchById(String assetId);
  Future<List<Asset>> fetchChildren(String parentAssetId);
  Future<Asset> create(Map<String, dynamic> data);
  Future<Asset> update(String assetId, Map<String, dynamic> data);
  Future<Asset> archive(String assetId);
  Future<Asset> restore(String assetId);
  Future<void> delete(String assetId);
}

// ── Implementation ────────────────────────────────────────────────────────────

class AssetService implements AssetServiceInterface {
  final _client = Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) throw Exception('Não autenticado');
    return uid;
  }

  @override
  Future<List<Asset>> fetchAll(String projectId) async {
    if (projectId.isEmpty) throw Exception('projectId inválido');
    final uid = _requireUid();
    final rows = await _client
        .from(AppConstants.tableAssets)
        .select()
        .eq('user_id', uid)
        .eq('project_id', projectId)
        .order('strategic_priority', ascending: false);
    return (rows as List).map((r) => Asset.fromMap(r)).toList();
  }

  @override
  Future<Asset?> fetchById(String assetId) async {
    if (assetId.isEmpty) throw Exception('assetId inválido');
    final uid = _requireUid();
    final row = await _client
        .from(AppConstants.tableAssets)
        .select()
        .eq('id', assetId)
        .eq('user_id', uid)
        .maybeSingle();
    return row == null ? null : Asset.fromMap(row);
  }

  @override
  Future<List<Asset>> fetchChildren(String parentAssetId) async {
    if (parentAssetId.isEmpty) throw Exception('parentAssetId inválido');
    final uid = _requireUid();
    final rows = await _client
        .from(AppConstants.tableAssets)
        .select()
        .eq('user_id', uid)
        .eq('parent_asset_id', parentAssetId)
        .order('strategic_priority', ascending: false);
    return (rows as List).map((r) => Asset.fromMap(r)).toList();
  }

  @override
  Future<Asset> create(Map<String, dynamic> data) async {
    final uid = _requireUid();

    final projectId = data['project_id'] as String?;
    if (projectId == null || projectId.isEmpty) {
      throw Exception('project_id obrigatório');
    }

    // Valida ownership do projeto
    await _assertProjectOwnership(uid, projectId);

    // Valida ownership do asset pai, se fornecido
    final parentId = data['parent_asset_id'] as String?;
    if (parentId != null && parentId.isNotEmpty) {
      await _assertParentOwnership(uid, projectId, parentId);
    }

    // user_id vem da sessão — nunca do payload do cliente
    final row = await _client
        .from(AppConstants.tableAssets)
        .insert({...data, 'user_id': uid})
        .select()
        .single();
    return Asset.fromMap(row);
  }

  @override
  Future<Asset> update(String assetId, Map<String, dynamic> data) async {
    if (assetId.isEmpty) throw Exception('assetId inválido');
    final uid = _requireUid();
    await _assertAssetOwnership(uid, assetId);

    final row = await _client
        .from(AppConstants.tableAssets)
        .update({...data, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', assetId)
        .eq('user_id', uid)
        .select()
        .single();
    return Asset.fromMap(row);
  }

  @override
  Future<Asset> archive(String assetId) async {
    return update(assetId, {'status': AssetStatus.archived.dbValue});
  }

  @override
  Future<Asset> restore(String assetId) async {
    return update(assetId, {'status': AssetStatus.active.dbValue});
  }

  @override
  Future<void> delete(String assetId) async {
    if (assetId.isEmpty) throw Exception('assetId inválido');
    final uid = _requireUid();
    await _assertAssetOwnership(uid, assetId);
    await _client
        .from(AppConstants.tableAssets)
        .delete()
        .eq('id', assetId)
        .eq('user_id', uid);
  }

  // ── Ownership guards ───────────────────────────────────────────────────────

  Future<void> _assertProjectOwnership(String uid, String projectId) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .select('id')
        .eq('id', projectId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) {
      throw Exception('Projeto não pertence ao usuário ou não existe');
    }
  }

  Future<void> _assertAssetOwnership(String uid, String assetId) async {
    final row = await _client
        .from(AppConstants.tableAssets)
        .select('id')
        .eq('id', assetId)
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) {
      throw Exception('Asset não pertence ao usuário ou não existe');
    }
  }

  Future<void> _assertParentOwnership(
    String uid,
    String projectId,
    String parentAssetId,
  ) async {
    final row = await _client
        .from(AppConstants.tableAssets)
        .select('id')
        .eq('id', parentAssetId)
        .eq('user_id', uid)
        .eq('project_id', projectId)
        .maybeSingle();
    if (row == null) {
      throw Exception(
        'Asset pai não pertence ao mesmo usuário/projeto ou não existe',
      );
    }
  }
}
