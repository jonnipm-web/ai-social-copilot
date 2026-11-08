import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_motion.dart';
import 'app_tokens.dart';

/// InsightValues Dark Premium theme. Every value comes from [AppColors],
/// [AppSpace], [AppRadius] and [AppType] in app_tokens.dart.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: AppColors.accentSoft,
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.info,
      onSecondary: AppColors.ground,
      secondaryContainer: AppColors.infoSoft,
      onSecondaryContainer: AppColors.info,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ground,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.ground,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceRaised,
      surfaceContainerHighest: AppColors.surfaceRaised,
      outline: AppColors.controlBorder,
      outlineVariant: AppColors.line,
      error: AppColors.negative,
      onError: AppColors.ground,
      errorContainer: AppColors.negativeSoft,
      onErrorContainer: AppColors.negative,
    );

    final inter = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = inter
        .copyWith(
          displaySmall: inter.displaySmall?.copyWith(
              fontSize: AppType.display,
              height: 38 / 32,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4),
          headlineSmall: inter.headlineSmall?.copyWith(
              fontSize: AppType.title,
              height: 30 / 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2),
          titleLarge: inter.titleLarge?.copyWith(
              fontSize: AppType.heading,
              height: 24 / 18,
              fontWeight: FontWeight.w600),
          titleMedium: inter.titleMedium?.copyWith(
              fontSize: AppType.body, fontWeight: FontWeight.w600),
          bodyLarge: inter.bodyLarge?.copyWith(
              fontSize: AppType.body, height: 22 / 15),
          bodyMedium: inter.bodyMedium?.copyWith(
              fontSize: 14, height: 20 / 14),
          bodySmall: inter.bodySmall?.copyWith(
              fontSize: AppType.label, color: AppColors.inkMuted),
          labelLarge: inter.labelLarge?.copyWith(
              fontSize: 14, fontWeight: FontWeight.w600),
          labelMedium: inter.labelMedium?.copyWith(
              fontSize: AppType.label, fontWeight: FontWeight.w500),
          labelSmall: inter.labelSmall?.copyWith(
              fontSize: AppType.caption,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: AppColors.inkSubtle),
        )
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md));
    final buttonText =
        GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      colorScheme: scheme,
      // Transparent: IvBackground (app.dart) paints the ground + light fades
      // behind every route.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: kIvPageTransitionsTheme,
      canvasColor: AppColors.ground,
      dividerColor: AppColors.line,
      textTheme: textTheme,
      dividerTheme: const DividerThemeData(
          color: AppColors.line, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.inkMuted, size: 20),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: AppType.heading,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        iconTheme: const IconThemeData(color: AppColors.inkMuted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceRaised,
        hintStyle: const TextStyle(color: AppColors.inkSubtle),
        labelStyle: const TextStyle(color: AppColors.inkMuted),
        border: inputBorder(AppColors.line),
        enabledBorder: inputBorder(AppColors.line),
        focusedBorder: inputBorder(AppColors.accent, 1.5),
        errorBorder: inputBorder(AppColors.negative),
        focusedErrorBorder: inputBorder(AppColors.negative, 1.5),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s4, vertical: AppSpace.s3 + 2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.surfaceRaised,
          disabledForegroundColor: AppColors.inkSubtle,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size(64, 44),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.controlBorder),
          minimumSize: const Size(64, 44),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: buttonText,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceRaised,
        selectedColor: AppColors.accentSoft,
        side: const BorderSide(color: AppColors.line),
        labelStyle: GoogleFonts.inter(
            fontSize: AppType.label,
            fontWeight: FontWeight.w500,
            color: AppColors.ink),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        textColor: AppColors.ink,
        selectedColor: AppColors.accent,
        selectedTileColor: AppColors.accentSoft,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.inkSubtle)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: s.contains(WidgetState.selected)
                    ? AppColors.accent
                    : AppColors.inkSubtle)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.inkSubtle,
        elevation: 0,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.ink,
        unselectedLabelColor: AppColors.inkSubtle,
        indicatorColor: AppColors.accent,
        dividerColor: AppColors.line,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.line)),
      ),
      // Default M3 sheets cap at 640px, which reads as a sliver on desktop.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints(maxWidth: 880),
        showDragHandle: false,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: TextStyle(color: AppColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.line,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.onAccent
                : AppColors.inkMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.surfaceRaised),
      ),
    );
  }
}
