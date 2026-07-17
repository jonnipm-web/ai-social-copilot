import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/opportunity_lab_item.dart';
import '../../core/constants/app_constants.dart';

class OpportunityLabService {
  final _client = Supabase.instance.client;

  Future<List<OpportunityLabItem>> fetchAll({String? projectId, String? status}) async {
    var filter = _client
        .from(AppConstants.tableOpportunityLab)
        .select();

    if (projectId != null) filter = filter.eq('project_id', projectId);
    if (status != null)    filter = filter.eq('status', status);

    final rows = await filter.order('final_score', ascending: false);
    return rows.map((r) => OpportunityLabItem.fromMap(r)).toList();
  }

  Future<OpportunityLabItem> create(OpportunityLabItem item) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final map = item.toInsertMap();
    map['user_id'] = uid;

    final row = await _client
        .from(AppConstants.tableOpportunityLab)
        .insert(map)
        .select()
        .single();
    return OpportunityLabItem.fromMap(row);
  }

  Future<OpportunityLabItem> updateStatus(String id, String status) async {
    final row = await _client
        .from(AppConstants.tableOpportunityLab)
        .update({'status': status})
        .eq('id', id)
        .select()
        .single();
    return OpportunityLabItem.fromMap(row);
  }

  Future<OpportunityLabItem?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableOpportunityLab)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : OpportunityLabItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableOpportunityLab).delete().eq('id', id);
  }

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    return {
      'total':    list.length,
      'pending':  list.where((i) => i.status == 'pending').length,
      'approved': list.where((i) => i.status == 'approved').length,
      'rejected': list.where((i) => i.status == 'rejected').length,
    };
  }
}
