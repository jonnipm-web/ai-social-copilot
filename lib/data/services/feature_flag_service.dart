import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/feature_flag.dart';
import '../../core/constants/app_constants.dart';

class FeatureFlagService {
  final _client = Supabase.instance.client;

  Future<List<FeatureFlag>> fetchAll() async {
    final rows = await _client.from(AppConstants.tableFeatureFlags).select();
    return (rows as List).map((r) => FeatureFlag.fromMap(r)).toList();
  }

  Future<bool> isEnabled(String featureName) async {
    final row = await _client
        .from(AppConstants.tableFeatureFlags)
        .select('enabled')
        .eq('feature_name', featureName)
        .maybeSingle();
    return row?['enabled'] as bool? ?? false;
  }

  Future<Map<String, bool>> fetchAllEnabled() async {
    final flags = await fetchAll();
    return {for (final f in flags) f.featureName: f.enabled};
  }
}
