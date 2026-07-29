import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/executive_context.dart';
import '../data/services/executive_context_orchestrator.dart';
import '../data/services/executive_context_service.dart';

// Contexto executivo de um projeto específico
final executiveContextByProjectProvider = FutureProvider.autoDispose
    .family<ExecutiveContext?, String>((ref, projectId) {
  return ref.read(executiveContextServiceProvider).fetchByProject(projectId);
});

// Todos os contextos executivos do usuário
final allExecutiveContextsProvider =
    FutureProvider.autoDispose<List<ExecutiveContext>>((ref) {
  return ref.read(executiveContextServiceProvider).fetchAllByUser();
});

// Projetos com check-in vencido
final checkInDueContextsProvider =
    FutureProvider.autoDispose<List<ExecutiveContext>>((ref) async {
  final all = await ref.watch(allExecutiveContextsProvider.future);
  return all.where((c) => c.checkInDue).toList();
});

// Notifier para ações executivas manuais
class ExecutiveContextNotifier extends StateNotifier<AsyncValue<void>> {
  ExecutiveContextNotifier(this._svc, this._orchestrator)
      : super(const AsyncValue.data(null));

  final ExecutiveContextService _svc;
  final ExecutiveContextOrchestrator _orchestrator;

  /// Registra check-in manual pelo usuário
  Future<void> completeCheckIn({
    required String projectId,
    required String projectName,
    required Ref ref,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _orchestrator.onCheckInCompleted(
        projectId: projectId,
        projectName: projectName,
      );
      ref.invalidate(executiveContextByProjectProvider(projectId));
      ref.invalidate(allExecutiveContextsProvider);
      ref.invalidate(checkInDueContextsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Atualiza o contexto com dados recalculados
  Future<void> upsert(Map<String, dynamic> data, {required Ref ref}) async {
    state = const AsyncValue.loading();
    try {
      await _svc.upsert(data);
      final projectId = data['project_id'] as String?;
      if (projectId != null) {
        ref.invalidate(executiveContextByProjectProvider(projectId));
      }
      ref.invalidate(allExecutiveContextsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final executiveContextNotifierProvider = StateNotifierProvider.autoDispose<
    ExecutiveContextNotifier, AsyncValue<void>>(
  (ref) => ExecutiveContextNotifier(
    ref.read(executiveContextServiceProvider),
    ref.read(executiveContextOrchestratorProvider),
  ),
);
