import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/project_resource_allocation.dart';
import '../data/services/project_resource_allocation_service.dart';

// ── Service provider — injetável em testes via override (mesmo padrão de
// projectServiceProvider em project_provider.dart) ────────────────────────────
final projectResourceAllocationServiceProvider =
    Provider<ProjectResourceAllocationServiceInterface>(
        (_) => ProjectResourceAllocationService());

/// IVE-COMMERCIAL-EXPERIENCE-12 (Phase B, mission Section 12) — explicit
/// PREVIEW-vs-SAVED lifecycle: `saved` is the last value confirmed
/// persisted by the server; `preview` is what the user is currently
/// editing and may differ from it. Changing a slider/field only ever
/// updates `preview` — nothing reaches the server until `save()` is
/// called, and `cancel()` discards `preview` back to `saved` exactly.
enum AllocationEditStatus { saved, editing, saving, error }

class ProjectResourceAllocationEditState {
  const ProjectResourceAllocationEditState({
    required this.saved,
    required this.preview,
    required this.status,
    this.error,
  });

  final ProjectResourceAllocation saved;
  final ProjectResourceAllocation preview;
  final AllocationEditStatus status;
  final String? error;

  bool get isDirty =>
      preview.hoursAllocated != saved.hoursAllocated ||
      preview.budgetAllocatedCents != saved.budgetAllocatedCents ||
      preview.currency != saved.currency;

  ProjectResourceAllocationEditState copyWith({
    ProjectResourceAllocation? saved,
    ProjectResourceAllocation? preview,
    AllocationEditStatus? status,
    String? error,
  }) =>
      ProjectResourceAllocationEditState(
        saved: saved ?? this.saved,
        preview: preview ?? this.preview,
        status: status ?? this.status,
        error: error,
      );
}

class ProjectResourceAllocationNotifier
    extends StateNotifier<AsyncValue<ProjectResourceAllocationEditState>> {
  ProjectResourceAllocationNotifier(this._service, this._projectId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  final ProjectResourceAllocationServiceInterface _service;
  final String _projectId;

  // Codex Gate 1 (mission 12, Phase B) P1 — "lost update": save() used to
  // capture `current.preview` before its await, then unconditionally
  // overwrite state with that (possibly now-stale) captured value once the
  // await resolved, discarding any edit the user made WHILE the save was
  // in flight. Fixed with the same monotonically-incrementing
  // revision-token pattern already established in ive_provider.dart's
  // beginThinking()/completeInteraction(token, ...) — every user-driven
  // state change (edit or cancel) bumps `_revision`; save() only commits
  // its full "back to saved" result if no such change happened during the
  // await, otherwise it preserves the newer local state and merely
  // records the server-confirmed baseline.
  int _revision = 0;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final saved = await _service.fetch(_projectId);
      state = AsyncValue.data(ProjectResourceAllocationEditState(
        saved: saved,
        preview: saved,
        status: AllocationEditStatus.saved,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateHoursPreview(int hours) {
    final current = state.valueOrNull;
    if (current == null) return;
    _revision++;
    state = AsyncValue.data(current.copyWith(
      preview: current.preview.copyWith(hoursAllocated: hours),
      status: AllocationEditStatus.editing,
    ));
  }

  void updateBudgetPreviewCents(int cents) {
    final current = state.valueOrNull;
    if (current == null) return;
    _revision++;
    state = AsyncValue.data(current.copyWith(
      preview: current.preview.copyWith(budgetAllocatedCents: cents),
      status: AllocationEditStatus.editing,
    ));
  }

  /// Discards unsaved preview edits, restoring the last saved state
  /// exactly — mission Section 12: "Cancel: restores saved state."
  void cancel() {
    final current = state.valueOrNull;
    if (current == null) return;
    _revision++;
    state = AsyncValue.data(current.copyWith(
      preview: current.saved,
      status: AllocationEditStatus.saved,
      error: null,
    ));
  }

  /// Mission Section 12: "Prevent double save." A synchronous guard
  /// (checked before any `await`, same pattern as
  /// AiExecutionController.run in Phase A) makes a second call while a
  /// save is already in flight a no-op.
  Future<void> save() async {
    final current = state.valueOrNull;
    if (current == null || current.status == AllocationEditStatus.saving) return;
    final revisionAtStart = _revision;
    state = AsyncValue.data(current.copyWith(status: AllocationEditStatus.saving));
    try {
      final saved = await _service.save(current.preview);
      if (_revision != revisionAtStart) {
        // The user edited or cancelled while this save was in flight —
        // that newer local state must win. Still record the
        // server-confirmed baseline (the save DID succeed) so isDirty
        // compares the newer preview against what the server actually
        // has, without discarding the newer edit.
        final latest = state.valueOrNull;
        if (latest != null) {
          final merged = latest.copyWith(saved: saved);
          // Codex Gate 2 (mission 12, Phase B) P2 — a cancel() during this
          // save leaves `latest.status == saved` (cancel's own doing), but
          // merging in the server's now-newer `saved` baseline can make
          // `merged.isDirty` true again (the cancelled preview no longer
          // matches what the server actually has). Recompute status from
          // isDirty here so the two never disagree — a `saved` status with
          // isDirty == true would tell the user everything's fine while
          // Save is silently re-enabled underneath them.
          state = AsyncValue.data(merged.copyWith(
            status: merged.isDirty ? AllocationEditStatus.editing : AllocationEditStatus.saved,
          ));
        }
        return;
      }
      state = AsyncValue.data(ProjectResourceAllocationEditState(
        saved: saved,
        preview: saved,
        status: AllocationEditStatus.saved,
      ));
    } catch (e) {
      if (_revision != revisionAtStart) {
        // Superseded by a newer edit/cancel already — don't stomp it with
        // a stale error from this abandoned attempt.
        return;
      }
      state = AsyncValue.data(current.copyWith(
        status: AllocationEditStatus.error,
        error: e.toString(),
      ));
    }
  }
}

final projectResourceAllocationProvider = StateNotifierProvider.autoDispose
    .family<ProjectResourceAllocationNotifier, AsyncValue<ProjectResourceAllocationEditState>, String>(
  (ref, projectId) => ProjectResourceAllocationNotifier(
    ref.watch(projectResourceAllocationServiceProvider),
    projectId,
  ),
);
