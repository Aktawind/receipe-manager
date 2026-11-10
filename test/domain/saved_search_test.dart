import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_filter.dart';
import 'package:recettes/domain/saved_search.dart';

final _now = DateTime.utc(2026, 11, 10);

void main() {
  test('une recherche enregistrée se relit à l’identique', () {
    final search = SavedSearch.create(
      now: _now,
      name: 'Plats rapides',
      query: 'poulet',
      filter: const RecipeFilter(
        quick: QuickFilter.favorites,
        labelIds: {'plats'},
        statuses: {RecipeStatus.toTest},
        times: TimeLimits(total: 30),
        equipmentIds: {'four'},
        ingredients: IngredientCriteria(all: ['citron'], none: ['crème']),
        sort: RecipeSort.duration,
      ),
    );
    final back = SavedSearch.fromJson(search.toJson(), now: _now)!;
    expect(back.name, 'Plats rapides');
    expect(back.query, 'poulet');
    expect(back.filter.quick, QuickFilter.favorites);
    expect(back.filter.labelIds, {'plats'});
    expect(back.filter.statuses, {RecipeStatus.toTest});
    expect(back.filter.times.total, 30);
    expect(back.filter.equipmentIds, {'four'});
    expect(back.filter.ingredients.all, ['citron']);
    expect(back.filter.ingredients.none, ['crème']);
    expect(back.filter.sort, RecipeSort.duration);
  });

  test('un enregistrement abîmé ou inconnu est ignoré sans planter', () {
    expect(SavedSearch.fromJson('n’importe quoi', now: _now), isNull);
    expect(SavedSearch.fromJson({'name': ''}, now: _now), isNull);
    final partial = SavedSearch.fromJson({
      'name': 'Vieux',
      'statuses': ['inconnu', 'toRetest'],
      'sort': 'nouveauTri',
    }, now: _now)!;
    expect(partial.filter.statuses, {RecipeStatus.toRetest});
    expect(partial.filter.sort, RecipeSort.title);
  });

  test('le même nom donne la même recherche, sur tous les appareils', () {
    expect(SavedSearch.idFor('Express'), SavedSearch.idFor(' express '));
    expect(SavedSearch.idFor('Express'), isNot(SavedSearch.idFor('Rapide')));
  });
}
