import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/advisor_profile.dart';
import '../../core/constants/app_constants.dart';

class AdvisorService {
  final _client = Supabase.instance.client;

  Future<AdvisorProfile?> fetchProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _client
        .from(AppConstants.tableAdvisorProfiles)
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    return row == null ? null : AdvisorProfile.fromMap(row);
  }

  Future<AdvisorProfile> saveProfile({
    required String advisorName,
    required String advisorRole,
    required String advisorStyle,
    String advisorAvatar = '',
    Map<String, dynamic> personalityJson = const {},
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');

    final data = AdvisorProfile(
      id:                    '',
      userId:                uid,
      advisorName:           advisorName,
      advisorRole:           advisorRole,
      advisorStyle:          advisorStyle,
      advisorAvatar:         advisorAvatar,
      advisorPersonalityJson: personalityJson,
      createdAt:             DateTime.now(),
    ).toInsertMap();

    final row = await _client
        .from(AppConstants.tableAdvisorProfiles)
        .upsert(data, onConflict: 'user_id')
        .select()
        .single();
    return AdvisorProfile.fromMap(row);
  }

  Future<bool> hasProfile() async {
    final profile = await fetchProfile();
    return profile != null;
  }
}
