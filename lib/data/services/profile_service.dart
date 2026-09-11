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
    final profile = Profile.fromMap(rows);

    // Auto-promove admin pelo email configurado. IVE-COMMERCIAL-RELEASE-
    // CONTROL-PLANE-01: desde a migração X4B, o gatilho
    // trg_prevent_self_privilege_escalation bloqueia qualquer sessão não-
    // admin tentando mudar sua própria role -- exatamente o que este
    // bloco faz. Hoje é inofensivo (a conta configurada já é admin em
    // produção, então o guard `role != 'admin'` nunca deixa isto rodar de
    // novo), mas se algum dia essa conta perder o papel de admin, ou o
    // e-mail configurado mudar para um usuário ainda 'free', isto lançaria
    // uma exceção Postgres 42501 não tratada e quebraria o carregamento do
    // perfil inteiro. O try/catch trata esse cenário como "a promoção
    // automática não é mais possível" (o que é o comportamento correto e
    // esperado pós-X4B) em vez de propagar o erro.
    if (profile.email == AppConstants.adminEmail && profile.role != 'admin') {
      try {
        await _client
            .from(AppConstants.tableProfiles)
            .update({'role': 'admin', 'monthly_limit': 99999})
            .eq('id', uid);
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
