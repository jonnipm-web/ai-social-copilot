// ── Rive asset paths ──────────────────────────────────────────────────────────

abstract final class IveAssetPaths {
  static const riveAsset      = 'assets/ive/rive/ive_executive_v1.riv';
  static const referenceImage = 'assets/ive/reference/ive_character_reference.png';
}

// ── Rive State Machine contract ───────────────────────────────────────────────

abstract final class IveRiveInputs {
  static const stateMachine       = 'IVE_EXECUTIVE_STATE_MACHINE';

  // Artboards
  static const artboardCompact    = 'IVE_AVATAR_COMPACT';
  static const artboardChat       = 'IVE_AVATAR_CHAT';
  static const artboardHalfBody   = 'IVE_HALF_BODY';
  static const artboardFull       = 'IVE_FULL_REFERENCE';

  // Boolean inputs
  static const isListening        = 'isListening';
  static const isThinking         = 'isThinking';
  static const isSpeaking         = 'isSpeaking';
  static const isVisible          = 'isVisible';
  static const hasUnreadInsight   = 'hasUnreadInsight';

  // Number inputs
  static const stateIndex         = 'stateIndex';
  static const attentionLevel     = 'attentionLevel';
  static const expressionIntensity = 'expressionIntensity';
  static const speechActivity     = 'speechActivity';

  // Trigger inputs
  static const wave               = 'wave';
  static const notify             = 'notify';
  static const success            = 'success';
  static const warning            = 'warning';
  static const error              = 'error';
  static const opportunity        = 'opportunity';
  static const focus              = 'focus';
  static const reset              = 'reset';
}

// ── Avatar size ───────────────────────────────────────────────────────────────

enum IveAvatarSize {
  compact(56),
  standard(72),
  large(96),
  chat(128),
  detail(160);

  final double dp;
  const IveAvatarSize(this.dp);
}
