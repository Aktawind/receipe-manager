import 'dart:math';

import 'meal_planner.dart';
import 'recipe.dart';

/// Les rubriques de l'écran d'accueil, dans l'ordre de départ.
enum HomeSection {
  today,
  shortcuts,
  favorites,
  recent,
  seasonal,
  toTest;

  static HomeSection? fromName(String name) => values.asNameMap()[name];
}

/// L'ordre des rubriques de l'accueil et celles qui sont affichées.
typedef HomeLayout = List<({HomeSection section, bool shown})>;

/// Ce que l'accueil montre, calculé à partir des recettes.
abstract final class HomePicks {
  static const limit = 12;

  static HomeLayout defaultLayout() => [
    for (final s in HomeSection.values) (section: s, shown: true),
  ];

  /// « today:1,favorites:0… » → l'ordre et l'affichage ; une rubrique
  /// inconnue est ignorée, une rubrique absente (nouvelle) va à la fin.
  static HomeLayout parseLayout(List<String>? stored) {
    if (stored == null) return defaultLayout();
    final layout = <({HomeSection section, bool shown})>[];
    for (final entry in stored) {
      final [name, ...rest] = entry.split(':');
      final section = HomeSection.fromName(name);
      if (section == null || layout.any((e) => e.section == section)) continue;
      layout.add((section: section, shown: rest.firstOrNull != '0'));
    }
    for (final s in HomeSection.values) {
      if (!layout.any((e) => e.section == s)) {
        layout.add((section: s, shown: true));
      }
    }
    return layout;
  }

  static List<String> encodeLayout(HomeLayout layout) => [
    for (final e in layout) '${e.section.name}:${e.shown ? 1 : 0}',
  ];

  /// Les favoris, par titre.
  static List<Recipe> favorites(List<Recipe> recipes) => [
    for (final r in recipes)
      if (r.isFavorite && !r.isDeleted) r,
  ].take(limit).toList();

  /// Les dernières consultées, la plus récente d'abord.
  static List<Recipe> recent(List<Recipe> recipes) =>
      ([
            for (final r in recipes)
              if (r.lastViewedAt != null && !r.isDeleted) r,
          ]..sort((a, b) => b.lastViewedAt!.compareTo(a.lastViewedAt!)))
          .take(limit)
          .toList();

  /// Des recettes de saison (ou sans saison), tirées au sort une fois par
  /// jour : les mêmes toute la journée. [labels] : le classement de chaque
  /// recette.
  static List<Recipe> seasonal(
    List<Recipe> recipes,
    Map<String, Iterable<String>> labels, {
    required DateTime day,
  }) {
    final season = Season.of(day);
    final fitting = [
      for (final r in recipes)
        if (!r.isDeleted &&
            MealPlanner.fitsSeason(labels[r.id] ?? const [], season))
          r,
    ]..sort((a, b) => a.id.compareTo(b.id));
    final seed = day.year * 1000 + day.month * 40 + day.day;
    fitting.shuffle(Random(seed));
    return fitting.take(limit).toList();
  }

  /// Les recettes encore à tester (ou à retester).
  static List<Recipe> toTest(List<Recipe> recipes) => [
    for (final r in recipes)
      if (!r.isDeleted &&
          (r.status == RecipeStatus.toTest ||
              r.status == RecipeStatus.toRetest))
        r,
  ].take(limit).toList();
}
