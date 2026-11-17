import 'package:flutter/cupertino.dart' show CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta: sala a oscuras, texto crema y ámbar de proyector para lo especial.
abstract final class AppColors {
  static const bg = Color(0xFF0F0E0D);
  static const surface = Color(0xFF191715);
  static const surfaceHigh = Color(0xFF24211E);
  static const surfaceHighest = Color(0xFF302C28);
  static const outline = Color(0xFF3D3833);
  static const cream = Color(0xFFF0E9DD);
  static const muted = Color(0xFFA79F93);
  static const amber = Color(0xFFF5B841);
  static const onAmber = Color(0xFF261A00);
  static const amberContainer = Color(0xFF4A3608);
  static const ok = Color(0xFF7FC98A);
  static const error = Color(0xFFFF8A7A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.amber, brightness: Brightness.dark).copyWith(
    primary: AppColors.amber,
    onPrimary: AppColors.onAmber,
    primaryContainer: AppColors.amberContainer,
    onPrimaryContainer: const Color(0xFFFFE2A6),
    secondary: AppColors.amber,
    onSecondary: AppColors.onAmber,
    secondaryContainer: AppColors.surfaceHighest,
    onSecondaryContainer: AppColors.cream,
    surface: AppColors.bg,
    onSurface: AppColors.cream,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    outline: AppColors.outline,
    outlineVariant: const Color(0xFF2A2623),
    error: AppColors.error,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: AppColors.bg);
  final text = base.textTheme.apply(bodyColor: AppColors.cream, displayColor: AppColors.cream);
  return base.copyWith(
    // Los componentes de iOS (barras, interruptores, hojas de acción) en el mismo tono.
    cupertinoOverrideTheme: const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.amber,
      barBackgroundColor: Color(0xE6191715),
      scaffoldBackgroundColor: AppColors.bg,
    ),
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.amberContainer,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.cream : AppColors.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceHigh,
      selectedColor: AppColors.amber,
      checkmarkColor: AppColors.onAmber,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      secondaryLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onAmber),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF2A2623), thickness: 1, space: 1),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHighest,
      contentTextStyle: TextStyle(color: AppColors.cream),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.amber,
      linearTrackColor: AppColors.surfaceHigh,
    ),
  );
}
