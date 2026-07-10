import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/action_queue_item.dart';
import '../data/services/action_queue_service.dart';

final actionQueueServiceProvider =
    Provider<ActionQueueService>((_) => ActionQueueService());

final actionQueueProvider =
    FutureProvider.autoDispose<List<ActionQueueItem>>((ref) {
  return ref.read(actionQueueServiceProvider).fetchAll();
});

final pendingActionsProvider =
    FutureProvider.autoDispose<List<ActionQueueItem>>((ref) {
  return ref.read(actionQueueServiceProvider).fetchPending();
});

final actionQueueSummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.read(actionQueueServiceProvider).summary();
});

class ActionQueueNotifier
    extends StateNotifier<AsyncValue<List<ActionQueueItem>>> {
  ActionQueueNotifier(this._svc) : super(const AsyncValue.loading()) {
    load();
  }

  final ActionQueueService _svc;

  Future<void> load({String? projectId, String? status}) async {
    state = const AsyncValue.loading();
    try {
      final list = await _svc.fetchAll(projectId: projectId, status: status);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(ActionQueueItem item) async {
    await _svc.create(item);
    await load();
  }

  Future<void> approve(String id) async {
    await _svc.updateStatus(id, 'approved');
    await load();
  }

  Future<void> complete(String id) async {
    await _svc.updateStatus(id, 'completed');
    await load();
  }

  Future<void> cancel(String id) async {
    await _svc.updateStatus(id, 'cancelled');
    await load();
  }

  Future<void> delete(String id) async {
    await _svc.delete(id);
    await load();
  }
}

final actionQueueNotifierProvider = StateNotifierProvider.autoDispose<
    ActionQueueNotifier, AsyncValue<List<ActionQueueItem>>>(
  (ref) => ActionQueueNotifier(ref.read(actionQueueServiceProvider)),
);
