import 'package:flutter/material.dart';

import '../models/ive_avatar_state_v2.dart';
import 'ive_avatar_tokens.dart';

// ── IveAvatarThemeData — resolved theme for a given state ─────────────────────

class IveAvatarThemeData {
  final Color  ringColor;
  final Color  glowColor;
  final Color  backgroundColor;
  final Color  labelColor;
  final double glowIntensity;
  final TextStyle labelStyle;

  const IveAvatarThemeData({
    required this.ringColor,
    required this.glowColor,
    required this.backgroundColor,
    required this.labelColor,
    required this.glowIntensity,
    required this.labelStyle,
  });
}

// ── IveAvatarTheme — static factory ──────────────────────────────────────────

abstract final class IveAvatarTheme {
  static IveAvatarThemeData forState(IveAvatarStateV2 state) {
    final config = IveAvatarStateConfigV2.forState(state);

    return IveAvatarThemeData(
      ringColor:       config.ringColor,
      glowColor:       config.glowColor,
      backgroundColor: IveAvatarTokens.backgroundDark,
      labelColor:      config.ringColor,
      glowIntensity:   config.glowIntensity,
      labelStyle: TextStyle(
        color:      config.ringColor,
        fontSize:   IveAvatarTokens.labelFontSizeSmall,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  static Color stateColor(IveAvatarStateV2 state) {
    return IveAvatarStateConfigV2.forState(state).ringColor;
  }

  static Color disabledColor(Color base) => base.withOpacity(0.3);
}
