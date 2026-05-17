import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../models/post_generation.dart';

class PostService {
  final _client = Supabase.instance.client;

  Future<Map<String, dynamic>> improvePost(
    String text, {
    File? imageFile,
    String? nicheHint,
  }) async {
    final Map<String, dynamic> body = {};

    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      body['image_base64'] = base64Encode(bytes);
      body['image_media_type'] = _mediaType(imageFile.path);
      if (text.isNotEmpty) body['text'] = text;
    } else {
      body['text'] = text;
    }
    if (nicheHint != null && nicheHint.isNotEmpty) {
      body['niche_hint'] = nicheHint;
    }

    final response = await _client.functions.invoke(
      AppConstants.edgeFunctionImprove,
      body: body,
    );

    if (response.status == 429) throw const LimitReachedException();
    if (response.status == 401) throw Exception('Sessão expirada. Faça login novamente.');
    if (response.status != 200) throw Exception('Erro ao processar. Tente novamente.');

    return response.data as Map<String, dynamic>;
  }

  String _mediaType(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
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

    return rows.map((row) => PostGeneration.fromMap(row)).toList();
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
