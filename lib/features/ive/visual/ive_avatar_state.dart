import 'package:flutter/material.dart';

import '../../../data/models/ive_issue.dart';
import '../../../data/models/ive_state.dart';

// ── Visual State ──────────────────────────────────────────────────────────────

enum IveVisualState {
  idle,
  attentive,
  listening,
  thinking,
  speaking,
  success,
  warning,
  error,
  opportunity,
  executive,
}

// ── State Config ──────────────────────────────────────────────────────────────

class IveVisualStateConfig {
  final Color  ringColor;
  final Color  glowColor;
  final double glowIntensity;
  final Color  overlayColor;
  final double overlayOpacity;
  final int    stateIndex;

  const IveVisualStateConfig({
    required this.ringColor,
    required this.glowColor,
    required this.glowIntensity,
    required this.overlayColor,
    required this.overlayOpacity,
    required this.stateIndex,
  });

  static IveVisualStateConfig forState(IveVisualState state) {
    switch (state) {
      case IveVisualState.idle:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF6C63FF),
          glowColor:      Color(0xFF6C63FF),
          glowIntensity:  0.35,
          overlayColor:   Color(0xFF6C63FF),
          overlayOpacity: 0.0,
          stateIndex:     0,
        );
      case IveVisualState.attentive:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF9B8FFF),
          glowColor:      Color(0xFF9B8FFF),
          glowIntensity:  0.45,
          overlayColor:   Color(0xFF9B8FFF),
          overlayOpacity: 0.05,
          stateIndex:     1,
        );
      case IveVisualState.listening:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF4DA6FF),
          glowColor:      Color(0xFF4DA6FF),
          glowIntensity:  0.55,
          overlayColor:   Color(0xFF4DA6FF),
          overlayOpacity: 0.05,
          stateIndex:     2,
        );
      case IveVisualState.thinking:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF00C6FF),
          glowColor:      Color(0xFF00C6FF),
          glowIntensity:  0.50,
          overlayColor:   Color(0xFF00C6FF),
          overlayOpacity: 0.04,
          stateIndex:     3,
        );
      case IveVisualState.speaking:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF7B5CF6),
          glowColor:      Color(0xFF7B5CF6),
          glowIntensity:  0.65,
          overlayColor:   Color(0xFF7B5CF6),
          overlayOpacity: 0.06,
          stateIndex:     4,
        );
      case IveVisualState.success:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF00E875),
          glowColor:      Color(0xFF00E875),
          glowIntensity:  0.70,
          overlayColor:   Color(0xFF00E875),
          overlayOpacity: 0.08,
          stateIndex:     5,
        );
      case IveVisualState.warning:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFFFFB020),
          glowColor:      Color(0xFFFFB020),
          glowIntensity:  0.65,
          overlayColor:   Color(0xFFFFB020),
          overlayOpacity: 0.07,
          stateIndex:     6,
        );
      case IveVisualState.error:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFFFF3D5A),
          glowColor:      Color(0xFFFF3D5A),
          glowIntensity:  0.75,
          overlayColor:   Color(0xFFFF3D5A),
          overlayOpacity: 0.10,
          stateIndex:     7,
        );
      case IveVisualState.opportunity:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFF00FFD0),
          glowColor:      Color(0xFF00FFD0),
          glowIntensity:  0.65,
          overlayColor:   Color(0xFF00FFD0),
          overlayOpacity: 0.06,
          stateIndex:     8,
        );
      case IveVisualState.executive:
        return const IveVisualStateConfig(
          ringColor:      Color(0xFFD4AF37),
          glowColor:      Color(0xFFD4AF37),
          glowIntensity:  0.60,
          overlayColor:   Color(0xFFD4AF37),
          overlayOpacity: 0.05,
          stateIndex:     9,
        );
    }
  }
}

// ── State Mapper ──────────────────────────────────────────────────────────────

abstract final class IveVisualStateMapper {
  static IveVisualState fromIveState(IveState state) {
    // Active issue takes priority
    if (state.activeIssue != null && state.bubbleVisible) {
      switch (state.activeIssue!.severity) {
        case IveIssueSeverity.critical:
        case IveIssueSeverity.error:
          return IveVisualState.error;
        case IveIssueSeverity.warning:
          return IveVisualState.warning;
        case IveIssueSeverity.info:
          return IveVisualState.attentive;
      }
    }

    // Map expression to visual state
    switch (state.expression) {
      case IveExpression.happy:    return IveVisualState.idle;
      case IveExpression.thinking: return IveVisualState.thinking;
      case IveExpression.excited:  return IveVisualState.success;
      case IveExpression.neutral:  return IveVisualState.attentive;
      case IveExpression.winking:  return IveVisualState.opportunity;
    }
  }
}
