import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/profile.dart';

class ProfileService {
  final _client = Supabase.instance.client;

  // ── Guards ────────────────────────────────────────────────────────────────

  String _requireUid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    return uid;
  }

  /// Lê a role diretamente do banco (não do estado local) e lança exceção
  /// se o chamador não for admin. Registra tentativas negadas.
  Future<void> _requireAdmin() async {
    final uid = _requireUid();
    final row = await _client
        .from(AppConstants.tableProfiles)
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final role = row?['role'] as String?;
    if (role != 'admin') {
      assert(() {
        debugPrint(
          '[Security] Acesso negado — operação admin por uid=$uid role=$role',
        );
        return true;
      }());
      debugPrint(
        '[Security] Acesso negado — operação admin por uid=$uid role=$role',
      );
      throw Exception('Operação reservada para administradores');
    }
  }

  // ── Profile do usuário logado ─────────────────────────────────────────────

  Future<Profile?> fetchCurrentProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final rows = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (rows == null) return null;
    final profile = Profile.fromMap(rows);

    // Auto-promoção via RPC SECURITY DEFINER no banco — evita UPDATE direto
    // que violaria o trigger de autorização de role.
    if (profile.email == AppConstants.adminEmail && profile.role != 'admin') {
      try {
        await _client.rpc('auto_promote_if_admin_email');
        return profile.copyWith(role: 'admin', monthlyLimit: 99999);
      } catch (_) {
        return profile;
      }
    }

    return profile;
  }

  Future<void> upsertProfile({
    required String id,
    required String email,
  }) async {
    final role = email == AppConstants.adminEmail ? 'admin' : 'free';
    final limit = email == AppConstants.adminEmail ? 99999 : 5;

    await _client.from(AppConstants.tableProfiles).upsert({
      'id':            id,
      'email':         email,
      'role':          role,
      'monthly_limit': limit,
    }, onConflict: 'id');
  }

  // ── Operações exclusivas de administrador ─────────────────────────────────

  Future<List<Profile>> fetchAllProfiles() async {
    await _requireAdmin();
    final rows = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Profile.fromMap(r)).toList();
  }

  Future<void> updateRole(String userId, String role) async {
    await _requireAdmin();
    final callerUid = _requireUid();

    if (callerUid == userId) {
      debugPrint('[Security] Admin bloqueado — tentativa de auto-promoção uid=$callerUid');
      throw Exception('Administrador não pode alterar a própria role');
    }

    final limit = AppConstants.limitForRole(role);
    await _client
        .from(AppConstants.tableProfiles)
        .update({'role': role, 'monthly_limit': limit})
        .eq('id', userId);
  }

  Future<void> setActive(String userId, bool isActive) async {
    await _requireAdmin();
    final callerUid = _requireUid();

    if (callerUid == userId) {
      debugPrint('[Security] Admin bloqueado — tentativa de auto-desativação uid=$callerUid');
      throw Exception('Administrador não pode desativar a própria conta');
    }

    await _client
        .from(AppConstants.tableProfiles)
        .update({'is_active': isActive})
        .eq('id', userId);
  }
}
