import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/ive_event_bus.dart';
import '../data/models/action_queue_item.dart';
import '../data/models/ive_event.dart';
import '../data/models/opportunity_lab_item.dart';
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

final actionQueueItemByIdProvider =
    FutureProvider.autoDispose.family<ActionQueueItem?, String>((ref, id) {
  return ref.read(actionQueueServiceProvider).fetchById(id);
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
    try {
      await _svc.create(item);
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    item.title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> approve(String id, {String title = 'Ação'}) async {
    try {
      await _svc.updateStatus(id, 'approved');
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> execute(String id, {String title = 'Ação'}) async {
    try {
      await _svc.updateStatus(id, 'executing');
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> complete(String id, {String title = 'Ação'}) async {
    try {
      await _svc.updateStatus(id, 'completed');
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> cancel(String id, {String title = 'Ação'}) async {
    try {
      await _svc.updateStatus(id, 'cancelled');
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<ActionQueueItem> addFromOpportunity({
    required String title,
    required String description,
    String? projectId,
    String? opportunityLabId,
    int priority    = 50,
    int impactScore = 60,
    int effortScore = 50,
    String       origin  = 'opportunity_lab',
    List<String> sources = const [],
    String?      rationale,
    List<String> plan    = const [],
    List<String> risks   = const [],
  }) async {
    final uid = _svc.currentUserId;
    if (uid == null) throw Exception('Não autenticado');
    final item = ActionQueueItem(
      id:               '',
      userId:           uid,
      projectId:        projectId,
      opportunityLabId: opportunityLabId,
      actionType:       'opportunity',
      title:            '[Lab] $title',
      priority:         priority,
      impactScore:      impactScore,
      effortScore:      effortScore,
      roiScore:         0,
      status:           'pending',
      createdAt:        DateTime.now(),
      description:      description.isNotEmpty ? description : null,
      origin:           origin,
      sources:          sources,
      rationale:        rationale,
      plan:             plan,
      risks:            risks,
    );
    try {
      final created = await _svc.create(item);
      await load();
      return created;
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    '[Lab] $title',
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<ActionQueueItem> addFromOpportunityItem(OpportunityLabItem opp) {
    return addFromOpportunity(
      title:            opp.title,
      description:      opp.description,
      projectId:        opp.projectId,
      opportunityLabId: opp.id,
      priority:         opp.finalScore > 0 ? opp.finalScore : 50,
      impactScore:      opp.revenueScore > 0 ? opp.revenueScore : 60,
      effortScore:      50,
      origin:           'opportunity_lab',
      sources:          opp.sources.isNotEmpty ? opp.sources : [opp.title],
      rationale:        opp.rationale,
      plan:             opp.actionSteps,
      risks:            opp.risks,
    );
  }

  Future<void> delete(String id, {String title = 'Ação'}) async {
    try {
      await _svc.delete(id);
      await load();
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }
}

final actionQueueNotifierProvider = StateNotifierProvider.autoDispose<
    ActionQueueNotifier, AsyncValue<List<ActionQueueItem>>>(
  (ref) => ActionQueueNotifier(ref.read(actionQueueServiceProvider)),
);
