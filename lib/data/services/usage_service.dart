import 'package:supabase_flutter/supabase_flutter.dart';

class UsageService {
  final _client = Supabase.instance.client;

  Future<int> getCurrentMonthCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final now = DateTime.now();
    final yearMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final row = await _client
        .from('generation_usage')
        .select('count')
        .eq('user_id', userId)
        .eq('year_month', yearMonth)
        .maybeSingle();

    return (row?['count'] as int?) ?? 0;
  }
}
