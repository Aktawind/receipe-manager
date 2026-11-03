import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  IngredientLine line(String name, double? quantity, [String unit = '']) =>
      IngredientLine(
        id: RecipeRepository.newId(),
        name: name,
        quantity: quantity,
        unit: unit,
      );

  Future<TestApp> open(
    WidgetTester tester,
    Recipe Function(Recipe) fill, {
    Map<String, Object> prefs = const {},
  }) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(() => TestApp.create(prefs: prefs)))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      await repo.save(fill(await repo.create()));
    });
    await app.pump(tester);
    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    return app;
  }

  testWidgets('changer les portions recalcule les ingrédients', (tester) async {
    await open(
      tester,
      (r) => r.copyWith(
        title: 'Crêpes',
        servings: () => 4,
        cookMinutes: () => 20,
        ingredients: [
          line('farine', 250, 'g'),
          line('œufs', 3),
          line('sel', 1, 'pincée'),
        ],
      ),
    );
    expect(find.text('4 pers.'), findsOneWidget);
    expect(find.text('250 g de farine'), findsOneWidget);
    expect(find.text('Quantités recalculées'), findsNothing);

    // Deux personnes de plus : × 1,5.
    await tester.tap(find.byKey(const ValueKey('servings-more')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('servings-more')));
    await settle(tester);
    expect(find.text('6 pers.'), findsOneWidget);
    expect(find.text('375 g de farine · au lieu de 250 g'), findsOneWidget);
    expect(find.text('5 œufs · au lieu de 3 · 4 ½ exactement'), findsOneWidget);
    expect(
      find.text('1 ½ pincée de sel · au lieu de 1 pincée · à goûter'),
      findsOneWidget,
    );
    expect(find.text('Quantités recalculées'), findsOneWidget);

    // Choix direct dans la liste : 2 personnes.
    await tester.tap(find.byKey(const ValueKey('servings-pill')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('scale-0.5')));
    await settle(tester);
    expect(find.text('2 pers.'), findsOneWidget);
    expect(find.text('125 g de farine · au lieu de 250 g'), findsOneWidget);

    // Nombre libre.
    await tester.tap(find.byKey(const ValueKey('servings-pill')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('scale-other')), '10');
    await tester.tap(find.byKey(const ValueKey('scale-other-ok')));
    await settle(tester);
    expect(find.text('10 pers.'), findsOneWidget);
    expect(find.text('625 g de farine · au lieu de 250 g'), findsOneWidget);

    // Retour à la recette.
    await tester.tap(find.byKey(const ValueKey('scale-reset')));
    await settle(tester);
    expect(find.text('4 pers.'), findsOneWidget);
    expect(find.text('250 g de farine'), findsOneWidget);
    expect(find.text('Quantités recalculées'), findsNothing);
  });

  testWidgets('unités et températures choisies dans les réglages', (
    tester,
  ) async {
    await open(
      tester,
      (r) => r.copyWith(
        title: 'Crêpes',
        servings: () => 4,
        ingredients: [
          line('farine', 2, 'tasse'),
          line('lait', 1, 'tasse'),
          line('beurre', 4, 'oz'),
          line('œufs', 2),
        ],
        steps: [
          RecipeStep(
            id: RecipeRepository.newId(),
            text: 'Cuire à 350 °F dans un moule de 9 pouces.',
          ),
        ],
      ),
      prefs: {'unit_system': 'metric', 'temperature_unit': 'celsius'},
    );
    // La densité de la farine : une estimation, marquée « ≈ ».
    expect(find.text('≈ 255 g de farine'), findsOneWidget);
    expect(find.text('240 ml de lait'), findsOneWidget);
    expect(find.text('113 g de beurre'), findsOneWidget);
    expect(find.text('2 œufs'), findsOneWidget);
    expect(find.text('Cuire à 175 °C dans un moule de 23 cm.'), findsOneWidget);
    // Pas de « Quantités recalculées » : seules les unités changent.
    expect(find.text('Quantités recalculées'), findsNothing);
  });

  testWidgets('une recette sans nombre de personnes ne propose rien', (
    tester,
  ) async {
    await open(
      tester,
      (r) => r.copyWith(title: 'Crêpes', ingredients: [line('lait', 50, 'cl')]),
    );
    expect(find.text('50 cl de lait'), findsOneWidget);
    expect(find.byKey(const ValueKey('servings-more')), findsNothing);
  });
}
