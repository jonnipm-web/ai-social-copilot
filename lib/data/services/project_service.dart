import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../../core/constants/app_constants.dart';

/// Interface abstrata — permite mock em testes sem depender do Supabase.
abstract class ProjectServiceInterface {
  Future<List<Project>> fetchAll();
  Future<Project?> fetchById(String id);
  Future<Project> create(Map<String, dynamic> data);
  Future<Project> update(String id, Map<String, dynamic> data);
  Future<void> delete(String id);
}

class ProjectService implements ProjectServiceInterface {
  final _client = Supabase.instance.client;

  @override
  Future<List<Project>> fetchAll() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    final rows = await _client
        .from(AppConstants.tableProjects)
        .select()
        .eq('user_id', uid)
        .order('priority_score', ascending: false);
    return (rows as List).map((r) => Project.fromMap(r)).toList();
  }

  @override
  Future<Project?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Project.fromMap(row);
  }

  @override
  Future<Project> create(Map<String, dynamic> data) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Usuário não autenticado.');
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
