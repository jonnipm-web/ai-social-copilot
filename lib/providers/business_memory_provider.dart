import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/business_memory.dart';
import '../data/services/business_memory_service.dart';

final businessMemoryServiceProvider =
    Provider<BusinessMemoryService>((_) => BusinessMemoryService());

final businessMemoryProvider =
    FutureProvider.autoDispose<List<BusinessMemory>>((ref) {
  return ref.read(businessMemoryServiceProvider).fetchAll();
});

final businessMemorySummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.read(businessMemoryServiceProvider).summary();
});

class BusinessMemoryNotifier
    extends StateNotifier<AsyncValue<List<BusinessMemory>>> {
  BusinessMemoryNotifier(this._svc) : super(const AsyncValue.loading()) {
    load();
  }

  final BusinessMemoryService _svc;

  Future<void> load({String? memoryType}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _svc.fetchAll(memoryType: memoryType);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> record({
    required String memoryType,
    required String title,
    String content = '',
    int confidenceScore = 50,
    String source = '',
    String? projectId,
  }) async {
    await _svc.create(
      memoryType:      memoryType,
      title:           title,
      content:         content,
      confidenceScore: confidenceScore,
      source:          source,
      projectId:       projectId,
    );
    await load();
  }

  Future<void> delete(String id) async {
    await _svc.delete(id);
    await load();
  }
}

final businessMemoryNotifierProvider = StateNotifierProvider.autoDispose<
    BusinessMemoryNotifier, AsyncValue<List<BusinessMemory>>>(
  (ref) => BusinessMemoryNotifier(ref.read(businessMemoryServiceProvider)),
);
