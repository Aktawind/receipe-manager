import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../classification/labels_providers.dart';

/// Recettes hors corbeille, triées par titre (sans tenir compte des accents).
final recipesProvider = StreamProvider<List<Recipe>>((ref) {
  return ref
      .watch(recipeRepositoryProvider)
      .watchRecipes()
      .map(
        (recipes) => [...recipes]
          ..sort(
            (a, b) =>
                normalizeForSearch(a.title)
                    .compareTo(normalizeForSearch(b.title)),
          ),
      );
});

final recipeProvider = StreamProvider.family<Recipe?, String>(
  (ref, id) => ref.watch(recipeRepositoryProvider).watchRecipe(id),
);

final trashProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchTrash(),
);

/// Le classement de chaque recette : recette → (élément → rang).
final recipeLabelLinksProvider = StreamProvider<Map<String, Map<String, int>>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchLabelLinks(),
);

final recipeSearchProvider = NotifierProvider<RecipeSearch, String>(
  RecipeSearch.new,
);

class RecipeSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Accès rapides au-dessus de la liste.
enum QuickFilter {
  all,
  favorites,

  /// Les dernières fiches ouvertes, la plus récente d'abord.
  recent,

  /// Les dernières recettes ajoutées, la plus récente d'abord.
  added,
}

enum RecipeSort {
  title,
  added,
  viewed,

  /// L'ordre choisi dans une collection (quand une seule est filtrée).
  manual,
}

/// Ce qui restreint la liste des recettes : accès rapide, classement choisi
/// et tri. La recherche par titre est à part.
class RecipeFilter {
  const RecipeFilter({
    this.quick = QuickFilter.all,
    this.labelIds = const {},
    this.sort = RecipeSort.title,
  });

  final QuickFilter quick;
  final Set<String> labelIds;
  final RecipeSort sort;

  bool get isActive => quick != QuickFilter.all || labelIds.isNotEmpty;

  RecipeFilter copyWith({
    QuickFilter? quick,
    Set<String>? labelIds,
    RecipeSort? sort,
  }) => RecipeFilter(
    quick: quick ?? this.quick,
    labelIds: labelIds ?? this.labelIds,
    sort: sort ?? this.sort,
  );
}

final recipeFilterProvider =
    NotifierProvider<RecipeFilterController, RecipeFilter>(
      RecipeFilterController.new,
    );

class RecipeFilterController extends Notifier<RecipeFilter> {
  static const _sortKey = 'recipes_sort';

  @override
  RecipeFilter build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_sortKey);
    final sort = RecipeSort.values.asNameMap()[stored];
    return RecipeFilter(
      sort: sort == null || sort == RecipeSort.manual ? RecipeSort.title : sort,
    );
  }

  void setQuick(QuickFilter quick) => state = state.copyWith(quick: quick);

  void setLabels(Set<String> ids) => state = state.copyWith(labelIds: ids);

  void toggleLabel(String id) {
    final next = {...state.labelIds};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(labelIds: next);
  }

  Future<void> setSort(RecipeSort sort) async {
    state = state.copyWith(sort: sort);
    if (sort != RecipeSort.manual) {
      await ref.read(sharedPreferencesProvider).setString(_sortKey, sort.name);
    }
  }

  void clear() => state = RecipeFilter(sort: state.sort);
}

/// Le seul élément « collection » filtré, s'il n'y en a qu'un : ses recettes
/// peuvent alors suivre l'ordre choisi.
final singleCollectionFilterProvider = Provider<Label?>((ref) {
  final filter = ref.watch(recipeFilterProvider);
  final labels = ref.watch(labelsProvider).value ?? const <Label>[];
  final selected = [
    for (final l in labels)
      if (filter.labelIds.contains(l.id)) l,
  ];
  return selected.length == 1 && selected.single.kind == LabelKind.collection
      ? selected.single
      : null;
});

/// Les identifiants à retenir pour un élément choisi : lui-même et, pour une
/// catégorie, toutes ses sous-catégories.
Set<String> _expanded(Iterable<Label> selected, List<Label> all) {
  final ids = {for (final l in selected) l.id};
  var grew = true;
  while (grew) {
    grew = false;
    for (final label in all) {
      if (label.parentId != null &&
          ids.contains(label.parentId) &&
          ids.add(label.id)) {
        grew = true;
      }
    }
  }
  return ids;
}

/// Recettes affichées : recherche, accès rapide, classement et tri appliqués.
final visibleRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final query = normalizeForSearch(ref.watch(recipeSearchProvider).trim());
  final filter = ref.watch(recipeFilterProvider);
  final all = ref.watch(labelsProvider).value ?? const <Label>[];
  final links = ref.watch(recipeLabelLinksProvider).value ?? const {};
  final collection = ref.watch(singleCollectionFilterProvider);

  return ref.watch(recipesProvider).whenData((recipes) {
    var shown = recipes.where((r) {
      if (query.isNotEmpty && !normalizeForSearch(r.title).contains(query)) {
        return false;
      }
      if (filter.quick == QuickFilter.favorites && !r.isFavorite) return false;
      if (filter.quick == QuickFilter.recent && r.lastViewedAt == null) {
        return false;
      }
      return true;
    }).toList();

    // Même famille : l'un ou l'autre ; familles différentes : les deux.
    final byKind = <LabelKind, List<Label>>{};
    for (final label in all) {
      if (filter.labelIds.contains(label.id)) {
        (byKind[label.kind] ??= []).add(label);
      }
    }
    for (final selected in byKind.values) {
      final wanted = _expanded(selected, all);
      shown = shown
          .where((r) => (links[r.id]?.keys ?? const []).any(wanted.contains))
          .toList();
    }

    int byTitle(Recipe a, Recipe b) =>
        normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title));
    switch (filter.quick) {
      case QuickFilter.recent:
        shown.sort((a, b) => b.lastViewedAt!.compareTo(a.lastViewedAt!));
        shown = shown.take(50).toList();
      case QuickFilter.added:
        shown.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        shown = shown.take(50).toList();
      case QuickFilter.all || QuickFilter.favorites:
        switch (filter.sort) {
          case RecipeSort.title:
            break; // déjà trié par titre
          case RecipeSort.added:
            shown.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          case RecipeSort.viewed:
            shown.sort((a, b) {
              final x = a.lastViewedAt, y = b.lastViewedAt;
              if (x == null && y == null) return byTitle(a, b);
              if (x == null) return 1;
              if (y == null) return -1;
              return y.compareTo(x);
            });
          case RecipeSort.manual:
            if (collection != null) {
              int rank(Recipe r) => links[r.id]?[collection.id] ?? 1 << 30;
              shown.sort((a, b) {
                final byRank = rank(a).compareTo(rank(b));
                return byRank != 0 ? byRank : byTitle(a, b);
              });
            }
        }
    }
    return shown;
  });
});

enum RecipesView { list, grid, cards }

final recipesViewProvider =
    NotifierProvider<RecipesViewController, RecipesView>(
      RecipesViewController.new,
    );

class RecipesViewController extends Notifier<RecipesView> {
  static const _key = 'recipes_view';

  @override
  RecipesView build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return RecipesView.values.asNameMap()[stored] ?? RecipesView.grid;
  }

  Future<void> set(RecipesView view) async {
    state = view;
    await ref.read(sharedPreferencesProvider).setString(_key, view.name);
  }
}

/// Afficher ou non les photos dans la liste des recettes.
final showPhotosProvider = NotifierProvider<ShowPhotosController, bool>(
  ShowPhotosController.new,
);

class ShowPhotosController extends Notifier<bool> {
  static const _key = 'recipes_show_photos';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}
