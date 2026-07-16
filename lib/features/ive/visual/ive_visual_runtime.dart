import 'ive_avatar_state.dart';
import '../domain/ive_visual_event.dart';

// ── Abstract runtime interface ────────────────────────────────────────────────
// The Context Engine emits states. The Visual Runtime translates states to
// Rive inputs (or fallback visuals). No business logic lives here.

abstract interface class IveVisualRuntime {
  /// Initializes the runtime. Throws if the asset cannot be loaded.
  Future<void> initialize();

  /// True after [initialize] completes successfully.
  bool get isReady;

  /// Transitions to a new visual state.
  void setState(IveVisualState state);

  /// Fires a one-shot trigger animation.
  void trigger(IveVisualTrigger trigger);

  // ── Granular inputs (all no-ops when not ready) ───────────────────────────

  void setListening(bool value);
  void setThinking(bool value);
  void setSpeaking(bool value);
  void setVisible(bool value);
  void setAttentionLevel(double value);
  void setExpressionIntensity(double value);
  void setSpeechActivity(double value);
  void setHasUnreadInsight(bool value);

  /// Releases all resources.
  void dispose();
}
