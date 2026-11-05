import 'package:flutter/material.dart';

import '../../../data/models/ive_issue.dart';
import '../../../data/models/ive_state.dart';
import 'package:ai_social_copilot/core/theme/app_tokens.dart';

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
  final Color ringColor;
  final Color glowColor;
  final double glowIntensity;
  final Color overlayColor;
  final double overlayOpacity;
  final int stateIndex;

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
          ringColor: AppColors.accent,
          glowColor: AppColors.accent,
          glowIntensity: 0.35,
          overlayColor: AppColors.accent,
          overlayOpacity: 0.0,
          stateIndex: 0,
        );
      case IveVisualState.attentive:
        return const IveVisualStateConfig(
          ringColor: AppColors.accent,
          glowColor: AppColors.accent,
          glowIntensity: 0.45,
          overlayColor: AppColors.accent,
          overlayOpacity: 0.05,
          stateIndex: 1,
        );
      case IveVisualState.listening:
        return const IveVisualStateConfig(
          ringColor: AppColors.info,
          glowColor: AppColors.info,
          glowIntensity: 0.55,
          overlayColor: AppColors.info,
          overlayOpacity: 0.05,
          stateIndex: 2,
        );
      case IveVisualState.thinking:
        return const IveVisualStateConfig(
          ringColor: AppColors.info,
          glowColor: AppColors.info,
          glowIntensity: 0.50,
          overlayColor: AppColors.info,
          overlayOpacity: 0.04,
          stateIndex: 3,
        );
      case IveVisualState.speaking:
        return const IveVisualStateConfig(
          ringColor: AppColors.accent,
          glowColor: AppColors.accent,
          glowIntensity: 0.65,
          overlayColor: AppColors.accent,
          overlayOpacity: 0.06,
          stateIndex: 4,
        );
      case IveVisualState.success:
        return const IveVisualStateConfig(
          ringColor: AppColors.positive,
          glowColor: AppColors.positive,
          glowIntensity: 0.70,
          overlayColor: AppColors.positive,
          overlayOpacity: 0.08,
          stateIndex: 5,
        );
      case IveVisualState.warning:
        return const IveVisualStateConfig(
          ringColor: AppColors.warning,
          glowColor: AppColors.warning,
          glowIntensity: 0.65,
          overlayColor: AppColors.warning,
          overlayOpacity: 0.07,
          stateIndex: 6,
        );
      case IveVisualState.error:
        return const IveVisualStateConfig(
          ringColor: AppColors.negative,
          glowColor: AppColors.negative,
          glowIntensity: 0.75,
          overlayColor: AppColors.negative,
          overlayOpacity: 0.10,
          stateIndex: 7,
        );
      case IveVisualState.opportunity:
        return const IveVisualStateConfig(
          ringColor: AppColors.accent,
          glowColor: AppColors.accent,
          glowIntensity: 0.65,
          overlayColor: AppColors.accent,
          overlayOpacity: 0.06,
          stateIndex: 8,
        );
      case IveVisualState.executive:
        return const IveVisualStateConfig(
          ringColor: AppColors.gold,
          glowColor: AppColors.gold,
          glowIntensity: 0.60,
          overlayColor: AppColors.gold,
          overlayOpacity: 0.05,
          stateIndex: 9,
        );
    }
  }
}

// ── State Mapper ──────────────────────────────────────────────────────────────

abstract final class IveVisualStateMapper {
  static IveVisualState fromIveState(IveState state) {
    // Live chat interaction takes priority over everything else — it's a
    // short-lived overlay (see IveNotifier.beginThinking/completeInteraction)
    // that must not be confused with a persistent business/context state.
    switch (state.interaction) {
      case IveInteractionState.thinking:
        return IveVisualState.thinking;
      case IveInteractionState.speaking:
        return IveVisualState.speaking;
      case null:
        break;
    }

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
      case IveExpression.happy:
        return IveVisualState.idle;
      case IveExpression.thinking:
        return IveVisualState.thinking;
      case IveExpression.excited:
        return IveVisualState.success;
      case IveExpression.neutral:
        return IveVisualState.attentive;
      case IveExpression.winking:
        return IveVisualState.opportunity;
    }
  }
}
