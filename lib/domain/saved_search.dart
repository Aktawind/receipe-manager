import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'recipe.dart';
import 'recipe_filter.dart';

/// Une recherche enregistrée : un nom, le texte cherché, les filtres et le tri.
/// Synchronisée entre les appareils ; son identifiant vient de son nom (le
/// même nom enregistré sur deux appareils donne la même recherche).
@immutable
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    this.query = '',
    this.filter = const RecipeFilter(),
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Une nouvelle recherche, datée de [now].
  factory SavedSearch.create({
    required String name,
    String query = '',
    RecipeFilter filter = const RecipeFilter(),
    required DateTime now,
  }) => SavedSearch(
    id: idFor(name),
    name: name.trim(),
    query: query,
    filter: filter,
    createdAt: now,
    updatedAt: now,
  );

  final String id;
  final String name;
  final String query;
  final RecipeFilter filter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  static String idFor(String name) => const Uuid().v5(
    Namespace.url.value,
    'recettes:search:${name.trim().toLowerCase()}',
  );

  SavedSearch copyWith({
    String? name,
    String? query,
    RecipeFilter? filter,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => SavedSearch(
    id: id,
    name: name ?? this.name,
    query: query ?? this.query,
    filter: filter ?? this.filter,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  /// Le contenu de la recherche (sans identifiant ni dates).
  Map<String, Object?> toJson() {
    final f = filter;
    return {
      'name': name,
      'query': query,
      'favorites': f.quick == QuickFilter.favorites,
      'labels': f.labelIds.toList(),
      'statuses': [for (final s in f.statuses) s.code],
      'total': f.times.total,
      'prep': f.times.prep,
      'cook': f.times.cook,
      'equipment': f.equipmentIds.toList(),
      'all': f.ingredients.all,
      'any': f.ingredients.any,
      'none': f.ingredients.none,
      'sort': f.sort.name,
    };
  }

  /// Lu avec indulgence : un champ inconnu ou absent prend sa valeur neutre ;
  /// [id] et les dates viennent d'ailleurs (base, sauvegarde), sinon du nom
  /// et de [now].
  static SavedSearch? fromJson(
    Object? json, {
    String? id,
    required DateTime now,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    List<String> strings(String key) => [
      for (final v in (json[key] is List ? json[key] as List : const []))
        if (v is String) v,
    ];
    int? number(String key) => json[key] is int ? json[key] as int : null;
    final sort = RecipeSort.values.asNameMap()[json['sort']];
    return SavedSearch(
      id: id ?? idFor(name),
      name: name.trim(),
      query: json['query'] is String ? json['query'] as String : '',
      filter: RecipeFilter(
        quick: json['favorites'] == true
            ? QuickFilter.favorites
            : QuickFilter.all,
        labelIds: strings('labels').toSet(),
        statuses: {
          for (final code in strings('statuses')) ?RecipeStatus.fromCode(code),
        },
        times: TimeLimits(
          total: number('total'),
          prep: number('prep'),
          cook: number('cook'),
        ),
        equipmentIds: strings('equipment').toSet(),
        ingredients: IngredientCriteria(
          all: strings('all'),
          any: strings('any'),
          none: strings('none'),
        ),
        sort: sort == null || sort == RecipeSort.manual
            ? RecipeSort.title
            : sort,
      ),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      deletedAt: deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavedSearch &&
      other.id == id &&
      other.name == name &&
      other.query == query &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      _sameJson(other);

  bool _sameJson(SavedSearch other) =>
      other.toJson().toString() == toJson().toString();

  @override
  int get hashCode =>
      Object.hash(id, name, query, createdAt, updatedAt, deletedAt);
}
