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

  test('ce qui manque : rien quand tout est là', () {
    expect(
      IngredientMatch.missing(gateau, [
        'farine',
        'oeufs',
        'beurre',
        'sucre',
        'huile de coco',
      ]),
      isEmpty,
    );
  });

  test('ce qui manque : les lignes non couvertes, telles qu’écrites', () {
    expect(IngredientMatch.missing(gateau, ['farine', 'sucre']), [
      'œufs',
      'beurre doux',
      'huile de coco',
    ]);
  });

  test('un remplaçant possible suffit', () {
    expect(
      IngredientMatch.missing(gateau, [
        'farine',
        'oeufs',
        'beurre',
        'sucre',
        'margarine',
      ]),
      isEmpty,
    );
  });

  test('facultatif, eau, sel et poivre ne manquent jamais', () {
    final simple = recipe([
      line('sel fin'),
      line('poivre'),
      line('eau'),
      line('persil', optional: true),
      line('tomates'),
    ]);
    expect(IngredientMatch.missing(simple, const []), ['tomates']);
    expect(IngredientMatch.missing(simple, ['tomate']), isEmpty);
  });

  test('« eau de fleur d’oranger » n’est pas de l’eau', () {
    final r = recipe([line('eau de fleur d’oranger')]);
    expect(IngredientMatch.missing(r, const []), ['eau de fleur d’oranger']);
  });
}
