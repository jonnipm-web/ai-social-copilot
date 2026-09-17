// ── Rive asset paths ──────────────────────────────────────────────────────────

abstract final class IveAssetPaths {
  // IVE-AVATAR-RIVE-RUNTIME-03B6C — temporary canary pointer, isolated branch
  // only. Points at the verified 03B6R cloud baseline (fileId 2578290,
  // revision 46876824, SHA-256 eabbfd3658479efe3c90cdef571f04c3fe2129d
  // 218146ef466176bc62ac2cd1f) exported as ive_executive_03b6_canary.riv.
  // Do NOT rename to ive_executive_v1.riv until a production gate approves
  // it; do NOT merge this pointer change to main as-is.
  static const riveAsset      = 'assets/ive/rive/ive_executive_03b6_canary.riv';

  // IVE-VISUAL-CANONICAL-INTEGRATION-07 — superseded by [avatarPortrait]
  // below (IveVisualFallback no longer references this). Left defined
  // rather than deleted: removing it is a separate, Codex-gated cleanup
  // decision (not required for this integration), and it has zero
  // remaining references as of this change.
  static const referenceImage = 'assets/ive/reference/ive_character_reference.png';

  // IVE-VISUAL-CANONICAL-INTEGRATION-07 — the approved canonical IVE
  // portrait (see docs/ive/IVE_AVATAR_03B2_ASSET_PROVENANCE.md), used by
  // IveVisualFallback as the commercial Avatar's displayed identity. A real
  // alpha-channel character cutout (1254x1254 RGBA, square), unlike
  // [referenceImage] above -- a flattened, non-transparent 1536x1024
  // design-spec sheet (the full "BASE DO PERSONAGEM" reference grid) never
  // intended for direct circular-avatar display. Master file is immutable;
  // never edit assets/ive/source/ive_avatar_master_03b2.png directly.
  static const avatarPortrait = 'assets/ive/source/ive_avatar_master_03b2.png';
}

// ── Rive feature gate ─────────────────────────────────────────────────────────
// IVE-AVATAR-COMMERCIAL-FALLBACK-04 — the Rive track is FROZEN
// (docs/ive/IVE_RIVE_FREEZE_RECORD.md). The commercial Avatar is
// IveVisualFallback, selected deterministically by this gate BEFORE any Rive
// runtime is constructed — never by waiting for a Rive failure, because
// 03B6O proved a Rive failure can be silent (initialize() succeeds, zero
// pixels drawn). This is a literal constant on purpose (Codex FALLBACK-04
// P1): no build flag, environment variable or CI invocation can flip it —
// re-entry requires a reviewed code change under an explicit Agente
// Martins/Paulo decision (see IVE_RIVE_FREEZE_RECORD.md §05).

abstract final class IveRiveFeatureGate {
  static const bool enabled = false;
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
  detail(160),
  // COMMERCIAL-EXPERIENCE-CLOSURE-16 — owner-rejected the previous IVE
  // dialog for showing a tiny generic chat emoji instead of the canonical
  // 03B2 portrait as its primary identity (mission Section 01.3). `hero` is
  // the size used for that one placement (the chat dialog's empty-state
  // central illustration) — materially larger than any existing use, without
  // inventing a second visual system.
  hero(220);

  final double dp;
  const IveAvatarSize(this.dp);
}
