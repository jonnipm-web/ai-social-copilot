import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/ive_event_bus.dart';
import '../data/models/ive_event.dart';
import '../data/models/project.dart';
import '../data/services/project_service.dart';

// ── Service provider — injetável em testes via override ───────────────────────
final projectServiceProvider =
    Provider<ProjectServiceInterface>((_) => ProjectService());

// ══════════════════════════════════════════════════════════════════════════════
// FONTE ÚNICA DE VERDADE
//
// AsyncNotifierProvider<ProjectsNotifier, List<Project>>
//
// Por que AsyncNotifier em vez de FutureProvider + StateNotifier separados:
//   • .future disponível → todos os providers de inteligência podem
//     ref.watch(projectsNotifierProvider.future) sem provider extra
//   • ref.invalidateSelf() relança build() — re-fetch automático do Supabase
//   • Atualizações otimistas possíveis (state = AsyncData([...]) antes do refetch)
//   • Alias projectsProvider aponta para o mesmo objeto → zero mudanças nos
//     arquivos que já fazem ref.watch(projectsProvider) ou .future ou invalidate
// ══════════════════════════════════════════════════════════════════════════════
class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  @override
  Future<List<Project>> build() {
    return ref.read(projectServiceProvider).fetchAll();
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<Project> create(Map<String, dynamic> data) async {
    final project = await ref.read(projectServiceProvider).create(data);

    // Atualização otimista — UI vê o novo projeto imediatamente
    state = AsyncData([...?state.valueOrNull, project]);

    // Resincroniza com o DB para ordem e scores corretos
    ref.invalidateSelf();

    IveEventBus.instance.emit(
      IveEvent.projectCreated(projectId: project.id, projectName: project.name),
    );
    return project;
  }

  // ── Update status ─────────────────────────────────────────────────────────

  Future<void> updateStatus(String id, String status) async {
    final project =
        await ref.read(projectServiceProvider).update(id, {'status': status});

    state = state.whenData(
      (list) => [for (final p in list) p.id == id ? project : p],
    );
    ref.invalidateSelf();

    IveEventBus.instance.emit(
      IveEvent.projectStatusChanged(
        projectId: id,
        projectName: project.name,
        status: status,
      ),
    );
  }

  // ── Update arbitrary fields ───────────────────────────────────────────────

  Future<void> update(String id, Map<String, dynamic> data) async {
    final project = await ref.read(projectServiceProvider).update(id, data);

    state = state.whenData(
      (list) => [for (final p in list) p.id == id ? project : p],
    );
    ref.invalidateSelf();

    IveEventBus.instance.emit(
      IveEvent.projectUpdated(projectId: id, projectName: project.name),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    final list = state.valueOrNull ?? [];
    final name =
        list.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;

    // Optimistic remove — sem flickering
    state = AsyncData(list.where((p) => p.id != id).toList());

    try {
      await ref.read(projectServiceProvider).delete(id);
      ref.invalidateSelf();
      IveEventBus.instance.emit(
        IveEvent.projectDeleted(projectId: id, projectName: name),
      );
    } catch (e) {
      // Reverte estado em caso de falha
      state = AsyncData(list);
      rethrow;
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

/// Fonte única de verdade para projetos.
/// Expõe: AsyncValue, .future, .notifier (para mutations).
final projectsNotifierProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
  ProjectsNotifier.new,
);

/// Alias retrocompatível — todos os arquivos que fazem:
///   ref.watch(projectsProvider)        → AsyncValue<List<Project>>
///   ref.watch(projectsProvider.future) → Future<List<Project>>
///   ref.invalidate(projectsProvider)   → dispara rebuild
/// continuam funcionando sem nenhuma alteração.
final projectsProvider = projectsNotifierProvider;

/// Provider para leitura de projeto por ID.
/// Reativo: recalcula quando projectsNotifierProvider muda.
final projectByIdProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) async {
  // Tenta servir do cache do notifier antes de ir ao Supabase
  final list = ref.watch(projectsNotifierProvider).valueOrNull;
  if (list != null) {
    final found = list.where((p) => p.id == id).toList();
    if (found.isNotEmpty) return found.first;
  }
  final result = await ref.read(projectServiceProvider).fetchById(id);
  if (result == null) throw Exception('Projeto não encontrado');
  return result;
});
