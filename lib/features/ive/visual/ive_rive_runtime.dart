import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

import '../domain/ive_visual_event.dart';
import 'ive_avatar_state.dart';
import 'ive_visual_config.dart';
import 'ive_visual_runtime.dart';

// ── Rive Runtime ──────────────────────────────────────────────────────────────
// Wraps a Rive State Machine and translates IveVisualState → input values.
// initialize() throws if the .riv asset is missing — the caller should catch
// and fall back to IveVisualFallback.

class IveRiveRuntime implements IveVisualRuntime {
  final String artboardName;

  IveRiveRuntime({this.artboardName = IveRiveInputs.artboardCompact});

  Artboard?               _artboard;
  StateMachineController? _smCtrl;

  // Boolean inputs
  SMIBool? _isListening;
  SMIBool? _isThinking;
  SMIBool? _isSpeaking;
  SMIBool? _isVisible;
  SMIBool? _hasUnreadInsight;

  // Number inputs
  SMINumber? _stateIndex;
  SMINumber? _attentionLevel;
  SMINumber? _expressionIntensity;
  SMINumber? _speechActivity;

  // Trigger inputs
  SMITrigger? _wave;
  SMITrigger? _notify;
  SMITrigger? _successTrigger;
  SMITrigger? _warningTrigger;
  SMITrigger? _errorTrigger;
  SMITrigger? _opportunityTrigger;
  SMITrigger? _focus;
  SMITrigger? _reset;

  bool _ready = false;

  @override
  bool get isReady => _ready;

  /// The loaded artboard — pass to [Rive] widget.
  Artboard? get artboard => _artboard;

  // ── Safe input finders ────────────────────────────────────────────────────
  // Rive has both SMIBool and SMITrigger implement SMIInput<bool>.
  // Using type-safe iteration avoids CastError on mismatches.

  static SMIBool? _findBool(StateMachineController ctrl, String name) {
    for (final i in ctrl.inputs) {
      if (i.name == name && i is SMIBool) return i;
    }
    return null;
  }

  static SMINumber? _findNumber(StateMachineController ctrl, String name) {
    for (final i in ctrl.inputs) {
      if (i.name == name && i is SMINumber) return i;
    }
    return null;
  }

  static SMITrigger? _findTrigger(StateMachineController ctrl, String name) {
    for (final i in ctrl.inputs) {
      if (i.name == name && i is SMITrigger) return i;
    }
    return null;
  }

  // ── Initialization ────────────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    final bytes = await rootBundle.load(IveAssetPaths.riveAsset);
    final file  = RiveFile.import(bytes);

    final artboard = file.artboardByName(artboardName) ?? file.mainArtboard;

    final ctrl = StateMachineController.fromArtboard(
      artboard,
      IveRiveInputs.stateMachine,
    );

    if (ctrl == null) {
      throw StateError(
        'State machine "${IveRiveInputs.stateMachine}" not found '
        'in artboard "$artboardName". '
        'See docs/ive/IVE_RIVE_ASSET_SPECIFICATION.md.',
      );
    }

    artboard.addController(ctrl);

    _isListening        = _findBool(ctrl,   IveRiveInputs.isListening);
    _isThinking         = _findBool(ctrl,   IveRiveInputs.isThinking);
    _isSpeaking         = _findBool(ctrl,   IveRiveInputs.isSpeaking);
    _isVisible          = _findBool(ctrl,   IveRiveInputs.isVisible);
    _hasUnreadInsight   = _findBool(ctrl,   IveRiveInputs.hasUnreadInsight);
    _stateIndex         = _findNumber(ctrl, IveRiveInputs.stateIndex);
    _attentionLevel     = _findNumber(ctrl, IveRiveInputs.attentionLevel);
    _expressionIntensity = _findNumber(ctrl, IveRiveInputs.expressionIntensity);
    _speechActivity     = _findNumber(ctrl, IveRiveInputs.speechActivity);
    _wave               = _findTrigger(ctrl, IveRiveInputs.wave);
    _notify             = _findTrigger(ctrl, IveRiveInputs.notify);
    _successTrigger     = _findTrigger(ctrl, IveRiveInputs.success);
    _warningTrigger     = _findTrigger(ctrl, IveRiveInputs.warning);
    _errorTrigger       = _findTrigger(ctrl, IveRiveInputs.error);
    _opportunityTrigger = _findTrigger(ctrl, IveRiveInputs.opportunity);
    _focus              = _findTrigger(ctrl, IveRiveInputs.focus);
    _reset              = _findTrigger(ctrl, IveRiveInputs.reset);

    _artboard = artboard;
    _smCtrl   = ctrl;
    _ready    = true;

    _isVisible?.value = true;
  }

  // ── State ─────────────────────────────────────────────────────────────────

  @override
  void setState(IveVisualState state) {
    if (!_ready) return;
    _stateIndex?.value = IveVisualStateConfig.forState(state).stateIndex.toDouble();
    _isListening?.value = state == IveVisualState.listening;
    _isThinking?.value  = state == IveVisualState.thinking;
    _isSpeaking?.value  = state == IveVisualState.speaking;
  }

  @override
  void trigger(IveVisualTrigger t) {
    if (!_ready) return;
    switch (t) {
      case IveVisualTrigger.wave:        _wave?.fire();               break;
      case IveVisualTrigger.notify:      _notify?.fire();             break;
      case IveVisualTrigger.success:     _successTrigger?.fire();     break;
      case IveVisualTrigger.warning:     _warningTrigger?.fire();     break;
      case IveVisualTrigger.error:       _errorTrigger?.fire();       break;
      case IveVisualTrigger.opportunity: _opportunityTrigger?.fire(); break;
      case IveVisualTrigger.focus:       _focus?.fire();              break;
      case IveVisualTrigger.reset:       _reset?.fire();              break;
    }
  }

  @override void setListening(bool v)            { _isListening?.value = v; }
  @override void setThinking(bool v)             { _isThinking?.value  = v; }
  @override void setSpeaking(bool v)             { _isSpeaking?.value  = v; }
  @override void setVisible(bool v)              { _isVisible?.value   = v; }
  @override void setHasUnreadInsight(bool v)     { _hasUnreadInsight?.value = v; }
  @override void setAttentionLevel(double v)     { _attentionLevel?.value = v; }
  @override void setExpressionIntensity(double v){ _expressionIntensity?.value = v; }
  @override void setSpeechActivity(double v)     { _speechActivity?.value = v; }

  @override
  void dispose() {
    _smCtrl?.dispose();
    _ready = false;
  }
}
