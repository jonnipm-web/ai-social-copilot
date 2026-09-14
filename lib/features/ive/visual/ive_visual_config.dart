// ── Rive asset paths ──────────────────────────────────────────────────────────

abstract final class IveAssetPaths {
  // IVE-AVATAR-RIVE-RUNTIME-03B6C — temporary canary pointer, isolated branch
  // only. Points at the verified 03B6R cloud baseline (fileId 2578290,
  // revision 46876824, SHA-256 eabbfd3658479efe3c90cdef571f04c3fe2129d
  // 218146ef466176bc62ac2cd1f) exported as ive_executive_03b6_canary.riv.
  // Do NOT rename to ive_executive_v1.riv until a production gate approves
  // it; do NOT merge this pointer change to main as-is.
  static const riveAsset      = 'assets/ive/rive/ive_executive_03b6_canary.riv';
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
