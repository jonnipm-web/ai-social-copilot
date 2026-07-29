import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_event.dart';

class ProjectEventService {
  final _client = Supabase.instance.client;
  static const _table = 'project_events';

  Future<List<ProjectEvent>> fetchByProject(String projectId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).map((r) => ProjectEvent.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProjectEvent>> fetchByUser(String userId) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return (rows as List).map((r) => ProjectEvent.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProjectEvent?> add(ProjectEvent event) async {
    try {
      final row = await _client
          .from(_table)
          .insert(event.toJson())
          .select()
          .single();
      return ProjectEvent.fromJson(row as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String eventId) async {
    try {
      await _client.from(_table).delete().eq('id', eventId);
    } catch (_) {}
  }

  /// Emite um evento padronizado sem lançar exceção.
  Future<void> emit({
    required String projectId,
    required String userId,
    required ProjectEventType type,
    required String title,
    String description = '',
    Map<String, dynamic> metadata = const {},
  }) =>
      add(ProjectEvent(
        id:          '',
        projectId:   projectId,
        userId:      userId,
        eventType:   type,
        title:       title,
        description: description,
        metadata:    metadata,
        createdAt:   DateTime.now(),
      )).then((_) {});
}
