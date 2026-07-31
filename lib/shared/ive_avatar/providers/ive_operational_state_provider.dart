import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ive_event_bus.dart';
import '../../../data/models/ive_event.dart';
import '../models/ive_avatar_state_v2.dart';

// ── Priority table ────────────────────────────────────────────────────────────
//
// Higher number = higher priority (wins when multiple operations overlap).

const _kStatePriority = <IveAvatarStateV2, int>{
  IveAvatarStateV2.idle: 0,
  IveAvatarStateV2.speaking: 1,
  IveAvatarStateV2.listening: 2,
  IveAvatarStateV2.thinking: 2,
  IveAvatarStateV2.success: 3,
  IveAvatarStateV2.attention: 4,
  IveAvatarStateV2.generating: 5,
  IveAvatarStateV2.researching: 5,
  IveAvatarStateV2.analyzing: 5,
  IveAvatarStateV2.waitingForUser: 6,
  IveAvatarStateV2.warning: 7,
  IveAvatarStateV2.error: 8,
  IveAvatarStateV2.offline: 0,
  IveAvatarStateV2.disabled: 0,
};

int _priority(IveAvatarStateV2 s) => _kStatePriority[s] ?? 0;

// Auto-dismiss durations for terminal states (null = no auto-dismiss).
const _kAutoDismiss = <IveAvatarStateV2, Duration>{
  IveAvatarStateV2.success: Duration(seconds: 3),
  IveAvatarStateV2.error: Duration(seconds: 5),
};

// ── Event → state mapping ─────────────────────────────────────────────────────

IveAvatarStateV2 _mapEventToState(IveEventType type) {
  switch (type) {
    case IveEventType.assetImportStarted:
      return IveAvatarStateV2.researching;
    case IveEventType.assetDownloadFailed:
      return IveAvatarStateV2.error;
    case IveEventType.assetAnalysisStarted:
      return IveAvatarStateV2.analyzing;
    case IveEventType.assetAnalysisCompleted:
      return IveAvatarStateV2.success;
    case IveEventType.assetAnalysisFailed:
      return IveAvatarStateV2.error;
    case IveEventType.scoreChanged:
      return IveAvatarStateV2.attention;
    case IveEventType.opportunityDetected:
      return IveAvatarStateV2.attention;
    case IveEventType.actionGenerated:
      return IveAvatarStateV2.success;
    case IveEventType.actionMutationFailed:
      return IveAvatarStateV2.error;
    case IveEventType.simulationCompleted:
      return IveAvatarStateV2.success;
    case IveEventType.projectCreated:
      return IveAvatarStateV2.success;
    case IveEventType.projectUpdated:
      return IveAvatarStateV2.attention;
    case IveEventType.projectStatusChanged:
      return IveAvatarStateV2.attention;
    case IveEventType.projectDeleted:
      return IveAvatarStateV2.idle;
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class IveOperationalStateNotifier extends StateNotifier<IveAvatarStateV2> {
  IveOperationalStateNotifier() : super(IveAvatarStateV2.idle) {
    _sub = IveEventBus.instance.stream.listen(_onEvent);
  }

  late final StreamSubscription<IveEvent> _sub;
  final _active = <String, IveAvatarStateV2>{}; // operationId → state
  Timer? _dismissTimer;

  void _onEvent(IveEvent event) {
    final mapped = _mapEventToState(event.type);
    final opId = event.entityId ?? event.timestamp.toIso8601String();

    if (mapped == IveAvatarStateV2.idle) {
      _active.remove(opId);
    } else {
      _active[opId] = mapped;
    }

    _updateState(mapped);
  }

  void _updateState(IveAvatarStateV2 triggered) {
    // Pick highest-priority active state
    IveAvatarStateV2 top = IveAvatarStateV2.idle;
    for (final s in _active.values) {
      if (_priority(s) > _priority(top)) top = s;
    }
    // If triggered state has higher priority than active ones, use it
    final candidate = _priority(triggered) >= _priority(top) ? triggered : top;

    if (state == candidate) return;
    state = candidate;

    _dismissTimer?.cancel();
    final autoDismiss = _kAutoDismiss[candidate];
    if (autoDismiss != null) {
      _dismissTimer = Timer(autoDismiss, () {
        _active.removeWhere((_, s) => s == candidate);
        state = IveAvatarStateV2.idle;
      });
    }
  }

  // Manual state update for operations that don't go through IveEventBus.
  void setOperationState(String operationId, IveAvatarStateV2 opState) {
    if (opState == IveAvatarStateV2.idle) {
      _active.remove(operationId);
    } else {
      _active[operationId] = opState;
    }
    _updateState(opState);
  }

  void clearOperation(String operationId) {
    _active.remove(operationId);
    if (_active.isEmpty) {
      _dismissTimer?.cancel();
      state = IveAvatarStateV2.idle;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _sub.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final iveOperationalStateProvider =
    StateNotifierProvider<IveOperationalStateNotifier, IveAvatarStateV2>(
  (_) => IveOperationalStateNotifier(),
);
