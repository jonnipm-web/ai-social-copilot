import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/quota_service.dart';
import '../data/models/quota_info.dart';

final quotaServiceProvider = Provider<QuotaService>((_) => QuotaService());

/// Cota de IA do mês atual. autoDispose para sempre refletir o estado real
/// ao reabrir a tela (não guarda cache entre sessões).
final currentQuotaProvider = FutureProvider.autoDispose<QuotaInfo>((ref) {
  return ref.watch(quotaServiceProvider).fetchCurrentQuota();
});
