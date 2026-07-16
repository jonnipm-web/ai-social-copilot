import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ive_visual_event.dart';
import '../visual/ive_avatar_state.dart';

// ── Visual Trigger Notifier ───────────────────────────────────────────────────
// Allows any provider to fire visual triggers that the IveAvatar widget picks
// up. Decoupled from the Rive runtime itself.

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
