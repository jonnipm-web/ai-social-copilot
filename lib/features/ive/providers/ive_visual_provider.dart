import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ive_visual_event.dart';
import '../visual/ive_avatar_state.dart';

// ── Visual Trigger Notifier ───────────────────────────────────────────────────
// Allows any provider to fire visual triggers that the IveAvatar widget picks
// up. Decoupled from the Rive runtime itself.
//
// STATUS (IVE-AVATAR-STATE-MACHINE-02 audit): still unwired — no production
// call site reads either provider below. Left in place deliberately, not
// removed: `iveVisualTriggerProvider`'s 8 Rive triggers (wave/notify/success/
// warning/error/opportunity/focus/reset) have no consumer in the fallback
// renderer (IveVisualFallback ignores triggers) and no shipped .riv to
// animate them, so wiring them now would be invisible motion with no real
// event behind it. `iveVisualStateOverrideProvider` would compete with
// IveState.interaction (see ive_provider.dart beginThinking/
// completeInteraction) as a second visual-state authority — this mission
// deliberately kept ONE source of truth (IveState) instead. Re-evaluate once
// a real .riv asset ships and/or a concrete screen needs a manual override.

class IveVisualTriggerNotifier extends StateNotifier<IveVisualTrigger?> {
  IveVisualTriggerNotifier() : super(null);

  void fire(IveVisualTrigger trigger) => state = trigger;
  void clear()                        => state = null;
}

final iveVisualTriggerProvider =
    StateNotifierProvider<IveVisualTriggerNotifier, IveVisualTrigger?>(
  (_) => IveVisualTriggerNotifier(),
);

// ── Manual visual state override (optional) ───────────────────────────────────
// Screens that need to temporarily override IVE's state (e.g. chat screen
// setting "listening" while the user types) can read this provider.
// null means "follow IveStateMapper.fromIveState" — the default.

final iveVisualStateOverrideProvider =
    StateProvider<IveVisualState?>((ref) => null);
