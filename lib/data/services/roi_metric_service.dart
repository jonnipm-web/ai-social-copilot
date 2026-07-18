import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/roi_metric.dart';
import '../../core/constants/app_constants.dart';

class RoiMetricService {
  final _client = Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<RoiMetric>> fetchAll({String? projectId}) async {
    final uid = _requireUid();
    var query = _client
        .from(AppConstants.tableRoiMetrics)
        .select()
        .eq('user_id', uid);
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
    return rows.map((r) => RoiMetric.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<RoiMetric> create({
    required String metricType,
    required double metricValue,
    String? projectId,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');

    final row = await _client
        .from(AppConstants.tableRoiMetrics)
        .insert({
          'user_id':      uid,
          'project_id':   projectId,
          'metric_type':  metricType,
          'metric_value': metricValue,
          'notes':        notes,
        })
        .select()
        .single();

    return RoiMetric.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableRoiMetrics).delete().eq('id', id);
  }

  Future<Map<String, double>> summary({String? projectId}) async {
    final metrics = await fetchAll(projectId: projectId);
    final map = <String, double>{};
    for (final m in metrics) {
      map[m.metricType] = (map[m.metricType] ?? 0) + m.metricValue;
    }
    return map;
  }
}
