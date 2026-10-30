import 'label.dart';

/// Le classement fourni au départ. Les identifiants sont déterministes : ces
/// éléments sont retrouvés tels quels après une réinstallation ou un import.
abstract final class DefaultLabels {
  static const _categories = <(String, String)>[
    ('Apéritifs et entrées', 'tapas'),
    ('Plats', 'restaurant'),
    ('Desserts', 'cake'),
    ('Goûters', 'local_cafe'),
    ('Boissons', 'local_bar'),
    ('Pains', 'bakery_dining'),
    ('Sauces', 'water_drop'),
    ('Préparations', 'blender'),
  ];

  static const _cuisines = [
    'Française',
    'Italienne',
    'Asiatique',
    'Méditerranéenne',
    'Orientale',
    'Mexicaine',
    'Américaine',
  ];

  static const seasonNames = ['Printemps', 'Été', 'Automne', 'Hiver'];
  static const allSeasons = 'Toute saison';

  static List<Label> build(DateTime now) {
    Label make(LabelKind kind, String name, int position, [String icon = '']) =>
        Label(
          id: Label.idFor(kind, name),
          kind: kind,
          name: name,
          icon: icon,
          position: position,
          createdAt: now,
          updatedAt: now,
        );
    return [
      for (final (i, c) in _categories.indexed)
        make(LabelKind.category, c.$1, i, c.$2),
      for (final (i, n) in _cuisines.indexed) make(LabelKind.cuisine, n, i),
      for (final (i, n) in [...seasonNames, allSeasons].indexed)
        make(LabelKind.season, n, i),
    ];
  }
}
