import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/diagnostics/diagnostic_models.dart';
import '../data/models/action_queue_item.dart';
import '../data/models/opportunity_lab_item.dart';
import '../data/models/copilot_turn.dart';
import '../data/services/insight_service.dart';
import 'diagnostic_session_provider.dart';

final insightServiceProvider =
    Provider<InsightService>((_) => InsightService());

// Insights for a specific project
final insightsByProjectProvider =
    FutureProvider.autoDispose.family<List<OpportunityLabItem>, String>(
        (ref, projectId) =>
            ref.read(insightServiceProvider).fetchByProject(projectId));

// Monthly usage count for a project (entitlement gate)
final insightMonthCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, projectId) =>
        ref.read(insightServiceProvider).countThisMonth(projectId));

// Recent insights across all projects (home screen)
final recentInsightsProvider =
    FutureProvider.autoDispose<List<OpportunityLabItem>>(
        (ref) => ref.read(insightServiceProvider).fetchRecent(limit: 5));

// ── State ────────────────────────────────────────────────────────────────────

class InsightState {
  final List<OpportunityLabItem> items;
  final bool loading;
  final String? error;
  final bool saving;
  final bool addingToActions;
  final int monthCount;

  const InsightState({
    this.items           = const [],
    this.loading         = false,
    this.error,
    this.saving          = false,
    this.addingToActions = false,
    this.monthCount      = 0,
  });

  InsightState copyWith({
    List<OpportunityLabItem>? items,
    bool? loading,
    String? error,
    bool? saving,
    bool? addingToActions,
    int? monthCount,
    bool clearError = false,
  }) =>
      InsightState(
        items:           items           ?? this.items,
        loading:         loading         ?? this.loading,
        error:           clearError ? null : (error ?? this.error),
        saving:          saving          ?? this.saving,
        addingToActions: addingToActions ?? this.addingToActions,
        monthCount:      monthCount      ?? this.monthCount,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class InsightNotifier extends StateNotifier<InsightState> {
  InsightNotifier(this._svc, this._ref, this._projectId)
      : super(const InsightState());

  final InsightService _svc;
  final Ref            _ref;
  final String         _projectId;

  void _log(String event, {String status = 'success', Object? error}) {
    _ref.read(diagnosticSessionProvider.notifier).logEvent(
      category:    DiagnosticCategory.ai,
      eventName:   event,
      operation:   'insight_vertical',
      status:      status,
      error:       error,
    );
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _svc.fetchByProject(_projectId);
      final count = await _svc.countThisMonth(_projectId);
      state = state.copyWith(items: items, loading: false, monthCount: count);
      _log('insight_load');
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      _log('insight_load', status: 'failure', error: e);
    }
  }

  Future<OpportunityLabItem?> save({
    required String question,
    required CopilotTurn turn,
  }) async {
    state = state.copyWith(saving: true, clearError: true);
    try {
      final item = await _svc.saveFromTurn(
        projectId: _projectId,
        question:  question,
        turn:      turn,
      );
      state = state.copyWith(
        saving:     false,
        items:      [item, ...state.items],
        monthCount: state.monthCount + 1,
      );
      _log('insight_save');
      return item;
    } catch (e) {
      state = state.copyWith(saving: false, error: e.toString());
      _log('insight_save', status: 'failure', error: e);
      return null;
    }
  }

  Future<ActionQueueItem?> addToActions(OpportunityLabItem insight) async {
    state = state.copyWith(addingToActions: true, clearError: true);
    try {
      final action = await _svc.addToActions(insight);
      state = state.copyWith(addingToActions: false);
      _log('insight_add_to_actions');
      return action;
    } catch (e) {
      state = state.copyWith(addingToActions: false, error: e.toString());
      _log('insight_add_to_actions', status: 'failure', error: e);
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _svc.delete(id);
      state = state.copyWith(
        items:      state.items.where((i) => i.id != id).toList(),
        monthCount: state.monthCount > 0 ? state.monthCount - 1 : 0,
      );
      _log('insight_delete');
    } catch (e) {
      state = state.copyWith(error: e.toString());
      _log('insight_delete', status: 'failure', error: e);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final insightNotifierProvider = StateNotifierProvider.autoDispose
    .family<InsightNotifier, InsightState, String>(
  (ref, projectId) {
    final notifier =
        InsightNotifier(ref.read(insightServiceProvider), ref, projectId);
    notifier.load();
    return notifier;
  },
);
