import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_item.dart';

class ContentLibraryService {
  final _db = Supabase.instance.client;

  Future<List<ContentItem>> fetchAll({String? brandId, bool includeArchived = false}) async {
    var query = _db.from('content_library').select();
    if (brandId != null) query = query.eq('brand_id', brandId);
    if (!includeArchived) query = query.neq('status', 'archived');
    final rows = await query.order('created_at', ascending: false);
    return rows.map(ContentItem.fromMap).toList();
  }

  Future<ContentItem> fetchById(String id) async {
    final row = await _db.from('content_library').select().eq('id', id).single();
    return ContentItem.fromMap(row);
  }

  Future<ContentItem> create(ContentItem item) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final row = await _db
        .from('content_library')
        .insert({...item.toInsertMap(), 'user_id': uid})
        .select()
        .single();
    return ContentItem.fromMap(row);
  }

  Future<ContentItem> update(String id, Map<String, dynamic> fields) async {
    final row = await _db
        .from('content_library')
        .update(fields)
        .eq('id', id)
        .select()
        .single();
    return ContentItem.fromMap(row);
  }

  Future<void> setStatus(String id, String status) async {
    await _db.from('content_library').update({'status': status}).eq('id', id);
  }
}
