import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/shopping.dart';
import 'package:recettes/domain/shopping_from_recipes.dart';

final _date = DateTime(2026, 11, 5);

Recipe recipe(
  String id,
  String title,
  List<String> lines, {
  int? servings,
  Map<String, String> links = const {},
}) => Recipe(
  id: id,
  title: title,
  servings: servings,
  createdAt: _date,
  updatedAt: _date,
  ingredients: [
    for (final (index, line) in lines.indexed)
      IngredientText.parse(
        line,
        id: '$id-$index',
        resolveRecipe: (title) =>
            links[title] == null ? null : (id: links[title]!, title: title),
      ),
  ],
);

String show(ShoppingCandidate c) =>
    '${c.selected ? '[x]' : '[ ]'} ${c.item.amount} ${c.item.name}'.replaceAll(
      '  ',
      ' ',
    );

void main() {
  final pate = recipe('pate', 'Pâte brisée', [
    '250 g de farine',
    '125 g de beurre froid',
    '1 pincée de sel',
    '5 cl d’eau froide',
  ], servings: 1);
  final quiche = recipe(
    'quiche',
    'Quiche lorraine',
    [
      'Pour la pâte :',
      '1 [[Pâte brisée]]',
      'La garniture :',
      '200 g de lardons',
      '3 œufs',
      '20 cl de crème fraîche',
      'Poivre',
      'Muscade (facultatif)',
    ],
    servings: 6,
    links: {'Pâte brisée': 'pate'},
  );
  Recipe? find(String id) => {'pate': pate, 'quiche': quiche}[id];

  test('les ingrédients, recettes liées dépliées, basiques décochés', () {
    final list = ShoppingFromRecipes.candidates(quiche, 1, linked: find);
    expect(
      [for (final c in list) show(c)],
      [
        '[x] 250 g Farine',
        '[x] 125 g Beurre froid',
        '[ ] 1 pincée Sel',
        '[ ] 5 cl Eau froide',
        '[x] 200 g Lardons',
        '[x] 3 Œufs',
        '[x] 20 cl Crème fraîche',
        '[ ] Poivre',
        '[ ] Muscade',
      ],
    );
    // La recette d'origine est la quiche, même pour la pâte.
    expect(list.first.item.sources.single.recipeTitle, 'Quiche lorraine');
    expect(list.first.viaRecipe, 'Pâte brisée');
    expect(list[4].viaRecipe, isNull);
  });

  test('pour 12 personnes : tout est doublé, la pâte aussi', () {
    final list = ShoppingFromRecipes.candidates(quiche, 2, linked: find);
    expect(show(list.first), '[x] 500 g Farine');
    expect(show(list[5]), '[x] 6 Œufs');
  });

  test('« 2 pâtes brisées » demandent deux fois la recette de la pâte', () {
    final tartes = recipe(
      'tartes',
      'Deux tartes',
      ['2 [[Pâte brisée]]', '1 kg de pommes'],
      servings: 8,
      links: {'Pâte brisée': 'pate'},
    );
    final list = ShoppingFromRecipes.candidates(
      tartes,
      1,
      linked: (id) => id == 'pate' ? pate : null,
    );
    expect(show(list.first), '[x] 500 g Farine');
  });

  test('une recette liée disparue reste une ligne ordinaire', () {
    final list = ShoppingFromRecipes.candidates(quiche, 1, linked: (_) => null);
    expect(show(list.first), '[x] 1 Pâte brisée');
  });

  test('une recette qui se contient elle-même ne boucle pas', () {
    final loop = recipe(
      'loop',
      'Sauce',
      ['1 [[Sauce]]', '1 oignon'],
      servings: 1,
      links: {'Sauce': 'loop'},
    );
    final list = ShoppingFromRecipes.candidates(loop, 1, linked: (_) => loop);
    expect([for (final c in list) show(c)], ['[x] 1 Sauce', '[x] 1 Oignon']);
  });

  test('ajoutées à une liste, deux recettes fusionnent leurs ingrédients', () {
    final crepes = recipe('crepes', 'Crêpes', [
      '250 g de farine',
      '4 œufs',
      '50 g de beurre',
    ], servings: 4);
    var items = <ShoppingItem>[];
    for (final r in [quiche, crepes]) {
      for (final c in ShoppingFromRecipes.candidates(r, 1, linked: find)) {
        if (c.selected) items = ShoppingProducts.merge(items, c.item);
      }
    }
    final farine = items.firstWhere((i) => i.name == 'Farine');
    expect(farine.amount, '500 g');
    expect(
      [for (final s in farine.sources) s.recipeTitle],
      ['Quiche lorraine', 'Crêpes'],
    );
    expect(items.firstWhere((i) => i.name == 'Œufs').amount, '7');
    // « beurre froid » et « beurre » restent deux produits.
    expect(items.where((i) => i.name.startsWith('Beurre')), hasLength(2));
  });

  test('basiques', () {
    for (final name in [
      'Sel',
      'sel fin',
      'Fleur de sel',
      'Poivre du moulin',
      'Eau',
      'eau tiède',
      'Sel et poivre',
    ]) {
      expect(ShoppingFromRecipes.isBasic(name), isTrue, reason: name);
    }
    for (final name in [
      'Poivron',
      'Eau de fleur d’oranger',
      'Selle d’agneau',
      'Eau gazeuse',
    ]) {
      expect(ShoppingFromRecipes.isBasic(name), isFalse, reason: name);
    }
  });
}
