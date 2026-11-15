import 'label.dart';
import 'planning.dart';
import 'recipe.dart';
import 'shopping.dart';
import 'shopping_from_recipes.dart';

/// Un nom et un nombre : une barre d'un graphique des statistiques.
typedef StatCount = ({String name, int count});

/// Les statistiques des recettes et du planning, calculées d'un coup.
class RecipeStats {
  const RecipeStats({
    required this.total,
    required this.favorites,
    required this.averageMinutes,
    required this.plannedLast30,
    required this.categories,
    required this.seasons,
    required this.statuses,
    required this.mostPlanned,
    required this.neverPlanned,
    required this.bestRated,
    required this.ingredients,
  });

  static const top = 10;

  final int total;
  final int favorites;

  /// Le temps total moyen des recettes qui en ont un ; `null` sinon.
  final int? averageMinutes;

  /// Les repas prévus ces 30 derniers jours (restes non comptés).
  final int plannedLast30;

  /// Par catégorie principale (ses sous-catégories comprises), la plus
  /// fournie d'abord ; `null` comme nom = sans catégorie.
  final List<({String? name, int count})> categories;

  /// Par saison, dans l'ordre du classement ; `null` = sans saison.
  final List<({String? name, int count})> seasons;

  /// Par statut (`null` = sans statut), dans l'ordre des statuts.
  final List<({RecipeStatus? status, int count})> statuses;

  /// Les recettes les plus souvent au planning (restes non comptés).
  final List<({Recipe recipe, int count})> mostPlanned;

  /// Les recettes jamais mises au planning.
  final int neverPlanned;

  /// Les mieux notées, la meilleure note d'abord.
  final List<Recipe> bestRated;

  /// Les ingrédients présents dans le plus de recettes (sel, poivre et
  /// autres basiques à part).
  final List<StatCount> ingredients;

  /// [links] : le classement de chaque recette ; [meals] : tout le planning.
  static RecipeStats compute({
    required List<Recipe> recipes,
    required List<Label> labels,
    required Map<String, Iterable<String>> links,
    required List<PlannedMeal> meals,
    required DateTime now,
  }) {
    final live = [
      for (final r in recipes)
        if (!r.isDeleted) r,
    ];
    final active = [
      for (final l in labels)
        if (!l.isDeleted) l,
    ]..sort((a, b) => a.position.compareTo(b.position));

    // Catégories : chaque sous-catégorie compte pour sa catégorie principale.
    final byId = {for (final l in active) l.id: l};
    String? rootOf(String id) {
      var label = byId[id];
      final seen = <String>{};
      while (label != null && label.parentId != null && seen.add(label.id)) {
        final parent = byId[label.parentId];
        if (parent == null) break;
        label = parent;
      }
      return label?.kind == LabelKind.category ? label!.id : null;
    }

    final roots = [
      for (final l in active)
        if (l.kind == LabelKind.category && rootOf(l.id) == l.id) l,
    ];
    final perRoot = <String, int>{};
    var noCategory = 0;
    final seasonLabels = [
      for (final l in active)
        if (l.kind == LabelKind.season) l,
    ];
    final perSeason = <String, int>{};
    var noSeason = 0;
    for (final r in live) {
      final ids = links[r.id] ?? const [];
      final recipeRoots = {for (final id in ids) ?rootOf(id)};
      if (recipeRoots.isEmpty) noCategory++;
      for (final root in recipeRoots) {
        perRoot[root] = (perRoot[root] ?? 0) + 1;
      }
      final recipeSeasons = {
        for (final id in ids)
          if (byId[id]?.kind == LabelKind.season) id,
      };
      if (recipeSeasons.isEmpty) noSeason++;
      for (final s in recipeSeasons) {
        perSeason[s] = (perSeason[s] ?? 0) + 1;
      }
    }
    final categories = [
      for (final l in roots)
        if ((perRoot[l.id] ?? 0) > 0) (name: l.name, count: perRoot[l.id]!),
    ]..sort((a, b) => b.count.compareTo(a.count));

    // Planning : les repas de recette, sans les restes.
    final cooked = [
      for (final m in meals)
        if (!m.isDeleted && m.isRecipe && !m.isLeftovers) m,
    ];
    final perRecipe = <String, int>{};
    for (final m in cooked) {
      perRecipe[m.recipeId!] = (perRecipe[m.recipeId!] ?? 0) + 1;
    }
    final liveById = {for (final r in live) r.id: r};
    final mostPlanned = [
      for (final e in perRecipe.entries)
        if (liveById[e.key] case final recipe?)
          (recipe: recipe, count: e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));
    final since = DateTime(now.year, now.month, now.day - 30);
    final today = DateTime(now.year, now.month, now.day);

    // Ingrédients : une fois par recette, au singulier, sans les basiques.
    final perIngredient = <String, int>{};
    final display = <String, String>{};
    for (final r in live) {
      final keys = <String>{};
      for (final line in r.ingredients) {
        if (line.isSection || line.isBlank || line.linkedRecipeId != null) {
          continue;
        }
        final name = line.name.trim();
        if (name.isEmpty || ShoppingFromRecipes.isBasic(name)) continue;
        final key = ShoppingProducts.keyOf(name);
        if (key.isEmpty || !keys.add(key)) continue;
        display.putIfAbsent(key, () => _capitalize(name));
      }
      for (final key in keys) {
        perIngredient[key] = (perIngredient[key] ?? 0) + 1;
      }
    }
    final ingredients = [
      for (final e in perIngredient.entries)
        if (e.value > 1) (name: display[e.key]!, count: e.value),
    ]..sort((a, b) => b.count.compareTo(a.count));

    final timed = [
      for (final r in live)
        if (r.totalMinutes case final m? when m > 0) m,
    ];
    final rated = [
      for (final r in live)
        if ((r.rating ?? 0) > 0) r,
    ]..sort((a, b) => b.rating!.compareTo(a.rating!));

    return RecipeStats(
      total: live.length,
      favorites: live.where((r) => r.isFavorite).length,
      averageMinutes: timed.isEmpty
          ? null
          : (timed.reduce((a, b) => a + b) / timed.length).round(),
      plannedLast30: cooked
          .where((m) => !m.day.isBefore(since) && !m.day.isAfter(today))
          .length,
      categories: [
        ...categories.take(top),
        if (noCategory > 0) (name: null, count: noCategory),
      ],
      seasons: [
        for (final l in seasonLabels)
          if ((perSeason[l.id] ?? 0) > 0)
            (name: l.name, count: perSeason[l.id]!),
        if (noSeason > 0) (name: null, count: noSeason),
      ],
      statuses: [
        for (final s in [...RecipeStatus.values, null])
          if (live.where((r) => r.status == s).length case final n when n > 0)
            (status: s, count: n),
      ],
      mostPlanned: mostPlanned.take(top).toList(),
      neverPlanned: live.where((r) => !perRecipe.containsKey(r.id)).length,
      bestRated: rated.take(top).toList(),
      ingredients: ingredients.take(top).toList(),
    );
  }

  static String _capitalize(String name) =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}
