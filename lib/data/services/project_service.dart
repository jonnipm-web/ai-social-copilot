import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project.dart';
import '../../core/constants/app_constants.dart';

class ProjectService {
  final _client = Supabase.instance.client;

  Future<List<Project>> fetchAll() async {
    final rows = await _client
        .from(AppConstants.tableProjects)
        .select()
        .order('priority_score', ascending: false);
    return (rows as List).map((r) => Project.fromMap(r)).toList();
  }

  Future<Project?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Project.fromMap(row);
  }

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

  Future<Project> update(String id, Map<String, dynamic> data) async {
    final row = await _client
        .from(AppConstants.tableProjects)
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Project.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client.from(AppConstants.tableProjects).delete().eq('id', id);
  }
}
