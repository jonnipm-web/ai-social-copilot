import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/action_queue_item.dart';
import '../../core/constants/app_constants.dart';

class ActionQueueService {
  final _client = Supabase.instance.client;

  Future<List<ActionQueueItem>> fetchAll({String? projectId, String? status}) async {
    var query = _client
        .from(AppConstants.tableActionQueue)
        .select()
        .order('priority', ascending: true);

    if (projectId != null) {
      query = query.eq('project_id', projectId) as dynamic;
    }
    if (status != null) {
      query = query.eq('status', status) as dynamic;
    }

    final rows = await query;
    return (rows as List).map((r) => ActionQueueItem.fromMap(r)).toList();
  }

  Future<ActionQueueItem> create(ActionQueueItem item) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final map = item.toInsertMap();
    map['user_id'] = uid;

    final row = await _client
        .from(AppConstants.tableActionQueue)
        .insert(map)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
  }

  Future<ActionQueueItem> updateStatus(String id, String status) async {
    final row = await _client
        .from(AppConstants.tableActionQueue)
        .update({'status': status})
        .eq('id', id)
        .select()
        .single();
    return ActionQueueItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableActionQueue).delete().eq('id', id);
  }

  Future<List<ActionQueueItem>> fetchPending() =>
      fetchAll(status: 'pending');

  Future<Map<String, int>> summary() async {
    final list = await fetchAll();
    return {
      'total':     list.length,
      'pending':   list.where((i) => i.status == 'pending').length,
      'executing': list.where((i) => i.status == 'executing').length,
      'completed': list.where((i) => i.status == 'completed').length,
    };
  }
}
