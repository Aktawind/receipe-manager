import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/shopping.dart';

import '../helpers/test_app.dart';

/// Une pâte brisée (pour 1 pâte), une quiche qui l'utilise, des crêpes.
Future<Map<String, Recipe>> _seed(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final repo = app.services.recipes;
      Future<Recipe> make(
        String title,
        int servings,
        String ingredients, {
        String servingsUnit = '',
        Map<String, Recipe> links = const {},
      }) async {
        final created = await repo.create();
        return repo.save(
          created.copyWith(
            title: title,
            servings: () => servings,
            servingsUnit: servingsUnit,
            ingredients: IngredientText.parseList(
              ingredients,
              resolveRecipe: (t) =>
                  links[t] == null ? null : (id: links[t]!.id, title: t),
            ),
          ),
        );
      }

      final pate = await make(
        'Pâte brisée',
        1,
        '250 g de farine\n125 g de beurre\n1 pincée de sel',
        servingsUnit: 'pâte',
      );
      final quiche = await make(
        'Quiche',
        6,
        '1 [[Pâte brisée]]\n200 g de lardons\n3 œufs\nPoivre',
        links: {'Pâte brisée': pate},
      );
      final crepes = await make(
        'Crêpes',
        4,
        '250 g de farine\n4 œufs\n50 cl de lait',
      );
      return {'pate': pate, 'quiche': quiche, 'crepes': crepes};
    }))!;

Future<List<ShoppingList>> _lists(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(() => app.services.shopping.getAllLists()))!;

void main() {
  testWidgets('depuis la fiche : pâte liée dépliée, basiques décochés', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await _seed(app, tester);
    await app.pump(tester);
    await tester.tap(find.text('Quiche'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('recipe-add-to-shopping')));
    await settle(tester);
    expect(find.text('Ajouter aux courses'), findsWidgets);
    expect(find.text('250 g Farine'), findsOneWidget);
    expect(find.text('pour la recette « Pâte brisée »'), findsWidgets);
    // Sel et poivre décochés : 4 produits sur 6.
    expect(find.text('Ajouter 4 produits'), findsOneWidget);

    // Pour 12 personnes : tout est doublé.
    await tester.tap(_keyStarting('add-shopping-more'));
    await settle(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tap(_keyStarting('add-shopping-more'));
      await settle(tester);
    }
    expect(find.text('12 pers.'), findsOneWidget);
    expect(find.text('500 g Farine'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-shopping-confirm')));
    await settle(tester);
    expect(find.text('4 produits ajoutés à « Courses »'), findsOneWidget);

    final list = (await _lists(app, tester)).single;
    expect(list.name, 'Courses');
    expect(
      [for (final i in list.items) '${i.amount} ${i.name}'],
      ['500 g Farine', '250 g Beurre', '400 g Lardons', '6 Œufs'],
    );
    expect(list.items.first.sources.single.recipeTitle, 'Quiche');
  });

  testWidgets('depuis une liste : plusieurs recettes, ingrédients fusionnés', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final recipes = await _seed(app, tester);
    await tester.runAsync(() => app.services.shopping.createList('Semaine'));
    await app.pump(tester);
    await tester.tap(find.text('Courses').last);
    await settle(tester);
    await tester.tap(find.text('Semaine'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('shopping-add-recipes')));
    await settle(tester);
    await tester.tap(
      find.byKey(ValueKey('recipe-picker-${recipes['quiche']!.id}')),
    );
    await tester.tap(
      find.byKey(ValueKey('recipe-picker-${recipes['crepes']!.id}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('recipe-picker-ok')));
    await tester.pump();
    // Les recettes sont relues en base avant d'ouvrir le choix des ingrédients.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('add-shopping-confirm')));
    await settle(tester);

    final list = (await _lists(app, tester)).single;
    final farine = list.items.firstWhere((i) => i.name == 'Farine');
    expect(farine.amount, '500 g');
    expect(list.items.firstWhere((i) => i.name == 'Œufs').amount, '7');
    expect(find.text('pour : Quiche, Crêpes'), findsWidgets);
  });
}

/// Le widget dont la clé commence par [prefix] (clés qui contiennent un
/// identifiant de recette).
Finder _keyStarting(String prefix) => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(prefix),
);
