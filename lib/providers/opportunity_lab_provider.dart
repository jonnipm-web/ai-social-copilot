import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/action_queue_item.dart';
import '../data/models/opportunity_lab_item.dart';
import '../data/services/opportunity_lab_service.dart';
import 'action_queue_provider.dart';

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

final opportunityLabItemByIdProvider =
    FutureProvider.autoDispose.family<OpportunityLabItem?, String>((ref, id) {
  return ref.read(opportunityLabServiceProvider).fetchById(id);
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
  String? _activeProjectId;

  Future<void> load({String? projectId}) async {
    _activeProjectId = projectId;
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
    await load(projectId: _activeProjectId);
  }

  Future<void> approve(String id) async {
    await _svc.updateStatus(id, 'approved');
    await load(projectId: _activeProjectId);
  }

  /// Single entry point for approving an opportunity and creating its action.
  ///
  /// Sequence (action first, then approve) ensures that a failed action
  /// creation never leaves the opportunity in an approved-without-action state.
  /// Idempotent: a second call returns the existing action without creating a duplicate.
  Future<ActionQueueItem> approveAndCreateAction(
    OpportunityLabItem opp,
    ActionQueueNotifier actionNotifier,
  ) async {
    if (opp.status == 'approved') {
      // Already approved — just ensure the action exists (idempotent create)
      return actionNotifier.addFromOpportunityItem(opp);
    }
    // 1. Create action first; DB UNIQUE constraint + service idempotency prevent duplicates
    final action = await actionNotifier.addFromOpportunityItem(opp);
    // 2. Approve opportunity only after action is confirmed persisted
    await _svc.updateStatus(opp.id, 'approved');
    await load(projectId: _activeProjectId);
    return action;
  }

  Future<void> delete(String id) async {
    await _svc.delete(id);
    await load(projectId: _activeProjectId);
  }
}

final opportunityLabNotifierProvider = StateNotifierProvider.autoDispose<
    OpportunityLabNotifier, AsyncValue<List<OpportunityLabItem>>>(
  (ref) => OpportunityLabNotifier(ref.read(opportunityLabServiceProvider)),
);
