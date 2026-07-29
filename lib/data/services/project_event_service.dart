import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project_event.dart';

class ProjectEventService {
  final _client = Supabase.instance.client;
  static const _table = 'project_events';

  String? get _uid => _client.auth.currentUser?.id;

  Future<List<ProjectEvent>> fetchByProject(
    String projectId, {
    String? filterGroup,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(limit);
      final rows = await query;
      final events = (rows as List)
          .map((r) => ProjectEvent.fromJson(r as Map<String, dynamic>))
          .toList();
      if (filterGroup != null && filterGroup != 'Todos') {
        return events.where((e) => e.filterGroup == filterGroup).toList();
      }
      return events;
    } catch (e) {
      _log('fetchByProject error: $e');
      return [];
    }
  }

  Future<List<ProjectEvent>> fetchByUser(String userId, {int limit = 100}) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => ProjectEvent.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('fetchByUser error: $e');
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
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — evento idempotente já existe, não é erro
      if (e.code == '23505') {
        _log('Evento idempotente ignorado: ${event.idempotencyKey}');
        return null;
      }
      _log('add error: ${e.message}');
      return null;
    } catch (e) {
      _log('add error: $e');
      return null;
    }
  }

  Future<void> delete(String eventId) async {
    try {
      await _client.from(_table).delete().eq('id', eventId);
    } catch (e) {
      _log('delete error: $e');
    }
  }

  /// Emite um evento padronizado.
  ///
  /// [idempotencyKey]: chave única para evitar duplicação em retries/rebuilds.
  /// Formato recomendado: `'${projectId}_${eventType}_${sourceEntityId ?? ''}'`.
  /// Não lança exceção — falhas são logadas e ignoradas.
  Future<void> emit({
    required String projectId,
    required ProjectEventType type,
    required String title,
    String description = '',
    Map<String, dynamic> metadata = const {},
    String? sourceModule,
    String? sourceEntityId,
    String? idempotencyKey,
  }) async {
    final uid = _uid;
    if (uid == null) {
      _log('emit ignorado: usuário não autenticado');
      return;
    }

    // Gera chave de idempotência padrão se não fornecida e há uma entidade fonte.
    // Usa type.name (nome do enum Dart) como sufixo — único e consistente.
    final key = idempotencyKey ??
        (sourceEntityId != null
            ? '${projectId}_${type.name}_$sourceEntityId'
            : null);

    await add(ProjectEvent(
      id:             '',
      projectId:      projectId,
      userId:         uid,
      eventType:      type,
      title:          title,
      description:    description,
      metadata:       metadata,
      sourceModule:   sourceModule,
      sourceEntityId: sourceEntityId,
      idempotencyKey: key,
      createdAt:      DateTime.now(),
    ));
  }

  void _log(String msg) {
    // Usa debugPrint para visibilidade nos logs de desenvolvimento
    // ignore: avoid_print
    print('[ProjectEventService] $msg');
  }
}
