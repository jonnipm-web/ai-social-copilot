import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/usage_service.dart';

const freeMonthlyLimit = 10;

final usageServiceProvider = Provider<UsageService>((_) => UsageService());

final usageProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(usageServiceProvider).getCurrentMonthCount();
});
