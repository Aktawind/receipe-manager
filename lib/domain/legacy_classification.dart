import 'default_labels.dart';
import 'label.dart';

/// Le classement d'une recette tel qu'il était avant la 0.3 : un type de plat,
/// des catégories et des collections en texte libre (c'est aussi ce que fournit
/// l'export de Recipe Keeper).
class LegacyEntry {
  const LegacyEntry({
    required this.recipeId,
    this.course = '',
    this.categories = const [],
    this.collections = const [],
  });

  final String recipeId;
  final String course;
  final List<String> categories;
  final List<String> collections;
}

/// Le résultat : les éléments de classement utilisés (avec leurs parents) et,
/// pour chaque recette, les identifiants à lui rattacher.
class ClassificationPlan {
  const ClassificationPlan(this.labels, this.byRecipe);

  final List<Label> labels;
  final Map<String, List<String>> byRecipe;
}

/// Convertit l'ancien classement en texte libre vers les catégories,
/// sous-catégories, saisons et collections.
///
/// - le type de plat (Plat, Dessert, Goûter…) devient la catégorie, la
///   catégorie d'origine (Viandes, Gâteaux…) la sous-catégorie ;
/// - les noms qui se ressemblent sont fusionnés : « Gâteau » et « Gâteaux »,
///   « Riz » et « Riz et céréales » ;
/// - les quatre saisons deviennent « Toute saison », trois saisons ou moins
///   restent des saisons ; toute autre collection reste une collection.
abstract final class LegacyClassification {
  static ClassificationPlan plan(
    Iterable<LegacyEntry> entries,
    DateTime now, {
    Iterable<Label> existing = const [],
  }) {
    final list = entries.toList();
    final catalog = <String, Label>{
      for (final label in DefaultLabels.build(now)) label.id: label,
      for (final label in existing) label.id: label,
    };

    // Familles de noms : les types de plat (et les catégories sans type de
    // plat) au premier niveau, puis les catégories de chaque type de plat.
    final top = _Book();
    for (final label in catalog.values) {
      if (label.kind == LabelKind.category && label.parentId == null) {
        top.preferred(label.name);
      }
    }
    final subs = <String, _Book>{};
    for (final entry in list) {
      final course = entry.course.trim();
      if (course.isNotEmpty) top.add(course);
      for (final category in _names(entry.categories)) {
        if (course.isEmpty) {
          top.add(category);
        } else if (Label.keyOf(category) != Label.keyOf(course)) {
          (subs[Label.keyOf(course)] ??= _Book()).add(category);
        }
      }
    }
    top.freeze();
    for (final book in subs.values) {
      book.freeze();
    }

    Label obtain(LabelKind kind, String name, {Label? parent}) {
      final id = Label.idFor(kind, name, parentId: parent?.id);
      return catalog.putIfAbsent(id, () {
        final position = catalog.values
            .where((l) => l.kind == kind && l.parentId == parent?.id)
            .length;
        return Label(
          id: id,
          kind: kind,
          name: name,
          parentId: parent?.id,
          position: position,
          createdAt: now,
          updatedAt: now,
        );
      });
    }

    final seasonKeys = {
      for (final name in DefaultLabels.seasonNames) Label.keyOf(name): name,
    };
    final used = <String>{};
    final byRecipe = <String, List<String>>{};

    for (final entry in list) {
      final ids = <String>[];
      final course = entry.course.trim();
      final courseLabel = course.isEmpty
          ? null
          : obtain(LabelKind.category, top.resolve(course));
      final categories = _names(entry.categories);

      var placed = false;
      for (final category in categories) {
        if (courseLabel == null) {
          ids.add(obtain(LabelKind.category, top.resolve(category)).id);
          placed = true;
        } else if (Label.keyOf(category) != Label.keyOf(course)) {
          final book = subs[Label.keyOf(course)]!;
          ids.add(
            obtain(
              LabelKind.category,
              book.resolve(category),
              parent: courseLabel,
            ).id,
          );
          placed = true;
        }
      }
      if (!placed && courseLabel != null) ids.add(courseLabel.id);

      final seasons = <String>{};
      for (final name in _names(entry.collections)) {
        final season = seasonKeys[Label.keyOf(name)];
        if (season != null) {
          seasons.add(season);
        } else {
          ids.add(obtain(LabelKind.collection, Label.cleanName(name)).id);
        }
      }
      if (seasons.length == DefaultLabels.seasonNames.length) {
        ids.add(obtain(LabelKind.season, DefaultLabels.allSeasons).id);
      } else {
        for (final season in DefaultLabels.seasonNames) {
          if (seasons.contains(season)) {
            ids.add(obtain(LabelKind.season, season).id);
          }
        }
      }

      final unique = <String>[];
      for (final id in ids) {
        if (!unique.contains(id)) unique.add(id);
      }
      byRecipe[entry.recipeId] = unique;
      used.addAll(unique);
    }

    // Seuls les éléments utilisés (et leurs parents) sont renvoyés : les
    // autres éléments par défaut ne sont pas ressuscités par un ancien fichier.
    for (final id in used.toList()) {
      final parent = catalog[id]?.parentId;
      if (parent != null) used.add(parent);
    }
    return ClassificationPlan([
      for (final label in catalog.values)
        if (used.contains(label.id)) label,
    ], byRecipe);
  }

  static List<String> _names(Iterable<String> names) => [
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim(),
  ];
}

/// Les noms d'une même famille, avec leurs fusions.
class _Book {
  final _seen = <String, Map<String, int>>{};
  final _preferred = <String, String>{};
  Map<String, String> _alias = {};
  final _display = <String, String>{};

  /// Un nom qui doit être gardé tel quel (élément par défaut ou existant).
  void preferred(String name) => _preferred[Label.keyOf(name)] = name;

  void add(String name) {
    final display = Label.cleanName(name);
    final counts = _seen.putIfAbsent(Label.keyOf(display), () => {});
    counts.update(display, (n) => n + 1, ifAbsent: () => 1);
  }

  void freeze() {
    // « riz » est une forme courte de « riz et céréales ».
    final keys = {..._seen.keys, ..._preferred.keys}.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _alias = {};
    for (final key in keys) {
      for (final longer in keys) {
        if (longer != key && longer.startsWith('$key et ')) {
          _alias[key] = _alias[longer] ?? longer;
          break;
        }
      }
    }
    // L'affichage d'un nom vient de ses propres écritures (« Gâteaux » plutôt
    // que « Gâteau » quand il y en a plus), jamais de sa forme courte.
    for (final entry in _seen.entries) {
      final preferred = _preferred[entry.key];
      if (preferred != null) {
        _display[entry.key] = preferred;
        continue;
      }
      final best = entry.value.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : b.key.length.compareTo(a.key.length);
        });
      _display[entry.key] = best.first.key;
    }
    for (final entry in _preferred.entries) {
      _display.putIfAbsent(entry.key, () => entry.value);
    }
  }

  /// Le nom à utiliser pour [name] : fusionné avec ses semblables.
  String resolve(String name) {
    final key = Label.keyOf(Label.cleanName(name));
    final target = _alias[key] ?? key;
    return _display[target] ?? _preferred[target] ?? Label.cleanName(name);
  }
}
