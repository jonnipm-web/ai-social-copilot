import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/calendar_item.dart';

class CalendarService {
  final _client = Supabase.instance.client;

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  Future<List<CalendarItem>> fetchAll() async {
    final uid = _requireUid();
    final rows = await _client
        .from(AppConstants.tableCalendarItems)
        .select()
        .eq('user_id', uid)
        .order('suggested_date');
    return (rows as List).map((r) => CalendarItem.fromMap(r)).toList();
  }

  Future<List<CalendarItem>> fetchByRange(DateTime start, DateTime end) async {
    final uid = _requireUid();
    final rows = await _client
        .from(AppConstants.tableCalendarItems)
        .select()
        .eq('user_id', uid)
        .gte('suggested_date', start.toIso8601String().substring(0, 10))
        .lte('suggested_date', end.toIso8601String().substring(0, 10))
        .order('suggested_date');
    return (rows as List).map((r) => CalendarItem.fromMap(r)).toList();
  }

  Future<CalendarItem> create(CalendarItem item) async {
    final uid = _requireUid();
    final map  = item.toInsertMap();
    map['user_id'] = uid;
    final row = await _client
        .from(AppConstants.tableCalendarItems)
        .insert(map)
        .select()
        .single();
    return CalendarItem.fromMap(row);
  }

  Future<CalendarItem> updateStatus(String id, String status) async {
    final row = await _client
        .from(AppConstants.tableCalendarItems)
        .update({'status': status, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return CalendarItem.fromMap(row);
  }

  Future<CalendarItem> update(String id, Map<String, dynamic> data) async {
    data['updated_at'] = DateTime.now().toUtc().toIso8601String();
    final row = await _client
        .from(AppConstants.tableCalendarItems)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return CalendarItem.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _client
        .from(AppConstants.tableCalendarItems)
        .delete()
        .eq('id', id);
  }
}
