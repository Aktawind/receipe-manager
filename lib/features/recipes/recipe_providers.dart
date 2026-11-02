import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart' show ValueGetter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/ingredient_match.dart';
import '../../domain/recipe.dart';
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

/// Toutes les recettes, ou seulement les favorites.
enum QuickFilter { all, favorites }

enum RecipeSort {
  title,
  added,
  viewed,

  /// Les plus courtes d'abord (durée totale) ; sans durée à la fin.
  duration,

  /// Les mieux notées d'abord ; sans note à la fin.
  rating,

  /// À tester, à retester, à améliorer, validée, sans statut.
  status,

  /// L'ordre choisi dans une collection (quand une seule est filtrée).
  manual,
}

/// Durées maximales, en minutes ; `null` = peu importe. Une recette dont la
/// durée n'est pas renseignée ne répond pas à une limite.
class TimeLimits {
  const TimeLimits({this.total, this.prep, this.cook});

  final int? total;
  final int? prep;
  final int? cook;

  bool get isActive => total != null || prep != null || cook != null;

  int get count => [total, prep, cook].nonNulls.length;

  bool accepts(Recipe r) {
    bool ok(int? limit, int? value) =>
        limit == null || (value != null && value <= limit);
    return ok(total, r.totalMinutes) &&
        ok(prep, r.prepMinutes) &&
        ok(cook, r.cookMinutes);
  }

  TimeLimits copyWith({
    ValueGetter<int?>? total,
    ValueGetter<int?>? prep,
    ValueGetter<int?>? cook,
  }) => TimeLimits(
    total: total != null ? total() : this.total,
    prep: prep != null ? prep() : this.prep,
    cook: cook != null ? cook() : this.cook,
  );
}

/// La recherche par ingrédients : ceux que la recette doit tous avoir, ceux dont
/// un suffit, ceux qu'elle ne doit pas avoir, et « ce que j'ai sous la main ».
class IngredientCriteria {
  const IngredientCriteria({
    this.all = const [],
    this.any = const [],
    this.none = const [],
    this.onHand = false,
    this.maxMissing = 0,
  });

  final List<String> all;
  final List<String> any;
  final List<String> none;

  /// Ne garder que les recettes faisables avec les ingrédients de la réserve.
  final bool onHand;

  /// Nombre d'ingrédients qu'on accepte de ne pas avoir (avec [onHand]).
  final int maxMissing;

  bool get isActive =>
      all.isNotEmpty || any.isNotEmpty || none.isNotEmpty || onHand;

  int get count => all.length + any.length + none.length + (onHand ? 1 : 0);

  IngredientCriteria copyWith({
    List<String>? all,
    List<String>? any,
    List<String>? none,
    bool? onHand,
    int? maxMissing,
  }) => IngredientCriteria(
    all: all ?? this.all,
    any: any ?? this.any,
    none: none ?? this.none,
    onHand: onHand ?? this.onHand,
    maxMissing: maxMissing ?? this.maxMissing,
  );
}

/// Ce qui restreint la liste des recettes : accès rapide, classement choisi,
/// statut, durées, matériel, ingrédients, et le tri. La recherche de texte est à
/// part.
class RecipeFilter {
  const RecipeFilter({
    this.quick = QuickFilter.all,
    this.labelIds = const {},
    this.statuses = const {},
    this.times = const TimeLimits(),
    this.equipmentIds = const {},
    this.ingredients = const IngredientCriteria(),
    this.sort = RecipeSort.title,
  });

  final QuickFilter quick;
  final Set<String> labelIds;

  /// Statuts retenus (l'un ou l'autre) ; vide = tous.
  final Set<RecipeStatus> statuses;
  final TimeLimits times;

  /// Le matériel choisi : seules restent les recettes qui les utilisent tous ;
  /// vide = pas de filtre.
  final Set<String> equipmentIds;
  final IngredientCriteria ingredients;
  final RecipeSort sort;

  bool get isActive =>
      quick != QuickFilter.all ||
      labelIds.isNotEmpty ||
      statuses.isNotEmpty ||
      times.isActive ||
      equipmentIds.isNotEmpty ||
      ingredients.isActive;

  /// Une recette doit-elle être lue en détail (ingrédients, matériel) pour
  /// appliquer ce filtre ?
  bool get needsDetails => equipmentIds.isNotEmpty || ingredients.isActive;

  /// Nombre de critères actifs (pastille sur l'icône du filtre).
  int get activeCount =>
      labelIds.length +
      statuses.length +
      times.count +
      (equipmentIds.isEmpty ? 0 : 1) +
      ingredients.count +
      (quick == QuickFilter.all ? 0 : 1);

  RecipeFilter copyWith({
    QuickFilter? quick,
    Set<String>? labelIds,
    Set<RecipeStatus>? statuses,
    TimeLimits? times,
    Set<String>? equipmentIds,
    IngredientCriteria? ingredients,
    RecipeSort? sort,
  }) => RecipeFilter(
    quick: quick ?? this.quick,
    labelIds: labelIds ?? this.labelIds,
    statuses: statuses ?? this.statuses,
    times: times ?? this.times,
    equipmentIds: equipmentIds ?? this.equipmentIds,
    ingredients: ingredients ?? this.ingredients,
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

/// Les ingrédients qu'on a sous la main, gardés sur l'appareil.
final pantryProvider = NotifierProvider<Pantry, List<String>>(Pantry.new);

class Pantry extends Notifier<List<String>> {
  static const _key = 'pantry';

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(_key) ?? const [];

  Future<void> add(String item) async {
    final clean = item.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return;
    final key = normalizeForSearch(clean);
    if (state.any((old) => normalizeForSearch(old) == key)) return;
    await _save([...state, clean]);
  }

  Future<void> remove(String item) => _save([
    for (final old in state)
      if (old != item) old,
  ]);

  Future<void> _save(List<String> next) async {
    state = next;
    await ref.read(sharedPreferencesProvider).setStringList(_key, next);
  }
}

/// Ce qu'il manque à chaque recette pour la faire avec ce qu'on a sous la main
/// (vide hors de ce mode).
final missingIngredientsProvider = Provider<Map<String, List<String>>>((ref) {
  final criteria = ref.watch(recipeFilterProvider).ingredients;
  if (!criteria.onHand) return const {};
  final pantry = ref.watch(pantryProvider);
  final details = ref.watch(recipeDetailsProvider).value ?? const [];
  return {
    for (final recipe in details)
      if (!recipe.isDeleted) recipe.id: IngredientMatch.missing(recipe, pantry),
  };
});

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
  final missing = ref.watch(missingIngredientsProvider);
  final all = ref.watch(labelsProvider).value ?? const <Label>[];
  final links = ref.watch(recipeLabelLinksProvider).value ?? const {};
  final collection = ref.watch(singleCollectionFilterProvider);
  final criteria = filter.ingredients;

  return ref.watch(recipesProvider).whenData((recipes) {
    var shown = recipes.where((r) {
      if (query.isNotEmpty && !relevance.containsKey(r.id)) return false;
      if (filter.quick == QuickFilter.favorites && !r.isFavorite) return false;
      if (filter.statuses.isNotEmpty && !filter.statuses.contains(r.status)) {
        return false;
      }
      if (!filter.times.accepts(r)) return false;
      final detailed = byId[r.id];
      if (filter.equipmentIds.isNotEmpty &&
          (detailed == null ||
              !filter.equipmentIds.every(detailed.equipmentIds.contains))) {
        return false;
      }
      if (criteria.isActive) {
        if (detailed == null) return false;
        if (!criteria.all.every((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
        if (criteria.any.isNotEmpty &&
            !criteria.any.any((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
        if (criteria.none.any((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
        if (criteria.onHand &&
            (missing[r.id]?.length ?? 1 << 30) > criteria.maxMissing) {
          return false;
        }
      }
      return true;
    }).toList();

    // Catégories, saisons, origines : l'un ou l'autre ; collections : toutes
    // celles qui sont choisies (« Végétarien » ET « Pâques ») ; familles
    // différentes : les deux.
    final byKind = <LabelKind, List<Label>>{};
    for (final label in all) {
      if (filter.labelIds.contains(label.id)) {
        (byKind[label.kind] ??= []).add(label);
      }
    }
    for (final entry in byKind.entries) {
      if (entry.key == LabelKind.collection) {
        for (final label in entry.value) {
          shown = shown
              .where((r) => links[r.id]?.containsKey(label.id) ?? false)
              .toList();
        }
        continue;
      }
      final wanted = _expanded(entry.value, all);
      shown = shown
          .where((r) => (links[r.id]?.keys ?? const []).any(wanted.contains))
          .toList();
    }

    int byTitle(Recipe a, Recipe b) =>
        normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title));
    if (query.isNotEmpty) {
      // Une recherche classe par pertinence, quel que soit le tri choisi.
      shown.sort((a, b) => relevance[a.id]!.compareTo(relevance[b.id]!));
      return shown;
    }
    if (criteria.onHand) {
      // Avec ce qu'on a sous la main : celles auxquelles il manque le moins.
      shown.sort((a, b) {
        final byMissing = (missing[a.id]?.length ?? 0).compareTo(
          missing[b.id]?.length ?? 0,
        );
        return byMissing != 0 ? byMissing : byTitle(a, b);
      });
      return shown;
    }
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
      case RecipeSort.duration:
        shown.sort((a, b) {
          final x = a.totalMinutes, y = b.totalMinutes;
          if (x == null && y == null) return byTitle(a, b);
          if (x == null) return 1;
          if (y == null) return -1;
          return x != y ? x.compareTo(y) : byTitle(a, b);
        });
      case RecipeSort.rating:
        shown.sort((a, b) {
          final x = a.rating, y = b.rating;
          if (x == null && y == null) return byTitle(a, b);
          if (x == null) return 1;
          if (y == null) return -1;
          return x != y ? y.compareTo(x) : byTitle(a, b);
        });
      case RecipeSort.status:
        // À tester, à retester, à améliorer, validée ; sans statut à la fin.
        int rank(Recipe r) => r.status?.index ?? RecipeStatus.values.length;
        shown.sort((a, b) {
          final byRank = rank(a).compareTo(rank(b));
          return byRank != 0 ? byRank : byTitle(a, b);
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
