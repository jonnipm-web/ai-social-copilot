import 'package:flutter/material.dart';

// ── IVE Avatar V2 Design Tokens ───────────────────────────────────────────────

abstract final class IveAvatarTokens {
  // Brand colors
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color secondaryTeal = Color(0xFF03DAC6);
  static const Color backgroundDark = Color(0xFF0F0F1A);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color errorRed = Color(0xFFFF3D5A);

  // State colors
  static const Color idle = Color(0xFF6C63FF);
  static const Color listening = Color(0xFF4DA6FF);
  static const Color thinking = Color(0xFF00C6FF);
  static const Color analyzing = Color(0xFF9B8FFF);
  static const Color researching = Color(0xFF00E0FF);
  static const Color generating = Color(0xFFB47AFF);
  static const Color speaking = Color(0xFF7B5CF6);
  static const Color success = Color(0xFF00E875);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF3D5A);
  static const Color offline = Color(0xFF555577);
  static const Color disabled = Color(0xFF333355);
  static const Color attention = Color(0xFFFFD700);
  static const Color waitingForUser = Color(0xFF8080C0);

  // Ring
  static const double ringStrokeWidth = 2.5;
  static const double ringGapRatio = 0.055;

  // Sizes
  static const double sizeCompact = 40.0;
  static const double sizeSmall = 56.0;
  static const double sizeStandard = 72.0;
  static const double sizeLarge = 96.0;
  static const double sizeChat = 128.0;
  static const double sizeFull = 160.0;

  // Touch target
  static const double minTouchTarget = 48.0;

  // Border radius for card mode
  static const double cardRadius = 16.0;

  // Assistant button size
  static const double assistantButtonSize = 64.0;

  // Typography
  static const double labelFontSizeSmall = 10.0;
  static const double labelFontSizeMedium = 12.0;
  static const double labelFontSizeLarge = 14.0;

  // Animation
  static const Duration transitionDuration = Duration(milliseconds: 300);
  static const Duration stateChangeFade = Duration(milliseconds: 500);

  // Opacity
  static const double disabledOpacity = 0.38;
}
