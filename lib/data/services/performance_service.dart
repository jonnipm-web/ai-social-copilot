import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/performance_metrics.dart';

class PerformanceService {
  final _client = Supabase.instance.client;

  static const _table = 'performance_metrics';

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<PerformanceMetrics>> fetchAll() async {
    final uid = _requireUid();
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => PerformanceMetrics.fromMap(r)).toList();
  }

  Future<List<PerformanceMetrics>> fetchForCampaign(String campaignId) async {
    final uid = _requireUid();
    final rows = await _client
        .from(_table)
        .select()
        .eq('campaign_id', campaignId)
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => PerformanceMetrics.fromMap(r)).toList();
  }

  Future<PerformanceMetrics> create(PerformanceMetrics metrics) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final data = metrics.toInsertMap();
    data['user_id'] = uid;

    final row = await _client
        .from(_table)
        .insert(data)
        .select()
        .single();

    return PerformanceMetrics.fromMap(row);
  }

  Future<PerformanceMetrics> update(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(_table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return PerformanceMetrics.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
