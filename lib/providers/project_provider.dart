import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  ProjectsNotifier(this._service) : super(const AsyncValue.loading()) {
    load();
  }

  final ProjectService _service;

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
    await _service.create(data);
    await load();
  }

  Future<void> updateStatus(String id, String status) async {
    await _service.update(id, {'status': status});
    await load();
  }

  Future<void> delete(String id) async {
    await _service.delete(id);
    await load();
  }
}

final projectsNotifierProvider =
    StateNotifierProvider.autoDispose<ProjectsNotifier, AsyncValue<List<Project>>>(
  (ref) => ProjectsNotifier(ref.read(projectServiceProvider)),
);
