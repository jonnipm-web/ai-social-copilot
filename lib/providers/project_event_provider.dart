import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/project_event.dart';
import '../data/services/project_event_service.dart';

final _service = ProjectEventService();

/// Eventos de timeline de um projeto específico.
final projectEventsProvider = FutureProvider.autoDispose
    .family<List<ProjectEvent>, String>((ref, projectId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  return _service.fetchByProject(projectId);
});

/// Todos os eventos do usuário (para dashboard global de timeline).
final allProjectEventsProvider = FutureProvider.autoDispose<List<ProjectEvent>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  return _service.fetchByUser(user.id);
});

/// Notifier para adicionar eventos programaticamente.
final projectEventNotifierProvider =
    StateNotifierProvider.autoDispose.family<ProjectEventNotifier, AsyncValue<void>, String>(
  (ref, projectId) => ProjectEventNotifier(projectId, ref),
);

class ProjectEventNotifier extends StateNotifier<AsyncValue<void>> {
  ProjectEventNotifier(this._projectId, this._ref) : super(const AsyncValue.data(null));

  final String _projectId;
  final Ref    _ref;

  Future<void> emit(ProjectEventType type, String title, {
    String description = '',
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    state = const AsyncValue.loading();
    try {
      await _service.emit(
        projectId:   _projectId,
        userId:      user.id,
        type:        type,
        title:       title,
        description: description,
        metadata:    metadata,
      );
      _ref.invalidate(projectEventsProvider(_projectId));
      _ref.invalidate(allProjectEventsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
