import 'package:flutter/foundation.dart';

import '../models/ive_avatar_context.dart';
import '../models/ive_avatar_state_v2.dart';
import '../models/ive_personality_profile.dart';

// ── V2 Controller state ───────────────────────────────────────────────────────

class IveAvatarControllerState {
  final IveAvatarStateV2      avatarState;
  final IveAvatarContext      context;
  final IvePersonalityProfile profile;
  final bool                  isVisible;

  const IveAvatarControllerState({
    this.avatarState = IveAvatarStateV2.idle,
    this.context     = IveAvatarContext.empty,
    this.profile     = IvePersonalityProfile.executive,
    this.isVisible   = false,
  });

  IveAvatarControllerState copyWith({
    IveAvatarStateV2?      avatarState,
    IveAvatarContext?      context,
    IvePersonalityProfile? profile,
    bool?                  isVisible,
  }) {
    return IveAvatarControllerState(
      avatarState: avatarState ?? this.avatarState,
      context:     context     ?? this.context,
      profile:     profile     ?? this.profile,
      isVisible:   isVisible   ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IveAvatarControllerState &&
          avatarState == other.avatarState &&
          context     == other.context     &&
          profile     == other.profile     &&
          isVisible   == other.isVisible;

  @override
  int get hashCode => Object.hash(avatarState, context, profile, isVisible);
}

// ── V2 Controller ─────────────────────────────────────────────────────────────

class IveAvatarControllerV2 extends ChangeNotifier {
  IveAvatarControllerState _state = const IveAvatarControllerState();

  IveAvatarControllerState get state => _state;

  void setState(IveAvatarControllerState newState) {
    if (_state == newState) return;
    _state = newState;
    notifyListeners();
  }

  void updateAvatarState(IveAvatarStateV2 avatarState) {
    setState(_state.copyWith(avatarState: avatarState));
  }

  void updateContext(IveAvatarContext context) {
    setState(_state.copyWith(context: context));
  }

  void updateProfile(IvePersonalityProfile profile) {
    setState(_state.copyWith(profile: profile));
  }

  void setVisible(bool visible) {
    setState(_state.copyWith(isVisible: visible));
  }

  void show({
    IveAvatarStateV2? state,
    IveAvatarContext? context,
  }) {
    setState(_state.copyWith(
      avatarState: state   ?? _state.avatarState,
      context:     context ?? _state.context,
      isVisible:   true,
    ));
  }

  void hide() => setState(_state.copyWith(isVisible: false));

  void transitionTo(IveAvatarStateV2 newState) {
    updateAvatarState(newState);
  }
}
