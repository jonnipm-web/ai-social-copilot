import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/profile.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  Future<Profile?> fetchCurrentProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final rows = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (rows == null) return null;
    return Profile.fromMap(rows);
  }

  Future<void> upsertProfile({
    required String id,
    required String email,
  }) async {
    // SEC-01: role and monthly_limit are server-controlled fields.
    // Do not write them from the client — the database trigger will reject it.
    // New users receive role='free' / monthly_limit=5 via the handle_new_user() trigger.
    await _client.from(AppConstants.tableProfiles).upsert({
      'id':    id,
      'email': email,
    }, onConflict: 'id');
  }

  // Admin: listar todos os perfis
  Future<List<Profile>> fetchAllProfiles() async {
    final rows = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Profile.fromMap(r)).toList();
  }

  // Admin: alterar papel de um usuário
  Future<void> updateRole(String userId, String role) async {
    final limit = AppConstants.limitForRole(role);
    await _client
        .from(AppConstants.tableProfiles)
        .update({'role': role, 'monthly_limit': limit})
        .eq('id', userId);
  }

  // Admin: ativar/desativar usuário
  Future<void> setActive(String userId, bool isActive) async {
    await _client
        .from(AppConstants.tableProfiles)
        .update({'is_active': isActive})
        .eq('id', userId);
  }
}
