import 'ive_avatar_state_v2.dart';

// ── IveAvatarConfiguration — per-instance display settings ───────────────────

class IveAvatarConfiguration {
  final IveAvatarDisplayMode displayMode;
  final IveAvatarPlacement   placement;
  final double               size;
  final bool                 showStatusRing;
  final bool                 showLabel;
  final bool                 showTooltip;
  final bool                 interactive;
  final bool                 debugMode;

  const IveAvatarConfiguration({
    this.displayMode    = IveAvatarDisplayMode.compact,
    this.placement      = IveAvatarPlacement.automatic,
    this.size           = 56,
    this.showStatusRing = true,
    this.showLabel      = false,
    this.showTooltip    = true,
    this.interactive    = true,
    this.debugMode      = false,
  });

  static const compact = IveAvatarConfiguration(
    displayMode:    IveAvatarDisplayMode.compact,
    size:           56,
    showStatusRing: true,
    showLabel:      false,
  );

  static const assistantButton = IveAvatarConfiguration(
    displayMode:    IveAvatarDisplayMode.assistantButton,
    size:           64,
    showStatusRing: true,
    showLabel:      false,
    placement:      IveAvatarPlacement.floatingBottomRight,
  );

  static const card = IveAvatarConfiguration(
    displayMode:    IveAvatarDisplayMode.card,
    size:           80,
    showStatusRing: true,
    showLabel:      true,
  );

  static const full = IveAvatarConfiguration(
    displayMode:    IveAvatarDisplayMode.full,
    size:           128,
    showStatusRing: true,
    showLabel:      true,
    showTooltip:    false,
  );

  IveAvatarConfiguration copyWith({
    IveAvatarDisplayMode? displayMode,
    IveAvatarPlacement?   placement,
    double?               size,
    bool?                 showStatusRing,
    bool?                 showLabel,
    bool?                 showTooltip,
    bool?                 interactive,
    bool?                 debugMode,
  }) {
    return IveAvatarConfiguration(
      displayMode:    displayMode    ?? this.displayMode,
      placement:      placement      ?? this.placement,
      size:           size           ?? this.size,
      showStatusRing: showStatusRing ?? this.showStatusRing,
      showLabel:      showLabel      ?? this.showLabel,
      showTooltip:    showTooltip    ?? this.showTooltip,
      interactive:    interactive    ?? this.interactive,
      debugMode:      debugMode      ?? this.debugMode,
    );
  }
}
