import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/theme/app_theme.dart';

/// Rapport de contraste WCAG entre deux couleurs.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // WCAG AA : 4,5 pour le texte courant.
  const minText = 4.5;

  for (final (name, scheme) in [
    ('clair', AppTheme.lightScheme),
    ('sombre', AppTheme.darkScheme),
  ]) {
    group('thème $name', () {
      final pairs = {
        'primary': (scheme.primary, scheme.onPrimary),
        'primaryContainer': (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
        'secondary': (scheme.secondary, scheme.onSecondary),
        'tertiary': (scheme.tertiary, scheme.onTertiary),
        'tertiaryContainer': (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
        'surface': (scheme.surface, scheme.onSurface),
      };
      pairs.forEach((role, colors) {
        test('$role est lisible', () {
          expect(contrast(colors.$1, colors.$2), greaterThanOrEqualTo(minText));
        });
      });
    });
  }
}
