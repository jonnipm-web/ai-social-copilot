import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/ive_memory.dart';

const _kLastRoute = 'ive_last_route';
const _kLastProjectId = 'ive_last_project_id';
const _kLastProjectName = 'ive_last_project_name';
const _kRecentQuestions = 'ive_recent_questions';
const _kInteractionCount = 'ive_interaction_count';

class IveMemoryNotifier extends StateNotifier<IveMemory> {
  IveMemoryNotifier() : super(const IveMemory()) {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedOut) {
        _activeUserId = null;
        if (mounted) state = const IveMemory();
        return;
      }
      final uid = event.session?.user.id;
      if (uid != null && uid != _activeUserId) _load(uid);
    });
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) _load(uid);
  }

  StreamSubscription<AuthState>? _authSub;
  String? _activeUserId;

  String _key(String base, String uid) => '${base}_$uid';

  Future<void> _load(String uid) async {
    _activeUserId = uid;
    if (mounted) state = const IveMemory();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _activeUserId != uid) return;
      state = state.copyWith(
        lastRoute: prefs.getString(_key(_kLastRoute, uid)) ?? '',
        lastProjectId: prefs.getString(_key(_kLastProjectId, uid)),
        lastProjectName: prefs.getString(_key(_kLastProjectName, uid)),
        recentQuestions:
            prefs.getStringList(_key(_kRecentQuestions, uid)) ?? [],
        interactionCount: prefs.getInt(_key(_kInteractionCount, uid)) ?? 0,
      );
    } catch (error) {
      assert(() {
        debugPrint('[IveMemory] load failed: $error');
        return true;
      }());
    }
  }

  Future<void> setRoute(String route) async {
    final uid = _activeUserId;
    if (uid == null || route == state.lastRoute) return;
    state = state.copyWith(lastRoute: route);
    _persist(uid, (prefs) => prefs.setString(_key(_kLastRoute, uid), route));
  }

  Future<void> setActiveProject(String id, String name) async {
    final uid = _activeUserId;
    if (uid == null) return;
    state = state.copyWith(lastProjectId: id, lastProjectName: name);
    _persist(uid, (prefs) async {
      await prefs.setString(_key(_kLastProjectId, uid), id);
      await prefs.setString(_key(_kLastProjectName, uid), name);
    });
  }

  Future<void> addQuestion(String question) async {
    final uid = _activeUserId;
    if (uid == null || question.trim().isEmpty) return;
    final updated =
        [question.trim(), ...state.recentQuestions].take(5).toList();
    state = state.copyWith(recentQuestions: updated);
    _persist(
      uid,
      (prefs) => prefs.setStringList(_key(_kRecentQuestions, uid), updated),
    );
  }

  void updateEcosystemSnapshot({
    required int health,
    required Map<String, int> scores,
  }) {
    if (_activeUserId == null) return;
    state = state.copyWith(
      overallHealthScore: health,
      ecosystemSnapshot: scores,
    );
  }

  void dismissAlert(String alertId) {
    if (_activeUserId == null || state.dismissedAlerts.contains(alertId))
      return;
    state = state.copyWith(
      dismissedAlerts: [...state.dismissedAlerts, alertId],
    );
  }

  bool isAlertDismissed(String alertId) =>
      state.dismissedAlerts.contains(alertId);

  Future<void> incrementInteraction() async {
    final uid = _activeUserId;
    if (uid == null) return;
    final count = state.interactionCount + 1;
    state = state.copyWith(interactionCount: count);
    _persist(
      uid,
      (prefs) => prefs.setInt(_key(_kInteractionCount, uid), count),
    );
  }

  void _persist(
    String uid,
    Future<void> Function(SharedPreferences) operation,
  ) async {
    try {
      if (_activeUserId != uid) return;
      final prefs = await SharedPreferences.getInstance();
      if (_activeUserId != uid) return;
      await operation(prefs);
    } catch (error) {
      assert(() {
        debugPrint('[IveMemory] persist failed: $error');
        return true;
      }());
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final iveMemoryProvider = StateNotifierProvider<IveMemoryNotifier, IveMemory>(
  (_) => IveMemoryNotifier(),
);
