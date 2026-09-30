import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_exceptions.dart';
import 'content_localization_service.dart';

/// Interface abstrata — permite mock em testes sem depender do Supabase.
abstract class ProjectServiceInterface {
  Future<List<Project>> fetchAll();
  Future<Project?> fetchById(String id);
  Future<Project> create(Map<String, dynamic> data);
  Future<Project> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

class ProjectService implements ProjectServiceInterface {
  ProjectService({RowLocalizer? localizer}) : _localizer = localizer ?? identityLocalizer;

  // R16 — presentation localization of persisted content (never modifies the
  // stored row; see content_localization_service.dart).
  final RowLocalizer _localizer;

  Future<List<Map<String, dynamic>>> _loc(String table, dynamic rows) =>
      _localizer(table, (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList());

  Future<Map<String, dynamic>> _locOne(String table, Map<String, dynamic> row) async =>
      (await _localizer(table, [row])).first;

  final _client = Supabase.instance.client;

  @override
  Future<List<Project>> fetchAll() async {
    final rows = await _client
        .from(AppConstants.tableProjects)
        .select()
        .order('priority_score', ascending: false);
    return (await _loc('projects', rows)).map((r) => Project.fromMap(r)).toList();
  }

  @override
  Future<Project?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Project.fromMap(await _locOne('projects', row));
  }

  @override
  Future<Project> create(Map<String, dynamic> data) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const NotAuthenticatedException();
    final row = await _client
        .from(AppConstants.tableProjects)
        .insert({...data, 'user_id': uid})
        .select()
        .single();
    return Project.fromMap(row);
  }

  @override
  Future<Project> update(String id, Map<String, dynamic> data) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Project.fromMap(row);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableProjects).delete().eq('id', id);
  }
}
