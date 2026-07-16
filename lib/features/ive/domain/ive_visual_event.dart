// ── Visual triggers (mapped to Rive trigger inputs) ───────────────────────────

enum IveVisualTrigger {
  wave,
  notify,
  success,
  warning,
  error,
  opportunity,
  focus,
  reset,
}

extension IveVisualTriggerExt on IveVisualTrigger {
  String get riveInputName {
    switch (this) {
      case IveVisualTrigger.wave:        return 'wave';
      case IveVisualTrigger.notify:      return 'notify';
      case IveVisualTrigger.success:     return 'success';
      case IveVisualTrigger.warning:     return 'warning';
      case IveVisualTrigger.error:       return 'error';
      case IveVisualTrigger.opportunity: return 'opportunity';
      case IveVisualTrigger.focus:       return 'focus';
      case IveVisualTrigger.reset:       return 'reset';
    }
  }
}
