import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/project_resource_allocation.dart';
import '../data/services/project_resource_allocation_service.dart';

final projectResourceAllocationServiceProvider =
    Provider<ProjectResourceAllocationService>((_) => ProjectResourceAllocationService());

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

  final ProjectResourceAllocationService _service;
  final String _projectId;

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
    state = AsyncValue.data(current.copyWith(
      preview: current.preview.copyWith(hoursAllocated: hours),
      status: AllocationEditStatus.editing,
    ));
  }

  void updateBudgetPreviewCents(int cents) {
    final current = state.valueOrNull;
    if (current == null) return;
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
    state = AsyncValue.data(current.copyWith(status: AllocationEditStatus.saving));
    try {
      final saved = await _service.save(current.preview);
      state = AsyncValue.data(ProjectResourceAllocationEditState(
        saved: saved,
        preview: saved,
        status: AllocationEditStatus.saved,
      ));
    } catch (e) {
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
