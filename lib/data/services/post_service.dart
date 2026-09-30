import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/post_generation.dart';

/// R16 — request body for `improve-post`, extracted so it is unit-testable
/// without a Supabase client.
Map<String, dynamic> buildImprovePostBody(
  String text, {
  required String language,
  String? idempotencyKey,
}) =>
    {
      'text': text,
      'language': language,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

class PostService {
  final _client = Supabase.instance.client;

  /// R16 — [language] is the PRESENTATION language ('pt-BR'/'en-US', from
  /// `outputLanguageCodeProvider`); it decides the language of the AI output,
  /// regardless of the language the original post was written in.
  Future<Map<String, dynamic>> improvePost(
    String text, {
    required String language,
    String? idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionImprove,
      body: buildImprovePostBody(text, language: language, idempotencyKey: idempotencyKey),
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

  Future<int> countMonthlyGenerations() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

    final rows = await _client
        .from(AppConstants.tablePostGenerations)
        .select('id')
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
