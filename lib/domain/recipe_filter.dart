import '../core/format/text_search.dart';
import 'ingredient_match.dart';
import 'label.dart';
import 'recipe.dart';

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
    int? Function()? total,
    int? Function()? prep,
    int? Function()? cook,
  }) => TimeLimits(
    total: total != null ? total() : this.total,
    prep: prep != null ? prep() : this.prep,
    cook: cook != null ? cook() : this.cook,
  );
}

/// La recherche par ingrédients : ceux que la recette doit tous avoir, ceux dont
/// un suffit, et ceux qu'elle ne doit pas avoir.
class IngredientCriteria {
  const IngredientCriteria({
    this.all = const [],
    this.any = const [],
    this.none = const [],
  });

  final List<String> all;
  final List<String> any;
  final List<String> none;

  bool get isActive => all.isNotEmpty || any.isNotEmpty || none.isNotEmpty;

  int get count => all.length + any.length + none.length;

  IngredientCriteria copyWith({
    List<String>? all,
    List<String>? any,
    List<String>? none,
  }) => IngredientCriteria(
    all: all ?? this.all,
    any: any ?? this.any,
    none: none ?? this.none,
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

  /// Les recettes de [recipes] (triées par titre) qui répondent au filtre,
  /// dans l'ordre choisi. [relevance] : le rang de chaque recette trouvée par
  /// une recherche de texte (elle classe alors par pertinence) ; [details] :
  /// les recettes lues en détail (ingrédients, matériel) ; [links] : le
  /// classement de chaque recette (recette → élément → rang) ; [collection] :
  /// la seule collection filtrée, pour l'ordre manuel.
  List<Recipe> apply(
    List<Recipe> recipes, {
    Map<String, int>? relevance,
    Map<String, Recipe> details = const {},
    List<Label> labels = const [],
    Map<String, Map<String, int>> links = const {},
    Label? collection,
  }) {
    var shown = recipes.where((r) {
      if (relevance != null && !relevance.containsKey(r.id)) return false;
      if (quick == QuickFilter.favorites && !r.isFavorite) return false;
      if (statuses.isNotEmpty && !statuses.contains(r.status)) {
        return false;
      }
      if (!times.accepts(r)) return false;
      final detailed = details[r.id];
      if (equipmentIds.isNotEmpty &&
          (detailed == null ||
              !equipmentIds.every(detailed.equipmentIds.contains))) {
        return false;
      }
      if (ingredients.isActive) {
        if (detailed == null) return false;
        if (!ingredients.all.every((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
        if (ingredients.any.isNotEmpty &&
            !ingredients.any.any((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
        if (ingredients.none.any((t) => IngredientMatch.has(detailed, t))) {
          return false;
        }
      }
      return true;
    }).toList();

    // Catégories, saisons, origines : l'un ou l'autre ; collections : toutes
    // celles qui sont choisies (« Végétarien » ET « Pâques ») ; familles
    // différentes : les deux.
    final byKind = <LabelKind, List<Label>>{};
    for (final label in labels) {
      if (labelIds.contains(label.id)) {
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
      final wanted = _expanded(entry.value, labels);
      shown = shown
          .where((r) => (links[r.id]?.keys ?? const []).any(wanted.contains))
          .toList();
    }

    if (relevance != null) {
      // Une recherche classe par pertinence, quel que soit le tri choisi.
      shown.sort((a, b) => relevance[a.id]!.compareTo(relevance[b.id]!));
    } else {
      _sort(shown, links, collection);
    }
    return shown;
  }

  /// Trie [shown] (déjà par titre) selon [sort].
  void _sort(
    List<Recipe> shown,
    Map<String, Map<String, int>> links,
    Label? collection,
  ) {
    int byTitle(Recipe a, Recipe b) =>
        normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title));
    // Selon une valeur, les recettes sans valeur à la fin, puis par titre.
    Comparator<Recipe> by<T extends Comparable<dynamic>>(
      T? Function(Recipe) value, {
      bool descending = false,
    }) => (a, b) {
      final x = value(a), y = value(b);
      if (x == null || y == null || x == y) {
        return x == y ? byTitle(a, b) : (x == null ? 1 : -1);
      }
      return descending ? y.compareTo(x) : x.compareTo(y);
    };
    switch (sort) {
      case RecipeSort.title:
        break; // déjà trié par titre
      case RecipeSort.added:
        shown.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case RecipeSort.viewed:
        shown.sort(by((r) => r.lastViewedAt, descending: true));
      case RecipeSort.duration:
        shown.sort(by((r) => r.totalMinutes));
      case RecipeSort.rating:
        shown.sort(by((r) => r.rating, descending: true));
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
  }

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
