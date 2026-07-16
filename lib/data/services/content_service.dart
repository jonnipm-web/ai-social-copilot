import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/content_item.dart';

class ContentService {
  final _client = Supabase.instance.client;

  Future<List<ContentItem>> fetchAll({String? projectId}) async {
    var query = _client.from(AppConstants.tableContentItems).select();
    if (projectId != null) query = query.eq('project_id', projectId);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => ContentItem.fromMap(r)).toList();
  }

  Future<ContentItem?> fetchById(String id) async {
    final row = await _client
        .from(AppConstants.tableContentItems)
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : ContentItem.fromMap(row);
  }

  Future<ContentItem> create(ContentItem item) async {
    final row = await _client
        .from(AppConstants.tableContentItems)
        .insert(item.toInsertMap())
        .select()
        .single();
    return ContentItem.fromMap(row);
  }

  Future<ContentItem> update(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(AppConstants.tableContentItems)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return ContentItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client
        .from(AppConstants.tableContentItems)
        .delete()
        .eq('id', id);
  }

  Future<void> upsertFromKnowledge({
    required String userId,
    String? projectId,
    required String knowledgeItemId,
    required String title,
    required String type,
    required String? description,
    required String? baseText,
    required String? niche,
    required String? targetAudience,
    required List<String> keywords,
    required int opportunityScore,
    String language = 'pt-BR',
  }) async {
    // Verifica se já existe item vinculado a este knowledge_item_id
    final existing = await _client
        .from(AppConstants.tableContentItems)
        .select('id')
        .eq('knowledge_item_id', knowledgeItemId)
        .maybeSingle();

    final data = {
      'user_id':            userId,
      if (projectId != null) 'project_id': projectId,
      'knowledge_item_id':  knowledgeItemId,
      'title':              title,
      'type':               type,
      'description':        description,
      'base_text':          baseText,
      'niche':              niche,
      'target_audience':    targetAudience,
      'language':           language,
      'auto_generated':     true,
      'keywords':           keywords,
      'opportunity_score':  opportunityScore,
      'status':             'active',
      'updated_at':         DateTime.now().toUtc().toIso8601String(),
    };

    if (existing != null) {
      await _client
          .from(AppConstants.tableContentItems)
          .update(data)
          .eq('id', existing['id'] as String);
    } else {
      await _client
          .from(AppConstants.tableContentItems)
          .insert(data);
    }
  }
}
