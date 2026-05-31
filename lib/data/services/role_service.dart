import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_role.dart';

class RoleService {
  final _db = Supabase.instance.client;

  Future<UserPermission> getUserPermission() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return UserPermission.defaultUser;

    final roleRow = await _db
        .from('user_roles')
        .select('role')
        .eq('user_id', uid)
        .maybeSingle();

    final role = UserRoleX.fromString(roleRow?['role'] as String?);

    if (role == UserRole.admin) {
      return UserPermission(role: role);
    }

    final flagRows = await _db
        .from('feature_flags')
        .select('flag_name, enabled')
        .eq('user_id', uid)
        .eq('enabled', true);

    final flags = <String, bool>{
      for (final r in flagRows)
        (r['flag_name'] as String): r['enabled'] as bool,
    };

    return UserPermission(role: role, flags: flags);
  }

  Future<void> setUserRole(String userId, String role) async {
    await _db.from('user_roles').upsert({
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> setFeatureFlag(
      String userId, String flag, bool enabled) async {
    await _db.from('feature_flags').upsert({
      'user_id': userId,
      'flag_name': flag,
      'enabled': enabled,
    });
  }
}
