import 'package:flutter/material.dart';

/// InsightValues Dark Premium — design tokens.
///
/// Single source of truth for colour, type, spacing and radius across
/// Core, Quant and Impact. Screens must use these (or Theme.of(context))
/// instead of hardcoded `Color(0x...)` / `Colors.*` values.
///
/// Rules:
/// - `accent` is the ONLY brand colour (primary action, active item, focus).
/// - `positive` / `negative` / `warning` mean data (up, down, risk) — never decoration.
/// - `gold` is reserved for paid plans / premium seals.
/// - Layers are separated by surfaces and 1px `line` borders, not shadows or gradients.
class AppColors {
  AppColors._();

  // Surfaces
  static const ground = Color(0xFF0A0C0F);
  static const surface = Color(0xFF111418);
  static const surfaceRaised = Color(0xFF171B20);
  static const line = Color(0xFF252A31);
  static const controlBorder = Color(0xFF606A77);

  // Text
  static const ink = Color(0xFFECEEF1);
  static const inkMuted = Color(0xFF9BA3AE);
  static const inkSubtle = Color(0xFF7E8794);

  // Brand
  static const accent = Color(0xFF2DB3A0);
  static const accentSoft = Color(0xFF0F2A27);
  static const onAccent = Color(0xFF04110F);

  // Secondary data hue (charts, secondary highlights)
  static const info = Color(0xFF7AA7D9);
  static const infoSoft = Color(0xFF14202E);

  // Premium
  static const gold = Color(0xFFC8A24E);
  static const goldSoft = Color(0xFF2A2413);

  // Data / status
  static const positive = Color(0xFF45CB86);
  static const positiveSoft = Color(0xFF0F2A1D);
  static const negative = Color(0xFFEF5F5C);
  static const negativeSoft = Color(0xFF2E1414);
  static const warning = Color(0xFFE3A33B);
  static const warningSoft = Color(0xFF2B2110);
}

/// 4px spacing scale.
class AppSpace {
  AppSpace._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
}

/// Three radii only.
class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
}

/// Type scale (Inter). Use with tabular figures for any number.
class AppType {
  AppType._();
  static const double display = 32;
  static const double title = 24;
  static const double heading = 18;
  static const double body = 15;
  static const double label = 13;
  static const double caption = 12;

  static const tabular = [FontFeature.tabularFigures()];
}

/// Card surface: a faint top-left light that fades into [AppColors.surface].
/// Used by every hand-built card decoration so surfaces read as one system.
const kIvSurfaceGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF161B21), AppColors.surface],
);
