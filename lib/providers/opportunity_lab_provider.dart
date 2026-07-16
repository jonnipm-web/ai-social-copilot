import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/opportunity_lab_item.dart';
import '../data/services/opportunity_lab_service.dart';

final opportunityLabServiceProvider =
    Provider<OpportunityLabService>((_) => OpportunityLabService());

final opportunityLabProvider =
    FutureProvider.autoDispose<List<OpportunityLabItem>>((ref) {
  return ref.read(opportunityLabServiceProvider).fetchAll();
});

final opportunityLabByProjectProvider =
    FutureProvider.autoDispose.family<List<OpportunityLabItem>, String>((ref, projectId) {
  return ref.read(opportunityLabServiceProvider).fetchAll(projectId: projectId);
});

final opportunityLabSummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.read(opportunityLabServiceProvider).summary();
});

class OpportunityLabNotifier
    extends StateNotifier<AsyncValue<List<OpportunityLabItem>>> {
  OpportunityLabNotifier(this._svc) : super(const AsyncValue.loading()) {
    load();
  }

  final OpportunityLabService _svc;

  Future<void> load({String? projectId}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _svc.fetchAll(projectId: projectId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(OpportunityLabItem item) async {
    await _svc.create(item);
    await load();
  }

  Future<void> approve(String id) async {
    await _svc.updateStatus(id, 'approved');
    await load();
  }

  Future<void> delete(String id) async {
    await _svc.delete(id);
    await load();
  }
}

final opportunityLabNotifierProvider = StateNotifierProvider.autoDispose<
    OpportunityLabNotifier, AsyncValue<List<OpportunityLabItem>>>(
  (ref) => OpportunityLabNotifier(ref.read(opportunityLabServiceProvider)),
);
