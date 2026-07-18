import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/post_generation.dart';

class PostService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> improvePost(String text) async {
    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionImprove,
      body: {'text': text},
    );

    if (response.status != 200) {
      throw Exception('Erro ao processar o texto. Tente novamente.');
    }

    return response.data as Map<String, dynamic>;
  }

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<PostGeneration> saveGeneration(PostGeneration generation) async {
    final uid = _requireUid();
    final map = generation.toInsertMap();
    map['user_id'] = uid;
    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .insert(map)
        .select()
        .single();

    return PostGeneration.fromMap(rows);
  }

  Future<List<PostGeneration>> fetchHistory() async {
    final uid = _requireUid();
    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .map((row) => PostGeneration.fromMap(row))
        .toList();
  }

  Future<int> countMonthlyGenerations() async {
    final uid = _requireUid();
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .select('id')
        .eq('user_id', uid)
        .gte('created_at', firstOfMonth);

    return (rows as List).length;
  }

  Future<PostGeneration> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tablePostGenerations)
        .select()
        .eq('id', id)
        .single();

    return PostGeneration.fromMap(row);
  }
}
