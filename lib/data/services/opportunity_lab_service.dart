import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/opportunity_lab_item.dart';
import '../../core/constants/app_constants.dart';

class OpportunityLabService {
  final _client = Supabase.instance.client;

  Future<List<OpportunityLabItem>> fetchAll({String? projectId, String? status}) async {
    var query = _client
        .from(AppConstants.tableOpportunityLab)
        .select()
        .order('final_score', ascending: false);

    if (projectId != null) {
      query = query.eq('project_id', projectId) as dynamic;
    }
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }

    final rows = await query;
    return (rows as List).map((r) => OpportunityLabItem.fromMap(r)).toList();
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

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableOpportunityLab).delete().eq('id', id);
  }

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    return {
      'total':     list.length,
      'pending':   list.where((i) => i.status == 'pending').length,
      'approved':  list.where((i) => i.status == 'approved').length,
      'executing': list.where((i) => i.status == 'executing').length,
    };
  }
}
