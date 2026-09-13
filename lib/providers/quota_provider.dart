import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostic_models.dart';
import '../data/services/quota_service.dart';
import '../data/models/quota_info.dart';
import 'diagnostic_session_provider.dart';

final quotaServiceProvider = Provider<QuotaService>((_) => QuotaService());

/// Cota de IA do mês atual. autoDispose para sempre refletir o estado real
/// ao reabrir a tela (não guarda cache entre sessões).
///
/// IVE-COMMERCIAL-OBSERVABILITY-07A — this is the ONE canonical quota
/// read path (backed by public.ai_usage / try_reserve_ai_quota, the real
/// commercial quota system). Logs the raw used/limit/role every time it
/// resolves, so a diagnostic session timeline directly shows what every
/// consumer of this provider actually saw — see dashboard_screen.dart's
/// _UsageCard, which used to read a completely different, legacy metric
/// (monthlyUsageProvider, a count of the old post_generations table
/// unrelated to the commercial quota system) and is exactly why the
/// physical test found Dashboard and Upgrade disagreeing about usage.
final currentQuotaProvider = FutureProvider.autoDispose<QuotaInfo>((ref) async {
  final info = await ref.watch(quotaServiceProvider).fetchCurrentQuota();
  ref.read(diagnosticLoggerProvider).logEvent(
    category: DiagnosticCategory.quota,
    eventName: 'quota_fetch',
    status: 'success',
    metadata: {'used': info.used, 'limit': info.limit, 'role': info.role},
  );
  return info;
});
