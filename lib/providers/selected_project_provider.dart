import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/project.dart';
import '../data/services/project_service.dart';
import 'project_provider.dart';

const _kSelectedProjectId = 'selected_project_id';

class SelectedProjectNotifier extends StateNotifier<Project?> {
  SelectedProjectNotifier(this._service) : super(null) {
    _listenAuthChanges();
    _restore();
  }

  final ProjectServiceInterface _service;
  StreamSubscription<AuthState>? _authSub;

  void _listenAuthChanges() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        _clearPersisted();
        if (mounted) state = null;
      } else if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _restore();
      }
    });
  }

  Future<void> _restore() async {
    try {
      // Cede a microtask queue (sem criar Timer) para a sessão de auth
      // ser totalmente inicializada antes de ler currentUser (corrige race P0.3)
      await Future.value();
      if (!mounted) return;
      final uid = Supabase.instance.client.auth.currentUser?.id;
      // sem retry — auth listener chama _restore() em signedIn/tokenRefreshed
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kSelectedProjectId);
      if (id == null) return;

      final project = await _service.fetchById(id);

      // Valida que o projeto pertence ao usuário autenticado
      if (project == null || project.userId != uid) {
        await _clearPersisted();
        if (mounted) state = null;
        return;
      }

      if (mounted) state = project;
    } catch (e) {
      assert(() {
        debugPrint('[SelectedProject] restore failed: $e');
        return true;
      }());
    }
  }

  Future<void> select(Project project) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) throw Exception('Não autenticado');
    if (project.userId != uid)
      throw Exception('Projeto não pertence ao usuário');

    state = project;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSelectedProjectId, project.id);
    } catch (_) {}
  }

  Future<Project> selectById(String projectId) async {
    final id = projectId.trim();
    if (id.isEmpty) throw ArgumentError.value(projectId, 'projectId');

    final current = state;
    if (current?.id == id) return current!;

    final project = await _service.fetchById(id);
    if (project == null) throw StateError('Projeto não encontrado');
    await select(project);
    return project;
  }

  Future<void> refresh() async {
    final current = state;
    if (current == null) return;
    try {
      final updated = await _service.fetchById(current.id);
      if (mounted) state = updated;
    } catch (_) {}
  }

  Future<void> clear() async {
    state = null;
    await _clearPersisted();
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSelectedProjectId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final selectedProjectProvider =
    StateNotifierProvider<SelectedProjectNotifier, Project?>((ref) {
  return SelectedProjectNotifier(ref.watch(projectServiceProvider));
});
