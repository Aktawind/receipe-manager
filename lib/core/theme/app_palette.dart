import 'package:flutter/material.dart';

/// Palette de base de l'application (voir docs/design/palette.md).
///
/// Ne pas utiliser ces couleurs directement dans les widgets : passer par
/// `Theme.of(context).colorScheme` pour que le thème sombre fonctionne.
abstract final class AppPalette {
  /// Vert profond : couleur principale (thème clair).
  static const deepTeal = Color(0xFF1B524F);

  /// Vert canard : couleur secondaire, conteneurs.
  static const teal = Color(0xFF236C68);

  /// Menthe très claire : fond (thème clair).
  static const mint = Color(0xFFEBF7F4);

  /// Jaune doux : mises en avant (favoris, astuces).
  static const butter = Color(0xFFFDE9A0);

  /// Orange caramel : accent (actions, minuteurs).
  static const caramel = Color(0xFFD4935A);

  // Dérivés pour le thème sombre.
  static const nightTeal = Color(0xFF0F2A28);
  static const nightSurface = Color(0xFF15332F);
  static const lightTeal = Color(0xFF8FD1C9);
  static const ink = Color(0xFF14211F);
}
