import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/ive_event_bus.dart';
import '../core/utils/language_utils.dart';
import '../core/utils/app_exceptions.dart';
import '../data/models/action_queue_item.dart';
import '../data/models/aef_runtime.dart';
import '../data/models/ive_event.dart';
import '../data/models/opportunity_lab_item.dart';
import '../data/services/action_queue_service.dart';
import '../l10n/app_localizations.dart';
import '../data/services/content_localization_service.dart';
import '../data/services/opportunity_lab_service.dart';

final actionQueueServiceProvider =
    Provider<ActionQueueService>((ref) => ActionQueueService(localizer: ref.watch(rowLocalizerProvider)));

final actionQueueProvider =
    FutureProvider.autoDispose<List<ActionQueueItem>>((ref) {
  return ref.watch(actionQueueServiceProvider).fetchAll();
});

final pendingActionsProvider =
    FutureProvider.autoDispose<List<ActionQueueItem>>((ref) {
  return ref.watch(actionQueueServiceProvider).fetchPending();
});

final actionQueueSummaryProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) {
  return ref.watch(actionQueueServiceProvider).summary();
});

final actionQueueItemByIdProvider =
    FutureProvider.autoDispose.family<ActionQueueItem?, String>((ref, id) {
  return ref.watch(actionQueueServiceProvider).fetchById(id);
});

// Action queue filtered by project_id (real Supabase filter)
final actionQueueByProjectProvider =
    FutureProvider.autoDispose.family<List<ActionQueueItem>, String>((ref, projectId) {
  return ref.watch(actionQueueServiceProvider).fetchAll(projectId: projectId);
});

class ActionQueueNotifier
    extends StateNotifier<AsyncValue<List<ActionQueueItem>>> {
  ActionQueueNotifier(this._svc, {AppLocalizations Function()? l10n})
      : _l10nFn = l10n,
        super(const AsyncValue.loading()) {
    load();
  }

  final ActionQueueService _svc;

  /// R16 — current UI-language localizations (via [appL10nProvider]); falls
  /// back to PT when constructed without one (tests).
  final AppLocalizations Function()? _l10nFn;
  AppLocalizations get _l10n {
    try {
      final v = _l10nFn?.call();
      if (v != null) return v;
    } catch (_) {
      // provider ref may already be disposed after an await -- fall back.
    }
    return lookupAppLocalizations(const Locale('pt'));
  }
  String _titleOr(String? title) =>
      (title == null || title.isEmpty) ? _l10n.uxActionDefaultTitle : title;
  String? _activeProjectId;

  Future<void> load({String? projectId, String? status}) async {
    _activeProjectId = projectId;
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
      await load(projectId: _activeProjectId);
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

  Future<void> approve(String id, {String? title}) async {
    try {
      await _svc.updateStatus(id, 'approved');
      await load(projectId: _activeProjectId);
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    _titleOr(title),
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// INSIGHTVALUES-PRODUCTIZATION-MACRO-03 — replaces the old direct
  /// `_svc.updateStatus(id, 'executing'/'completed')` writes. The
  /// "execute"/"complete" transition is now AEF-governed (Human Gate,
  /// receipt, audit) via action-engine-runtime — see
  /// ActionEngineExecuteSheet, which drives propose/decide/execute and
  /// calls this only with the real, terminal, receipted result. This
  /// method never invents a status: it writes exactly what the receipt
  /// says (ActionQueueService.applyAefResult).
  Future<void> applyGovernedResult(String id, AefRuntimeResult result, {String? title}) async {
    try {
      await _svc.applyAefResult(id, result);
      await load(projectId: _activeProjectId);
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    _titleOr(title),
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> cancel(String id, {String? title}) async {
    try {
      await _svc.updateStatus(id, 'cancelled');
      await load(projectId: _activeProjectId);
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    _titleOr(title),
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
    String? marketAnalysisId,
    int priority    = 50,
    int impactScore = 60,
    int effortScore = 50,
    int roiScore    = 0,
    int marketScore = 0,
    int confidence  = 0,
    String       origin  = 'opportunity_lab',
    List<String> sources = const [],
    String?      rationale,
    List<String> plan    = const [],
    List<String> risks   = const [],
  }) async {
    final uid = _svc.currentUserId;
    if (uid == null) throw const NotAuthenticatedException();
    final item = ActionQueueItem(
      id:               '',
      userId:           uid,
      projectId:        projectId,
      opportunityLabId: opportunityLabId,
      marketAnalysisId: marketAnalysisId,
      actionType:       'opportunity',
      // R16 — the stored title carries NO localized marker (formerly a
      // '[Lab] ' prefix); provenance is recorded in `origin` instead.
      title:            title,
      priority:         priority,
      impactScore:      impactScore,
      effortScore:      effortScore,
      roiScore:         roiScore,
      marketScore:      marketScore,
      confidence:       confidence,
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
          actionTitle:    title,
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<ActionQueueItem> addFromOpportunityItem(OpportunityLabItem shown) async {
    // R16 §8 — the opportunity on screen may be a translated PRESENTATION.
    // A new action must be derived from the ORIGINAL stored text (the
    // action is then presented through the same localization layer), so
    // re-read the row without localization; fall back to what is on screen
    // only if that read is impossible (e.g. tests without Supabase).
    OpportunityLabItem opp = shown;
    if (shown.localizedFrom != null) {
      try {
        opp = await OpportunityLabService().fetchById(shown.id) ?? shown;
      } catch (_) {
        opp = shown;
      }
    }
    return addFromOpportunity(
      title:            opp.title,
      description:      opp.description,
      projectId:        opp.projectId,
      opportunityLabId: opp.id,
      marketAnalysisId: opp.marketAnalysisId,
      priority:         opp.finalScore > 0 ? opp.finalScore : 50,
      impactScore:      opp.revenueScore > 0 ? opp.revenueScore : 60,
      effortScore:      50,
      roiScore:         opp.finalScore,
      marketScore:      opp.marketScore,
      confidence:       opp.confidence,
      origin:           'opportunity_lab',
      sources:          opp.sources.isNotEmpty ? opp.sources : [opp.title],
      rationale:        opp.rationale,
      plan:             opp.actionSteps,
      risks:            opp.risks,
    );
  }

  Future<void> delete(String id, {String? title}) async {
    try {
      await _svc.delete(id);
      await load(projectId: _activeProjectId);
    } catch (e) {
      IveEventBus.instance.emit(
        IveEvent.actionMutationFailed(
          actionTitle:    _titleOr(title),
          technicalError: e.toString(),
        ),
      );
      rethrow;
    }
  }
}

final actionQueueNotifierProvider = StateNotifierProvider.autoDispose<
    ActionQueueNotifier, AsyncValue<List<ActionQueueItem>>>(
  (ref) => ActionQueueNotifier(
    ref.watch(actionQueueServiceProvider),
    l10n: () => ref.read(appL10nProvider),
  ),
);
