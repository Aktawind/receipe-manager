import 'package:flutter/material.dart';

/// Palette de base de l'application (voir docs/design/palette.md) : bleu
/// canard et pêche, dans des tons doux.
///
/// Ne pas utiliser ces couleurs directement dans les widgets : passer par
/// `Theme.of(context).colorScheme` pour que le thème sombre fonctionne.
abstract final class AppPalette {
  /// Bleu canard profond : couleur principale (thème clair).
  static const deepTeal = Color(0xFF0E5A62);

  /// Bleu canard : couleur secondaire, conteneurs.
  static const teal = Color(0xFF1C7880);

  /// Blanc cassé chaud : fond (thème clair).
  static const cream = Color(0xFFFAF6F1);

  /// Pêche clair : mises en avant (onglet choisi, astuces).
  static const lightPeach = Color(0xFFFFDDD0);

  /// Pêche : accent (bouton d'action, minuteurs).
  static const peach = Color(0xFFF2A285);

  // Dérivés pour le thème sombre.
  static const nightTeal = Color(0xFF0D2427);
  static const nightSurface = Color(0xFF14323A);
  static const lightTeal = Color(0xFF8ED0D3);
  static const ink = Color(0xFF132326);
}
