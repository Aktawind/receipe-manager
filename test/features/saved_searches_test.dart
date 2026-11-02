import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/features/recipes/recipe_providers.dart';
import 'package:recettes/features/recipes/saved_searches.dart';

import '../helpers/test_app.dart';

void main() {
  test('une recherche enregistrée se relit à l’identique', () {
    const search = SavedSearch(
      name: 'Plats rapides',
      query: 'poulet',
      filter: RecipeFilter(
        quick: QuickFilter.favorites,
        labelIds: {'plats'},
        statuses: {RecipeStatus.toTest},
        times: TimeLimits(total: 30),
        equipmentIds: {'four'},
        ingredients: IngredientCriteria(all: ['citron'], none: ['crème']),
        sort: RecipeSort.duration,
      ),
    );
    final back = SavedSearch.fromJson(search.toJson())!;
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
    expect(SavedSearch.fromJson('n’importe quoi'), isNull);
    expect(SavedSearch.fromJson({'name': ''}), isNull);
    final partial = SavedSearch.fromJson({
      'name': 'Vieux',
      'statuses': ['inconnu', 'toRetest'],
      'sort': 'nouveauTri',
    })!;
    expect(partial.filter.statuses, {RecipeStatus.toRetest});
    expect(partial.filter.sort, RecipeSort.title);
  });

  testWidgets('enregistrer une recherche, effacer, la retrouver d’un geste', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      Future<void> add(String title, int prep) async {
        final created = await app.services.recipes.create();
        await app.services.recipes.save(
          created.copyWith(title: title, prepMinutes: () => prep),
        );
      }

      await add('Omelette', 10);
      await add('Pot-au-feu', 180);
    });
    await app.pump(tester);

    Future<void> openFilters() async {
      await tester.tap(find.byTooltip('Filtrer'));
      await settle(tester);
    }

    // Une durée limite, puis on l'enregistre.
    await openFilters();
    await tester.ensureVisible(find.text('Durée'));
    await tester.tap(find.text('Durée'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('limit-total')));
    await settle(tester);
    await tester.tap(find.text('30 min').last);
    await settle(tester);
    await tester.tap(find.text('Valider'));
    await settle(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('saved-search-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saved-search-save')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Express');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Express'), findsOneWidget);
    expect(app.prefs.getStringList('saved_searches'), hasLength(1));

    // Tout effacer : les deux recettes reviennent.
    await tester.tap(find.text('Tout effacer'));
    await settle(tester);
    await tester.tap(find.text('Terminé'));
    await settle(tester);
    expect(find.text('Pot-au-feu'), findsOneWidget);

    // Un appui sur « Express » : la recherche revient, le filtre se ferme.
    await openFilters();
    await tester.tap(find.widgetWithText(InputChip, 'Express'));
    await settle(tester);
    expect(find.text('Omelette'), findsOneWidget);
    expect(find.text('Pot-au-feu'), findsNothing);
    expect(find.text('Effacer les filtres'), findsOneWidget);
  });
}
