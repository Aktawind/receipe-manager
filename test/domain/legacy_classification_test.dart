import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/legacy_classification.dart';

void main() {
  final now = DateTime(2026, 10, 29);

  /// Les noms des étiquettes d'une recette, avec leur parent : « Plats > Viandes ».
  List<String> pathsOf(ClassificationPlan plan, String recipeId) {
    final byId = {for (final l in plan.labels) l.id: l};
    return [
      for (final id in plan.byRecipe[recipeId]!)
        [
          if (byId[id]!.parentId != null) byId[byId[id]!.parentId]!.name,
          byId[id]!.name,
        ].join(' > '),
    ];
  }

  LegacyEntry entry(
    String id, {
    String course = '',
    List<String> categories = const [],
    List<String> collections = const [],
  }) => LegacyEntry(
    recipeId: id,
    course: course,
    categories: categories,
    collections: collections,
  );

  test(
    'le type de plat devient la catégorie, la catégorie la sous-catégorie',
    () {
      final plan = LegacyClassification.plan([
        entry('a', course: 'Plat', categories: ['Viandes']),
        entry('b', course: 'Dessert', categories: ['Gâteaux']),
        entry('c', course: 'Dessert'),
      ], now);
      expect(pathsOf(plan, 'a'), ['Plats > Viandes']);
      expect(pathsOf(plan, 'b'), ['Desserts > Gâteaux']);
      expect(pathsOf(plan, 'c'), ['Desserts']);
    },
  );

  test(
    'les types de plat de Recipe Keeper retrouvent les catégories par défaut',
    () {
      final plan = LegacyClassification.plan([
        entry('1', course: 'Plat'),
        entry('2', course: 'Goûter'),
        entry('3', course: 'Apéritifs et Entrées'),
        entry('4', course: 'Boisson', categories: ['Boissons']),
        entry('5', course: 'Préparation'),
      ], now);
      expect(plan.byRecipe.values.map((_) => 1).length, 5);
      expect(pathsOf(plan, '1'), ['Plats']);
      expect(pathsOf(plan, '2'), ['Goûters']);
      expect(pathsOf(plan, '3'), ['Apéritifs et entrées']);
      // La sous-catégorie identique à sa catégorie n'est pas créée.
      expect(pathsOf(plan, '4'), ['Boissons']);
      expect(pathsOf(plan, '5'), ['Préparations']);
      // Les identifiants sont ceux des éléments par défaut.
      expect(
        plan.byRecipe['1']!.single,
        Label.idFor(LabelKind.category, 'Plats'),
      );
    },
  );

  test('les noms qui se ressemblent sont fusionnés', () {
    final plan = LegacyClassification.plan([
      for (var i = 0; i < 5; i++)
        entry('g$i', course: 'Dessert', categories: ['Gâteaux']),
      entry('g5', course: 'Dessert', categories: ['Gâteau']),
      entry('s1', course: 'Plat', categories: ['Salades']),
      entry('s2', course: 'Plat', categories: ['Salade']),
      entry('so', course: 'Plat', categories: ['Soupe']),
      entry('so2', course: 'Plat', categories: ['Soupes']),
      entry('so3', course: 'Plat', categories: ['Soupes']),
      for (var i = 0; i < 7; i++)
        entry('r$i', course: 'Plat', categories: ['Riz et céréales']),
      entry('r7', course: 'Plat', categories: ['Riz']),
    ], now);
    expect(pathsOf(plan, 'g5'), ['Desserts > Gâteaux']);
    expect(pathsOf(plan, 's2'), pathsOf(plan, 's1'));
    expect(pathsOf(plan, 'so'), ['Plats > Soupes']);
    expect(pathsOf(plan, 'r7'), ['Plats > Riz et céréales']);
    final names = plan.labels.map((l) => l.name).toList();
    expect(names.where((n) => n == 'Gâteaux'), hasLength(1));
    expect(names, isNot(contains('Gâteau')));
    expect(names, isNot(contains('Riz')));
    expect(names, isNot(contains('Salade')));
  });

  test('une même catégorie sous deux types de plat reste dans chacun', () {
    final plan = LegacyClassification.plan([
      entry('a', course: 'Dessert', categories: ['Gâteaux']),
      entry('b', course: 'Goûter', categories: ['Gâteaux']),
    ], now);
    expect(pathsOf(plan, 'a'), ['Desserts > Gâteaux']);
    expect(pathsOf(plan, 'b'), ['Goûters > Gâteaux']);
    expect(plan.byRecipe['a'], isNot(plan.byRecipe['b']));
  });

  test('sans type de plat, la catégorie est au premier niveau', () {
    final plan = LegacyClassification.plan([
      entry('a', categories: ['Viandes']),
      entry('b'),
    ], now);
    expect(pathsOf(plan, 'a'), ['Viandes']);
    expect(plan.byRecipe['b'], isEmpty);
  });

  test('saisons : les quatre = « Toute saison », sinon celles qui restent', () {
    final plan = LegacyClassification.plan([
      entry('all', collections: ['Automne', 'Été', 'Hiver', 'Printemps']),
      entry('three', collections: ['Automne', 'Hiver', 'Printemps']),
      entry('summer', collections: ['Été']),
      entry('none'),
      entry('mixed', collections: ['Été', 'Pique-nique du dimanche']),
    ], now);
    expect(pathsOf(plan, 'all'), ['Toute saison']);
    expect(pathsOf(plan, 'three'), ['Printemps', 'Automne', 'Hiver']);
    expect(pathsOf(plan, 'summer'), ['Été']);
    expect(plan.byRecipe['none'], isEmpty);
    // Une collection qui n'est pas une saison reste une collection.
    expect(pathsOf(plan, 'mixed'), ['Pique-nique du dimanche', 'Été']);
    final custom = plan.labels.firstWhere(
      (l) => l.name == 'Pique-nique du dimanche',
    );
    expect(custom.kind, LabelKind.collection);
  });

  test('seuls les éléments utilisés sont renvoyés, parents compris', () {
    final plan = LegacyClassification.plan([
      entry('a', course: 'Plat', categories: ['Viandes']),
    ], now);
    expect(plan.labels.map((l) => l.name).toList()..sort(), [
      'Plats',
      'Viandes',
    ]);
  });

  test('mêmes données = mêmes identifiants, quel que soit l’ordre', () {
    final one = LegacyClassification.plan([
      entry('a', course: 'Plat', categories: ['Viandes']),
      entry('b', course: 'Plat', categories: ['Salades']),
    ], now);
    final two = LegacyClassification.plan([
      entry('b', course: 'Plat', categories: ['Salades']),
      entry('a', course: 'Plat', categories: ['Viandes']),
    ], DateTime(2030));
    expect(one.byRecipe, two.byRecipe);
  });
}
