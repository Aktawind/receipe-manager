import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Thèmes clair et sombre construits à partir de [AppPalette].
abstract final class AppTheme {
  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(seedColor: AppPalette.teal).copyWith(
        primary: AppPalette.deepTeal,
        onPrimary: Colors.white,
        primaryContainer: AppPalette.teal,
        onPrimaryContainer: Colors.white,
        secondary: AppPalette.teal,
        onSecondary: Colors.white,
        tertiary: AppPalette.caramel,
        onTertiary: AppPalette.ink,
        tertiaryContainer: AppPalette.butter,
        onTertiaryContainer: AppPalette.ink,
        surface: AppPalette.mint,
        onSurface: AppPalette.ink,
      );

  static final ColorScheme darkScheme =
      ColorScheme.fromSeed(
        seedColor: AppPalette.teal,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppPalette.lightTeal,
        onPrimary: AppPalette.nightTeal,
        primaryContainer: AppPalette.teal,
        onPrimaryContainer: Colors.white,
        secondary: AppPalette.lightTeal,
        onSecondary: AppPalette.nightTeal,
        tertiary: AppPalette.caramel,
        onTertiary: AppPalette.ink,
        tertiaryContainer: AppPalette.butter,
        onTertiaryContainer: AppPalette.ink,
        surface: AppPalette.nightTeal,
        onSurface: AppPalette.mint,
      );

  static ThemeData get light => _build(lightScheme);
  static ThemeData get dark => _build(darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.tertiaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.tertiaryContainer,
      ),
    );
  }
}
