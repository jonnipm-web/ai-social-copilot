import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/content_item.dart';

class ContentService {
  final _client = Supabase.instance.client;

  Future<List<ContentItem>> fetchAll() async {
    final rows = await _client
        .from(AppConstants.tableContentItems)
        .select()
        .order('created_at', ascending: false);
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
}
