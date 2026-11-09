import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/default_labels.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/meal_planner.dart';
import 'package:recettes/domain/recipe.dart';

final _date = DateTime(2026, 11, 8);
const _dinner = 'diner';

Recipe recipe(
  String title, {
  int? minutes,
  List<Season> seasons = const [],
  bool allSeasons = false,
  List<String> collections = const [],
  String ingredients = '',
}) => Recipe(
  id: title,
  title: title,
  prepMinutes: minutes,
  labelIds: [
    for (final s in seasons) s.labelId,
    if (allSeasons) Label.idFor(LabelKind.season, DefaultLabels.allSeasons),
    ...collections,
  ],
  ingredients: IngredientText.parseList(ingredients),
  createdAt: _date,
  updatedAt: _date,
);

List<String> titles(List<Recipe?> recipes) => [
  for (final r in recipes) r?.title ?? '—',
];

void main() {
  final recipes = [
    recipe('Gratin', minutes: 60, seasons: [Season.winter]),
    recipe('Salade', minutes: 10, seasons: [Season.summer]),
    recipe('Omelette', minutes: 15),
    recipe('Soupe', minutes: 25, seasons: [Season.winter, Season.autumn]),
    recipe('Pâtes au pesto', allSeasons: true, minutes: 20),
    recipe('Quiche', collections: ['rapide'], ingredients: '3 courgettes'),
  ];
  const slot = PlannerSlot(weekday: 1, slotId: _dinner);

  test('saison de la date', () {
    expect(Season.of(DateTime(2026, 11, 8)), Season.autumn);
    expect(Season.of(DateTime(2026, 1, 3)), Season.winter);
    expect(Season.of(DateTime(2026, 7, 14)), Season.summer);
  });

  test('temps et saison : sans durée ni saison, une recette convient', () {
    final options = MealPlanner.candidates(
      recipes,
      slot,
      season: Season.autumn,
      random: Random(1),
    );
    expect(
      {for (final r in options) r.title},
      {'Omelette', 'Soupe', 'Pâtes au pesto', 'Quiche'},
    );
  });

  test('collection et ingrédients à écouler', () {
    final rapide = MealPlanner.candidates(
      recipes,
      const PlannerSlot(weekday: 1, slotId: _dinner, collectionId: 'rapide'),
      season: Season.autumn,
      random: Random(1),
    );
    expect(titles(rapide), ['Quiche']);
    for (var seed = 0; seed < 5; seed++) {
      final options = MealPlanner.candidates(
        recipes,
        slot,
        season: Season.autumn,
        useUp: ['courgette'],
        random: Random(seed),
      );
      expect(options.first.title, 'Quiche', reason: 'graine $seed');
    }
  });

  test('une semaine : pas deux fois la même recette, puis remplacer', () {
    final week = [
      for (var day = 1; day <= 4; day++)
        PlannerSlot(weekday: day, slotId: _dinner),
    ];
    final plan = MealPlanner.propose(
      recipes,
      week,
      season: Season.autumn,
      random: Random(3),
    );
    expect(plan.toSet(), hasLength(4));
    final other = MealPlanner.replace(
      recipes,
      week.first,
      season: Season.autumn,
      taken: {for (final r in plan) r!.id},
      rejected: {plan.first!.id},
      random: Random(4),
    );
    expect(other, isNotNull);
    expect(other!.id, isNot(plan.first!.id));

    // Plus de repas que de recettes : les recettes reviennent.
    final long = MealPlanner.propose(
      recipes,
      [for (var i = 0; i < 6; i++) PlannerSlot(weekday: 1, slotId: '$i')],
      season: Season.autumn,
      random: Random(3),
    );
    expect(long.every((r) => r != null), isTrue);
  });

  test('accompagnements : de saison, sans se répéter', () {
    final sides = DefaultSideDishes.build(_date);
    final random = Random(2);
    final seen = <String>{};
    for (var i = 0; i < 6; i++) {
      final v = MealPlanner.side(
        sides,
        SideKind.vegetable,
        season: Season.summer,
        exclude: seen,
        random: random,
      )!;
      expect(v.fits(Season.summer), isTrue, reason: v.name);
      expect(seen.add(v.name), isTrue);
    }
    final starch = MealPlanner.side(
      sides,
      SideKind.starch,
      season: Season.winter,
      random: random,
    );
    expect(DefaultSideDishes.starches, contains(starch!.name));
    expect(
      MealPlanner.side(
        const [],
        SideKind.protein,
        season: Season.winter,
        random: random,
      ),
      isNull,
    );
  });

  test('une ligne de planification se lit et s’écrit', () {
    const line = PlannerSlot(
      weekday: 5,
      slotId: _dinner,
      minutes: 45,
      collectionId: 'rapide',
    );
    expect(PlannerSlot.fromJson(line.toJson()), line);
    expect(PlannerSlot.fromJson({'weekday': 9, 'slot': 'x'}), isNull);
  });

  test('sans limite de temps', () {
    const free = PlannerSlot(weekday: 7, slotId: _dinner, minutes: null);
    final options = MealPlanner.candidates(
      recipes,
      free,
      season: Season.winter,
      random: Random(1),
    );
    expect(options.map((r) => r.title), contains('Gratin'));
    // `null` se garde ; une ancienne ligne sans temps reste à 30 min.
    expect(PlannerSlot.fromJson(free.toJson())!.minutes, isNull);
    expect(PlannerSlot.fromJson({'weekday': 1, 'slot': _dinner})!.minutes, 30);
  });

  test('les types de plat du créneau', () {
    final breakfast = [
      recipe('Tarte aux pommes', collections: ['dessert']),
      recipe('Choucroute', collections: ['plat']),
      recipe('Porridge', collections: ['petit-dej']),
    ];
    const morning = PlannerSlot(weekday: 7, slotId: 'matin', minutes: null);
    expect(
      titles(
        MealPlanner.candidates(
          breakfast,
          morning,
          season: Season.winter,
          categories: {'petit-dej'},
          random: Random(1),
        ),
      ),
      ['Porridge'],
    );
    // Sans type de plat choisi : tout convient.
    expect(
      MealPlanner.candidates(
        breakfast,
        morning,
        season: Season.winter,
        random: Random(1),
      ),
      hasLength(3),
    );
    expect(
      titles(
        MealPlanner.propose(
          breakfast,
          [morning, const PlannerSlot(weekday: 7, slotId: _dinner)],
          season: Season.winter,
          categories: {
            'matin': {'petit-dej'},
            _dinner: {'plat'},
          },
          random: Random(1),
        ),
      ),
      ['Porridge', 'Choucroute'],
    );
  });
}
