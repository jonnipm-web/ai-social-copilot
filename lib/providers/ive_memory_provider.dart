import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/ive_memory.dart';

// ── Chaves SharedPreferences ───────────────────────────────────────────────────
const _kLastRoute        = 'ive_last_route';
const _kLastProjectId    = 'ive_last_project_id';
const _kLastProjectName  = 'ive_last_project_name';
const _kRecentQuestions  = 'ive_recent_questions';
const _kInteractionCount = 'ive_interaction_count';

class IveMemoryNotifier extends StateNotifier<IveMemory> {
  IveMemoryNotifier() : super(const IveMemory()) {
    _load();
  }

  // ── Carrega do SharedPreferences na inicialização ─────────────────────────
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = state.copyWith(
        lastRoute:        prefs.getString(_kLastRoute)        ?? '',
        lastProjectId:    prefs.getString(_kLastProjectId),
        lastProjectName:  prefs.getString(_kLastProjectName),
        recentQuestions:  prefs.getStringList(_kRecentQuestions) ?? [],
        interactionCount: prefs.getInt(_kInteractionCount)    ?? 0,
      );
    } catch (_) {
      // SharedPreferences pode falhar em ambiente de teste — ignora
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  Future<void> setRoute(String route) async {
    if (route == state.lastRoute) return;
    state = state.copyWith(lastRoute: route);
    _persist((prefs) => prefs.setString(_kLastRoute, route));
  }

  Future<void> setActiveProject(String id, String name) async {
    state = state.copyWith(lastProjectId: id, lastProjectName: name);
    _persist((prefs) async {
      await prefs.setString(_kLastProjectId, id);
      await prefs.setString(_kLastProjectName, name);
    });
  }

  Future<void> addQuestion(String question) async {
    if (question.trim().isEmpty) return;
    final updated = [question.trim(), ...state.recentQuestions]
        .take(5)
        .toList();
    state = state.copyWith(recentQuestions: updated);
    _persist((prefs) => prefs.setStringList(_kRecentQuestions, updated));
  }

  void updateEcosystemSnapshot({
    required int health,
    required Map<String, int> scores,
  }) {
    state = state.copyWith(
      overallHealthScore: health,
      ecosystemSnapshot:  scores,
    );
    // health e snapshot são sessão apenas — não persistem
  }

  void dismissAlert(String alertId) {
    if (state.dismissedAlerts.contains(alertId)) return;
    state = state.copyWith(
      dismissedAlerts: [...state.dismissedAlerts, alertId],
    );
  }

  bool isAlertDismissed(String alertId) =>
      state.dismissedAlerts.contains(alertId);

  Future<void> incrementInteraction() async {
    final count = state.interactionCount + 1;
    state = state.copyWith(interactionCount: count);
    _persist((prefs) => prefs.setInt(_kInteractionCount, count));
  }

  // ── Utilitário privado ────────────────────────────────────────────────────
  void _persist(Future<void> Function(SharedPreferences) fn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await fn(prefs);
    } catch (_) {}
  }
}

// ── Provider global ───────────────────────────────────────────────────────────
final iveMemoryProvider = StateNotifierProvider<IveMemoryNotifier, IveMemory>(
  (_) => IveMemoryNotifier(),
);
