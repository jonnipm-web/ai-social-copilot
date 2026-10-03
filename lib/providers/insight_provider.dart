import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/opportunity_lab_item.dart';
import '../data/models/copilot_turn.dart';
import '../data/services/insight_service.dart';

final insightServiceProvider =
    Provider<InsightService>((_) => InsightService());

final insightsByProjectProvider =
    FutureProvider.autoDispose.family<List<OpportunityLabItem>, String>(
        (ref, projectId) =>
            ref.read(insightServiceProvider).fetchByProject(projectId));

final insightMonthCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, projectId) =>
        ref.read(insightServiceProvider).countThisMonth(projectId));

class InsightState {
  final List<OpportunityLabItem> items;
  final bool loading;
  final String? error;
  final bool saving;

  const InsightState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.saving = false,
  });

  InsightState copyWith({
    List<OpportunityLabItem>? items,
    bool? loading,
    String? error,
    bool? saving,
    bool clearError = false,
  }) =>
      InsightState(
        items:   items   ?? this.items,
        loading: loading ?? this.loading,
        error:   clearError ? null : (error ?? this.error),
        saving:  saving  ?? this.saving,
      );
}

class InsightNotifier extends StateNotifier<InsightState> {
  InsightNotifier(this._svc) : super(const InsightState());

  final InsightService _svc;

  Future<void> load(String projectId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _svc.fetchByProject(projectId);
      state = state.copyWith(items: items, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<OpportunityLabItem?> save({
    required String projectId,
    required String question,
    required CopilotTurn turn,
  }) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final item = await _svc.saveFromTurn(
        projectId: projectId,
        question:  question,
        turn:      turn,
      );
      state = state.copyWith(
        saving: false,
        items:  [item, ...state.items],
      );
      return item;
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _svc.delete(id);
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final insightNotifierProvider = StateNotifierProvider.autoDispose
    .family<InsightNotifier, InsightState, String>(
  (ref, projectId) {
    final notifier = InsightNotifier(ref.read(insightServiceProvider));
    notifier.load(projectId);
    return notifier;
  },
);
