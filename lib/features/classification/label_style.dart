import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Les icônes proposées pour un élément de classement, par clé enregistrée.
const labelIcons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'tapas': Icons.tapas,
  'cake': Icons.cake,
  'cookie': Icons.cookie,
  'local_cafe': Icons.local_cafe,
  'local_bar': Icons.local_bar,
  'wine_bar': Icons.wine_bar,
  'bakery_dining': Icons.bakery_dining,
  'breakfast_dining': Icons.breakfast_dining,
  'lunch_dining': Icons.lunch_dining,
  'dinner_dining': Icons.dinner_dining,
  'ramen_dining': Icons.ramen_dining,
  'rice_bowl': Icons.rice_bowl,
  'soup_kitchen': Icons.soup_kitchen,
  'set_meal': Icons.set_meal,
  'egg': Icons.egg_alt,
  'icecream': Icons.icecream,
  'local_pizza': Icons.local_pizza,
  'water_drop': Icons.water_drop,
  'blender': Icons.blender,
  'eco': Icons.eco,
  'local_florist': Icons.local_florist,
  'celebration': Icons.celebration,
  'ac_unit': Icons.ac_unit,
  'wb_sunny': Icons.wb_sunny,
  'favorite': Icons.favorite,
  'star': Icons.star,
};

/// L'icône d'un élément, ou [fallback] s'il n'en a pas choisi.
IconData labelIconData(String key, IconData fallback) =>
    labelIcons[key] ?? fallback;

/// Les couleurs proposées : toujours des couleurs du thème (clair et sombre).
const labelColorKeys = ['primary', 'teal', 'caramel', 'butter'];

Color? labelColor(ColorScheme scheme, String key) => switch (key) {
  'primary' => scheme.primary,
  'teal' => scheme.secondary,
  'caramel' => scheme.tertiary,
  'butter' => scheme.tertiaryContainer,
  _ => null,
};

String labelColorName(AppLocalizations l10n, String key) => switch (key) {
  'primary' => l10n.colorPrimary,
  'teal' => l10n.colorTeal,
  'caramel' => l10n.colorCaramel,
  'butter' => l10n.colorButter,
  _ => l10n.noColor,
};
