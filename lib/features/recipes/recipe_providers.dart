import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_filter.dart';
import '../../domain/recipe_search.dart';
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

  void setStatuses(Set<RecipeStatus> statuses) =>
      state = state.copyWith(statuses: statuses);

  void setTimes(TimeLimits times) => state = state.copyWith(times: times);

  void setEquipment(Set<String> ids) =>
      state = state.copyWith(equipmentIds: ids);

  void setIngredients(IngredientCriteria criteria) =>
      state = state.copyWith(ingredients: criteria);

  /// Remplace le choix d'une famille ([ofKind] : ses éléments) par [chosen].
  void replaceLabels(Set<String> ofKind, Iterable<String> chosen) {
    state = state.copyWith(
      labelIds: {
        for (final id in state.labelIds)
          if (!ofKind.contains(id)) id,
        ...chosen,
      },
    );
  }

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

  /// Remplace tout le filtre (recherche enregistrée).
  void apply(RecipeFilter filter) => state = filter;
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

/// Toutes les recettes avec leurs ingrédients, étapes et matériel : de quoi
/// chercher dans le texte et par ingrédient. Lues seulement quand on en a
/// besoin, puis relues quand les recettes changent.
final recipeDetailsProvider = StreamProvider<List<Recipe>>((ref) async* {
  final repository = ref.watch(recipeRepositoryProvider);
  final db = ref.watch(appServicesProvider).database;
  yield await repository.getAllWithDetails();
  final changes = db.tableUpdates(
    TableUpdateQuery.onAllTables([
      db.recipes,
      db.ingredients,
      db.recipeSteps,
      db.recipeEquipment,
    ]),
  );
  await for (final _ in changes) {
    // Laisse finir une série d'écritures (une recette = plusieurs tables).
    await Future<void>.delayed(const Duration(milliseconds: 300));
    yield await repository.getAllWithDetails();
  }
});

/// L'index de recherche (titres, ingrédients, préparation, notes).
final searchIndexProvider = Provider<AsyncValue<RecipeSearchIndex>>(
  (ref) => ref.watch(recipeDetailsProvider).whenData(RecipeSearchIndex.new),
);

/// Recettes affichées : recherche, accès rapide, classement, statut, durées,
/// matériel et ingrédients appliqués, puis le tri.
final visibleRecipesProvider = Provider<AsyncValue<List<Recipe>>>((ref) {
  final query = ref.watch(recipeSearchProvider).trim();
  final filter = ref.watch(recipeFilterProvider);

  // Les recettes lues en détail ne sont demandées que si la recherche de texte
  // ou un filtre d'ingrédients ou de matériel en a besoin.
  final details = query.isEmpty && !filter.needsDetails
      ? null
      : ref.watch(recipeDetailsProvider);
  if (details != null && !details.hasValue) {
    return details.hasError
        ? AsyncError(details.error!, details.stackTrace!)
        : const AsyncLoading();
  }
  final byId = {
    if (details != null)
      for (final recipe in details.requireValue) recipe.id: recipe,
  };

  // Classement par pertinence : id → rang (l'index est gardé entre deux frappes).
  final index = query.isEmpty ? null : ref.watch(searchIndexProvider).value;
  final relevance = <String, int>{
    if (index != null)
      for (final (rank, hit) in index.search(query).indexed) hit.recipeId: rank,
  };
  final all = ref.watch(labelsProvider).value ?? const <Label>[];
  final links = ref.watch(recipeLabelLinksProvider).value ?? const {};
  final collection = ref.watch(singleCollectionFilterProvider);

  return ref
      .watch(recipesProvider)
      .whenData(
        (recipes) => filter.apply(
          recipes,
          relevance: query.isEmpty ? null : relevance,
          details: byId,
          labels: all,
          links: links,
          collection: collection,
        ),
      );
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

/// Les dernières recherches, la plus récente d'abord (gardées sur l'appareil).
final searchHistoryProvider = NotifierProvider<SearchHistory, List<String>>(
  SearchHistory.new,
);

class SearchHistory extends Notifier<List<String>> {
  static const _key = 'search_history';
  static const maxEntries = 10;

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  Future<void> add(String query) async {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 2) return;
    final key = normalizeForSearch(clean);
    final next = [
      clean,
      for (final old in state)
        if (normalizeForSearch(old) != key) old,
    ].take(maxEntries).toList();
    await _save(next);
  }

  Future<void> remove(String query) => _save([
    for (final old in state)
      if (old != query) old,
  ]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(_key, next);
  }
}
