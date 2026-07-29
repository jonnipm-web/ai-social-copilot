import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/executive_context.dart';

class ExecutiveContextService {
  final _client = Supabase.instance.client;
  static const _table = 'executive_contexts';

  String? get _uid => _client.auth.currentUser?.id;

  Future<ExecutiveContext?> fetchByProject(String projectId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('project_id', projectId)
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return _fromRow(row as Map<String, dynamic>);
    } catch (e) {
      _log('fetchByProject error: $e');
      return null;
    }
  }

  Future<List<ExecutiveContext>> fetchAllByUser() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', uid)
          .order('priority_score', ascending: false);
      return (rows as List)
          .map((r) => _fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('fetchAllByUser error: $e');
      return [];
    }
  }

  /// Upsert idempotente por project_id.
  /// Preserva decisões e riscos históricos se o campo não for passado.
  Future<ExecutiveContext?> upsert(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final payload = {
        ...data,
        'user_id':    uid,
        'updated_at': DateTime.now().toIso8601String(),
      };
      final row = await _client
          .from(_table)
          .upsert(payload, onConflict: 'project_id')
          .select()
          .single();
      return _fromRow(row as Map<String, dynamic>);
    } catch (e) {
      _log('upsert error: $e');
      return null;
    }
  }

  /// Registra que o check-in foi realizado.
  Future<void> markCheckInCompleted(String projectId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from(_table)
          .update({
            'check_in_due':    false,
            'last_activity_at': DateTime.now().toIso8601String(),
            'updated_at':      DateTime.now().toIso8601String(),
          })
          .eq('project_id', projectId)
          .eq('user_id', uid);
    } catch (e) {
      _log('markCheckInCompleted error: $e');
    }
  }

  /// Atualiza apenas o timestamp de última atividade.
  Future<void> updateLastActivity(String projectId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final now = DateTime.now().toIso8601String();
      await _client
          .from(_table)
          .upsert({
            'project_id':      projectId,
            'user_id':         uid,
            'last_activity_at': now,
            'updated_at':       now,
          }, onConflict: 'project_id')
          .select()
          .maybeSingle();
    } catch (e) {
      _log('updateLastActivity error: $e');
    }
  }

  Future<void> deleteByProject(String projectId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _client
          .from(_table)
          .delete()
          .eq('project_id', projectId)
          .eq('user_id', uid);
    } catch (e) {
      _log('deleteByProject error: $e');
    }
  }

  ExecutiveContext _fromRow(Map<String, dynamic> row) => ExecutiveContext(
        projectId:       row['project_id'] as String,
        userId:          row['user_id'] as String,
        executiveSummary: row['executive_summary'] as String? ?? '',
        keyDecisions:    _parseStringList(row['decisions']),
        openRisks:       _parseStringList(row['risks']),
        synergies:       _parseStringList(row['relationships']),
        currentStage:    'ideia',
        lastAnalysisAt:  row['last_analysis_at'] != null
            ? DateTime.tryParse(row['last_analysis_at'] as String)
            : null,
        lastCheckInAt:   row['last_activity_at'] != null
            ? DateTime.tryParse(row['last_activity_at'] as String)
            : null,
        checkInDueAt:    null,
        priorityScore:   row['priority_score'] as int? ?? 0,
        metadata:        (row['health'] as Map<String, dynamic>?) ?? {},
        updatedAt:       DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  List<String> _parseStringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return [];
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[ExecutiveContextService] $msg');
  }
}
