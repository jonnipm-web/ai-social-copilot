import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/project.dart';
import '../data/services/project_service.dart';
import 'project_provider.dart';

const _kSelectedProjectId = 'selected_project_id';

class SelectedProjectNotifier extends StateNotifier<Project?> {
  SelectedProjectNotifier(this._service) : super(null) {
    _restore();
  }

  final ProjectServiceInterface _service;

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kSelectedProjectId);
      if (id != null) {
        final project = await _service.fetchById(id);
        if (project != null && mounted) state = project;
      }
    } catch (_) {}
  }

  Future<void> select(Project project) async {
    state = project;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSelectedProjectId, project.id);
    } catch (_) {}
  }

  Future<void> clear() async {
    state = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedProjectId);
    } catch (_) {}
  }
}

final selectedProjectProvider =
    StateNotifierProvider<SelectedProjectNotifier, Project?>((ref) {
  return SelectedProjectNotifier(ref.watch(projectServiceProvider));
});
