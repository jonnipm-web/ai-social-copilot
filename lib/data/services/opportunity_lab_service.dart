import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/opportunity_lab_item.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_exceptions.dart';
import 'content_localization_service.dart';

class OpportunityLabService {
  OpportunityLabService({RowLocalizer? localizer}) : _localizer = localizer ?? identityLocalizer;

  // R16 — presentation localization of persisted content (never modifies the
  // stored row; see content_localization_service.dart).
  final RowLocalizer _localizer;

  Future<List<Map<String, dynamic>>> _loc(String table, dynamic rows) =>
      _localizer(table, (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList());

  Future<Map<String, dynamic>> _locOne(String table, Map<String, dynamic> row) async =>
      (await _localizer(table, [row])).first;

  // Lazy getter, not an eager field initializer -- same fix as
  // MarketAnalysisService/context_copilot_provider.dart: any widget test
  // that mounts a screen watching opportunityLabNotifierProvider (without
  // calling a query method) previously threw "You must initialize the
  // supabase instance" in a plain test process. Deferring the access to
  // first real query matches the app's own normal flow, where Supabase is
  // always initialized long before any query.
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<OpportunityLabItem>> fetchAll({String? projectId, String? status}) async {
    var filter = _client
        .from(AppConstants.tableOpportunityLab)
        .select();

    if (projectId != null) filter = filter.eq('project_id', projectId);
    if (status != null)    filter = filter.eq('status', status);

    final rows = await filter.order('final_score', ascending: false);
    return (await _loc('opportunity_lab', rows)).map((r) => OpportunityLabItem.fromMap(r)).toList();
  }

  Future<OpportunityLabItem> create(OpportunityLabItem item) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();

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
    return row == null ? null : OpportunityLabItem.fromMap(await _locOne('opportunity_lab', row));
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
