import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_match.dart';
import 'package:recettes/domain/recipe.dart';

Recipe recipe(List<IngredientLine> lines) => Recipe(
  id: 'r',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  ingredients: lines,
);

IngredientLine line(
  String name, {
  String substitutes = '',
  bool optional = false,
  bool section = false,
}) => IngredientLine(
  id: name,
  name: name,
  substitutes: substitutes,
  optional: optional,
  isSection: section,
);

void main() {
  final gateau = recipe([
    line('PÂTE', section: true),
    line('farine de blé'),
    line('œufs'),
    line('beurre doux'),
    line('sucre en poudre'),
    line('huile de coco', substitutes: 'margarine, huile de tournesol'),
    line('noix', optional: true),
    line('sel'),
    line('eau'),
  ]);

  test('un ingrédient est reconnu dans une ligne, sans accents ni pluriel', () {
    expect(IngredientMatch.has(gateau, 'farine'), isTrue);
    expect(IngredientMatch.has(gateau, 'oeuf'), isTrue);
    expect(IngredientMatch.has(gateau, 'beurre'), isTrue);
    expect(IngredientMatch.has(gateau, 'sucre poudre'), isTrue);
    expect(IngredientMatch.has(gateau, 'choc'), isFalse);
  });

  test('début de mot et faute de frappe', () {
    expect(IngredientMatch.has(gateau, 'beur'), isTrue);
    expect(IngredientMatch.has(gateau, 'farrine'), isTrue);
  });

  test('un titre de partie n’est pas un ingrédient', () {
    expect(IngredientMatch.has(gateau, 'pate'), isFalse);
  });

  test('un remplaçant ne compte pas comme « contient »', () {
    expect(IngredientMatch.has(gateau, 'margarine'), isFalse);
  });

  test('une faute de frappe ne change pas la première lettre', () {
    final bouches = recipe([
      line('chocolat noir'),
      line('crème fraîche'),
      line('vanille'),
      line('marrons glacés'),
      line('pastilles de chocolat'),
    ]);
    expect(IngredientMatch.has(bouches, 'lentilles'), isFalse);
    expect(IngredientMatch.has(bouches, 'chocolta'), isTrue);
    final saucisse = recipe([
      line('saucisses de Toulouse'),
      line('lentilles vertes'),
    ]);
    expect(IngredientMatch.has(saucisse, 'lentilles'), isTrue);
    expect(IngredientMatch.has(saucisse, 'lentille'), isTrue);
  });
}
