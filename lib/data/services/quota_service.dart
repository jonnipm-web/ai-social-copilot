import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quota_info.dart';

/// Lê o estado de cota real (IVE-COMMERCIAL-ENTITLEMENTS-01) para exibição.
/// Somente leitura: profiles.role/monthly_limit e ai_usage.request_count já
/// são protegidos por RLS (o usuário só lê a própria linha) e só podem ser
/// escritos pelo servidor. Nada aqui decide se uma chamada de IA é
/// permitida — isso é sempre resolvido por try_reserve_ai_quota() no
/// backend, no momento da chamada.
class QuotaService {
  final _client = Supabase.instance.client;

  Future<QuotaInfo> fetchCurrentQuota() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Usuário não autenticado.');

    final profile = await _client
        .from('profiles')
        .select('role, monthly_limit')
        .eq('id', userId)
        .single();

    final role = profile['role'] as String? ?? 'free';
    final limit = (profile['monthly_limit'] as num?)?.toInt() ?? 5;

    final now = DateTime.now().toUtc();
    final periodStart = DateTime.utc(now.year, now.month, 1);
    final periodStartStr =
        '${periodStart.year.toString().padLeft(4, '0')}-'
        '${periodStart.month.toString().padLeft(2, '0')}-01';

    final usageRow = await _client
        .from('ai_usage')
        .select('request_count')
        .eq('user_id', userId)
        .eq('period_start', periodStartStr)
        .maybeSingle();

    final used = (usageRow?['request_count'] as num?)?.toInt() ?? 0;

    return QuotaInfo(role: role, limit: limit, used: used);
  }
}
