import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../domain/recipe.dart';

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

final recipeSearchProvider = NotifierProvider<RecipeSearch, String>(
  RecipeSearch.new,
);

class RecipeSearch extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Recettes affichées : filtrées par la recherche en cours.
final visibleRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final query = normalizeForSearch(ref.watch(recipeSearchProvider).trim());
  return ref
      .watch(recipesProvider)
      .whenData(
        (recipes) => query.isEmpty
            ? recipes
            : recipes
                  .where((r) => normalizeForSearch(r.title).contains(query))
                  .toList(),
      );
});

enum RecipesView { list, grid }

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

  Future<void> toggle() async {
    state = state == RecipesView.grid ? RecipesView.list : RecipesView.grid;
    await ref.read(sharedPreferencesProvider).setString(_key, state.name);
  }
}
