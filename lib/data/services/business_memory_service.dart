import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_memory.dart';
import '../../core/constants/app_constants.dart';

class BusinessMemoryService {
  final _client = Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<BusinessMemory>> fetchAll({String? projectId, String? memoryType}) async {
    final uid = _requireUid();
    // Filters must be applied before order() — order() returns PostgrestTransformBuilder
    // which does not expose .eq(). Applying filters first keeps the type as
    // PostgrestFilterBuilder throughout the chain.
    var query = _client
        .from(AppConstants.tableBusinessMemory)
        .select()
        .eq('user_id', uid);

    if (projectId != null) query = query.eq('project_id', projectId);
    if (memoryType != null) query = query.eq('memory_type', memoryType);

    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => BusinessMemory.fromMap(r)).toList();
  }

  Future<BusinessMemory> create({
    required String memoryType,
    required String title,
    String content = '',
    int confidenceScore = 50,
    String source = '',
    String? projectId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final row = await _client
        .from(AppConstants.tableBusinessMemory)
        .insert(BusinessMemory(
          id:              '',
          userId:          uid,
          projectId:       projectId,
          memoryType:      memoryType,
          title:           title,
          content:         content,
          confidenceScore: confidenceScore,
          source:          source,
          createdAt:       DateTime.now(),
        ).toInsertMap())
        .select()
        .single();
    return BusinessMemory.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableBusinessMemory).delete().eq('id', id);
  }

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    final map = <String, int>{};
    for (final m in list) {
      map[m.memoryType] = (map[m.memoryType] ?? 0) + 1;
    }
    return map;
  }

  Future<void> recordOpportunity({
    required String title,
    String content = '',
    String? projectId,
    String status = 'generated',
  }) async {
    await create(
      memoryType:      'opportunity',
      title:           title,
      content:         content,
      confidenceScore: 70,
      source:          'opportunity_discovery',
      projectId:       projectId,
    );
  }

  Future<void> recordCampaign({
    required String title,
    required bool success,
    String? projectId,
  }) async {
    await create(
      memoryType:      success ? 'success' : 'failure',
      title:           title,
      content:         success ? 'Campanha bem-sucedida' : 'Campanha mal-sucedida',
      confidenceScore: 80,
      source:          'campaigns',
      projectId:       projectId,
    );
  }

  Future<void> recordRoi({
    required double roiValue,
    required String description,
    String? projectId,
  }) async {
    await create(
      memoryType:      'revenue',
      title:           'ROI: R\$ ${roiValue.toStringAsFixed(2)}',
      content:         description,
      confidenceScore: 90,
      source:          'roi_tracker',
      projectId:       projectId,
    );
  }
}
