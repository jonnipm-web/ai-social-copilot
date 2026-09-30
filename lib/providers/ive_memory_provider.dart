import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/ive_memory.dart';

// ── Chaves SharedPreferences ───────────────────────────────────────────────────
const _kLastRoute        = 'ive_last_route';
const _kLastProjectId    = 'ive_last_project_id';
const _kLastProjectName  = 'ive_last_project_name';
const _kRecentQuestions  = 'ive_recent_questions';
const _kInteractionCount = 'ive_interaction_count';
// IVE-INTELLIGENCE-CORE-01 (IVE-F01) — which user the device-local IVE
// memory belongs to. SharedPreferences is per DEVICE, not per user: without
// this, a second person signing in on the same phone/browser inherited the
// previous user's recent questions and last project name.
const _kOwnerUserId      = 'ive_memory_owner';
const _kAllIveKeys = [
  _kLastRoute, _kLastProjectId, _kLastProjectName, _kRecentQuestions,
  _kInteractionCount, _kOwnerUserId,
];

class IveMemoryNotifier extends StateNotifier<IveMemory> {
  IveMemoryNotifier() : super(const IveMemory()) {
    _load();
  }

  // IVE-INTELLIGENCE-CORE-01 (IVE-F01) — completes when the initial async
  // load from SharedPreferences has finished. A session reset/bind waits for
  // it; otherwise a load still in flight could re-apply the PREVIOUS user's
  // data after the reset (a real race found by the isolation tests).
  final Completer<void> _loaded = Completer<void>();

  // ── Carrega do SharedPreferences na inicialização ─────────────────────────
  Future<void> _load() async {
    try {
      if (_loaded.isCompleted) return;
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
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────

  // GATE-17-FINAL-CLOSURE (Section 12, physical crash, 2026-09-21) — same
  // confirmed trigger as IveNotifier.setRoute (see its own comment):
  // IveRouteObserver.didPush firing during the Navigator's own first mount
  // calls _IveOverlayState._onRouteChange, which calls THIS setRoute right
  // alongside IveNotifier's. Deferred the same way.
  Future<void> setRoute(String route) async {
    if (route == state.lastRoute) return;
    _runSafely(() {
      state = state.copyWith(lastRoute: route);
      _persist((prefs) => prefs.setString(_kLastRoute, route));
    });
  }

  void _runSafely(void Function() mutate) {
    void apply() {
      if (!mounted) return;
      mutate();
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      apply();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    }
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

  /// IVE-INTELLIGENCE-CORE-01 (IVE-F01) — wipes every device-local IVE key
  /// and the in-memory state. Called on sign-out and whenever a different
  /// user signs in (see ive_session_isolation.dart).
  Future<void> clearForSessionChange() async {
    await _loaded.future;
    if (mounted) state = const IveMemory();
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in _kAllIveKeys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Binds the device-local memory to [userId]. If it was written for
  /// someone else (or for nobody — legacy data from before this field
  /// existed), it is wiped first. Returns true when a wipe happened.
  Future<bool> bindToUser(String userId) async {
    await _loaded.future;
    try {
      final prefs = await SharedPreferences.getInstance();
      final owner = prefs.getString(_kOwnerUserId);
      if (owner == userId) return false;
      await clearForSessionChange();
      await prefs.setString(_kOwnerUserId, userId);
      return true;
    } catch (_) {
      await clearForSessionChange();
      return true;
    }
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
