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
      // The selected tab sits on a butter-yellow indicator in both themes, so
      // its icon must use the dark "on" color, not the theme's default.
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.tertiaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onTertiaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.tertiaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onTertiaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
