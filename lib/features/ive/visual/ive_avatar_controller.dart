import 'package:flutter/foundation.dart';

import '../domain/ive_visual_event.dart';
import 'ive_avatar_state.dart';
import 'ive_rive_runtime.dart';
import 'ive_visual_runtime.dart';

// ── Avatar Controller ─────────────────────────────────────────────────────────
// Bridge between the IVE Context Engine (business logic / IveProvider) and the
// Visual Runtime (Rive or fallback). Lives inside the IveAvatar widget's state.

class IveAvatarController extends ChangeNotifier {
  IveRiveRuntime? _riveRuntime;
  IveVisualState  _currentState   = IveVisualState.idle;
  bool            _riveReady      = false;
  bool            _disposed       = false;

  IveVisualState get currentState => _currentState;
  bool           get isRiveReady  => _riveReady;

  /// Returns the Rive runtime (for the Rive widget to access the artboard).
  IveRiveRuntime? get riveRuntime => _riveRuntime;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<bool> initializeRive({String? artboardName}) async {
    try {
      _riveRuntime = artboardName != null
          ? IveRiveRuntime(artboardName: artboardName)
          : IveRiveRuntime();
      await _riveRuntime!.initialize();
      _riveReady = true;
      notifyListeners();
      return true;
    } catch (_) {
      // .riv asset missing or malformed — fallback will be used
      _riveRuntime = null;
      _riveReady   = false;
      return false;
    }
  }

  // ── State management ──────────────────────────────────────────────────────

  void applyVisualState(IveVisualState state) {
    if (_disposed) return;
    if (_currentState == state) return;
    _currentState = state;

    if (_riveReady) {
      _riveRuntime!.setState(state);
    }

    notifyListeners();
  }

  void triggerAnimation(IveVisualTrigger trigger) {
    if (_disposed || !_riveReady) return;
    _riveRuntime!.trigger(trigger);
  }

  // ── Granular inputs ───────────────────────────────────────────────────────

  void setListening(bool value) {
    if (_riveReady) _riveRuntime!.setListening(value);
  }

  void setThinking(bool value) {
    if (_riveReady) _riveRuntime!.setThinking(value);
  }

  void setSpeaking(bool value) {
    if (_riveReady) _riveRuntime!.setSpeaking(value);
  }

  void setAttentionLevel(double value) {
    if (_riveReady) _riveRuntime!.setAttentionLevel(value);
  }

  void setExpressionIntensity(double value) {
    if (_riveReady) _riveRuntime!.setExpressionIntensity(value);
  }

  void setSpeechActivity(double value) {
    if (_riveReady) _riveRuntime!.setSpeechActivity(value);
  }

  void setHasUnreadInsight(bool value) {
    if (_riveReady) _riveRuntime!.setHasUnreadInsight(value);
  }

  @override
  void dispose() {
    _disposed = true;
    _riveRuntime?.dispose();
    super.dispose();
  }
}
