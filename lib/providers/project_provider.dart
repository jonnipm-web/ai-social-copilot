import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/ive_event_bus.dart';
import '../data/models/ive_event.dart';
import '../data/models/project.dart';
import '../data/services/project_service.dart';

final projectServiceProvider = Provider<ProjectService>((_) => ProjectService());

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) {
  return ref.read(projectServiceProvider).fetchAll();
});

final projectByIdProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, id) async {
  final result = await ref.read(projectServiceProvider).fetchById(id);
  if (result == null) throw Exception('Projeto não encontrado');
  return result;
});

class ProjectsNotifier extends StateNotifier<AsyncValue<List<Project>>> {
  ProjectsNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final ProjectService _service;
  final Ref _ref;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.fetchAll();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> create(Map<String, dynamic> data) async {
    final project = await _service.create(data);
    await load();
    _ref.invalidate(projectsProvider);
    IveEventBus.instance.emit(
      IveEvent.projectCreated(projectId: project.id, projectName: project.name),
    );
  }

  Future<void> updateStatus(String id, String status) async {
    final project = await _service.update(id, {'status': status});
    await load();
    _ref.invalidate(projectsProvider);
    IveEventBus.instance.emit(
      IveEvent.projectStatusChanged(
        projectId: id, projectName: project.name, status: status),
    );
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final project = await _service.update(id, data);
    await load();
    _ref.invalidate(projectsProvider);
    IveEventBus.instance.emit(
      IveEvent.projectUpdated(projectId: id, projectName: project.name),
    );
  }

  Future<void> delete(String id) async {
    final projects = state.valueOrNull ?? [];
    final match = projects.where((p) => p.id == id).toList();
    final name = match.isNotEmpty ? match.first.name : id;
    await _service.delete(id);
    await load();
    _ref.invalidate(projectsProvider);
    IveEventBus.instance.emit(
      IveEvent.projectDeleted(projectId: id, projectName: name),
    );
  }
}

final projectsNotifierProvider =
    StateNotifierProvider.autoDispose<ProjectsNotifier, AsyncValue<List<Project>>>(
  (ref) => ProjectsNotifier(ref.read(projectServiceProvider), ref),
);
