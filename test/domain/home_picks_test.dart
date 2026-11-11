import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/home_picks.dart';
import 'package:recettes/domain/meal_planner.dart';
import 'package:recettes/domain/recipe.dart';

final _date = DateTime(2026, 11, 2);

Recipe recipe(
  String id, {
  bool favorite = false,
  DateTime? viewed,
  RecipeStatus? status,
}) => Recipe(
  id: id,
  title: id,
  isFavorite: favorite,
  lastViewedAt: viewed,
  status: status,
  createdAt: _date,
  updatedAt: _date,
);

void main() {
  test('favoris, consultées (la plus récente d’abord), à tester', () {
    final recipes = [
      recipe('a', favorite: true, viewed: DateTime(2026, 11, 2)),
      recipe('b', viewed: DateTime(2026, 11, 5)),
      recipe('c', status: RecipeStatus.toTest),
      recipe('d', status: RecipeStatus.validated),
    ];
    expect([for (final r in HomePicks.favorites(recipes)) r.id], ['a']);
    expect([for (final r in HomePicks.recent(recipes)) r.id], ['b', 'a']);
    expect([for (final r in HomePicks.toTest(recipes)) r.id], ['c']);
  });

  test(
    'idées de saison : les mêmes toute la journée, sans les hors saison',
    () {
      final recipes = [for (var i = 0; i < 30; i++) recipe('r$i')];
      final labels = {
        'r0': [Season.summer.labelId],
        'r1': [Season.autumn.labelId],
      };
      final morning = HomePicks.seasonal(
        recipes,
        labels,
        day: DateTime(2026, 11, 11),
      );
      final evening = HomePicks.seasonal(
        recipes,
        labels,
        day: DateTime(2026, 11, 11),
      );
      expect([for (final r in morning) r.id], [for (final r in evening) r.id]);
      expect(morning, hasLength(HomePicks.limit));
      final all = HomePicks.seasonal(
        recipes.take(3).toList(),
        labels,
        day: DateTime(2026, 11, 11),
      );
      // r0 (été) n'est pas proposée en novembre ; r1 (automne) et r2 (sans
      // saison) le sont.
      expect({for (final r in all) r.id}, {'r1', 'r2'});
    },
  );

  test('l’ordre des rubriques se lit et s’écrit', () {
    final layout = HomePicks.parseLayout([
      'favorites:0',
      'today:1',
      'inconnue:1',
      'today:0',
    ]);
    expect(layout.first, (section: HomeSection.favorites, shown: false));
    expect(layout[1], (section: HomeSection.today, shown: true));
    // Les rubriques absentes arrivent à la fin, affichées.
    expect(layout, hasLength(HomeSection.values.length));
    expect(layout.last.shown, isTrue);
    expect(HomePicks.parseLayout(HomePicks.encodeLayout(layout)), layout);
    expect(HomePicks.parseLayout(null).first.section, HomeSection.today);
  });
}
