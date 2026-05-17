import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  Future<UserProfile?> fetchProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final rows = await _client
        .from('user_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (rows == null) return null;
    return UserProfile.fromMap(rows);
  }

  Future<UserProfile> saveNiche(String niche) async {
    final userId = _client.auth.currentUser!.id;
    final profile = UserProfile(userId: userId, niche: niche);

    await _client
        .from('user_profiles')
        .upsert(profile.toUpsertMap(), onConflict: 'user_id');

    return profile;
  }
}
