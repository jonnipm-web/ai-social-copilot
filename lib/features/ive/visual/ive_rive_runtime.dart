import '../domain/ive_visual_event.dart';
import 'ive_avatar_state.dart';
import 'ive_visual_config.dart';
import 'ive_visual_runtime.dart';

// IVE-AVATAR-COMMERCIAL-FALLBACK-04 — Rive track FROZEN.
// IveRiveFeatureGate.enabled = false; this class is never instantiated at
// runtime. The rive package was removed from pubspec.yaml to unblock Android
// APK builds (rive_common JNI native-library Gradle failure, rive_common
// 0.4.15). Re-entry requires a reviewed code change under an explicit
// Agente Martins/Paulo decision (see docs/ive/IVE_RIVE_FREEZE_RECORD.md §05).

class IveRiveRuntime implements IveVisualRuntime {
  final String artboardName;

  IveRiveRuntime({this.artboardName = IveRiveInputs.artboardCompact});

  @override
  bool get isReady => false;

  @override
  Future<void> initialize() async =>
      throw StateError('Rive is frozen (IveRiveFeatureGate.enabled = false).');

  @override
  void setState(IveVisualState state) {}

  @override
  void trigger(IveVisualTrigger t) {}

  @override
  void setListening(bool v) {}

  @override
  void setThinking(bool v) {}

  @override
  void setSpeaking(bool v) {}

  @override
  void setVisible(bool v) {}

  @override
  void setAttentionLevel(double v) {}

  @override
  void setExpressionIntensity(double v) {}

  @override
  void setSpeechActivity(double v) {}

  @override
  void setHasUnreadInsight(bool v) {}

  @override
  void dispose() {}
}
