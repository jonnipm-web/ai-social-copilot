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

  Future<PostGeneration> saveGeneration(PostGeneration generation) async {
    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .insert(generation.toInsertMap())
        .select()
        .single();

    return PostGeneration.fromMap(rows);
  }

  Future<List<PostGeneration>> fetchHistory() async {
    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .map((row) => PostGeneration.fromMap(row))
        .toList();
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
