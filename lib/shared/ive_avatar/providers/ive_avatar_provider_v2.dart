import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/ive_avatar_controller_v2.dart';
import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';
import '../services/ive_avatar_context_service.dart';
import '../services/ive_avatar_visibility_service.dart';

// ── Feature flag provider (local constant — V2 is off by default) ─────────────
//
// The flag starts as false and is not sourced from Supabase in V2 preview.
// It will be wired to FeatureFlagService when the user approves V2.

final iveAvatarV2EnabledProvider = Provider<bool>((_) => false);

// ── Services ──────────────────────────────────────────────────────────────────

final iveAvatarVisibilityServiceProvider =
    Provider<IveAvatarVisibilityService>((_) => const IveAvatarVisibilityService());

final iveAvatarContextServiceProvider =
    Provider<IveAvatarContextService>((_) => const IveAvatarContextService());

// ── Notifier ──────────────────────────────────────────────────────────────────

class IveAvatarV2Notifier extends StateNotifier<IveAvatarControllerState> {
  IveAvatarV2Notifier() : super(const IveAvatarControllerState());

  void updateAvatarState(IveAvatarStateV2 avatarState) {
    if (state.avatarState == avatarState) return;
    state = state.copyWith(avatarState: avatarState);
  }

  void updateContext(IveAvatarContext context) {
    state = state.copyWith(context: context);
  }

  void show({IveAvatarStateV2? avatarState}) {
    state = state.copyWith(
      avatarState: avatarState ?? state.avatarState,
      isVisible:   true,
    );
  }

  void hide() => state = state.copyWith(isVisible: false);

  void reset() => state = const IveAvatarControllerState();
}

// ── Providers ─────────────────────────────────────────────────────────────────

final iveAvatarV2Provider =
    StateNotifierProvider<IveAvatarV2Notifier, IveAvatarControllerState>(
  (_) => IveAvatarV2Notifier(),
);

// Selector providers — prevent unnecessary rebuilds

final iveAvatarV2StateProvider = Provider<IveAvatarStateV2>((ref) {
  return ref.watch(iveAvatarV2Provider.select((s) => s.avatarState));
});

final iveAvatarV2ContextProvider = Provider<IveAvatarContext>((ref) {
  return ref.watch(iveAvatarV2Provider.select((s) => s.context));
});

final iveAvatarV2VisibleProvider = Provider<bool>((ref) {
  return ref.watch(iveAvatarV2Provider.select((s) => s.isVisible));
});
