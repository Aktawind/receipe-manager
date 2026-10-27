import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/recipe.dart';

IngredientLine parse(String text) => IngredientText.parse(text, id: 'x');

void main() {
  group('parse', () {
    test('quantité, unité et nom', () {
      final line = parse('200 g de farine');
      expect(line.quantity, 200);
      expect(line.unit, 'g');
      expect(line.name, 'farine');
    });

    test('unité collée au nombre', () {
      final line = parse('200g sucre');
      expect(line.quantity, 200);
      expect(line.unit, 'g');
      expect(line.name, 'sucre');
    });

    test("élision d'", () {
      final line = parse("2 gousses d'ail");
      expect(line.quantity, 2);
      expect(line.unit, 'gousse');
      expect(line.name, 'ail');
    });

    test('cuillères en toutes lettres', () {
      final line = parse('1 cuillère à soupe d’huile d’olive');
      expect(line.unit, 'c. à s.');
      expect(line.name, 'huile d’olive');
    });

    test('fractions', () {
      expect(parse('1/2 citron').quantity, 0.5);
      expect(parse('1 1/2 tasse de lait').quantity, 1.5);
      expect(parse('½ botte de persil').quantity, 0.5);
      expect(parse('1½ L de lait').quantity, 1.5);
      expect(parse('1,5 kg de pommes').quantity, 1.5);
    });

    test('« un » et « une » valent 1', () {
      final line = parse('une pincée de sel');
      expect(line.quantity, 1);
      expect(line.unit, 'pincée');
      expect(line.name, 'sel');
      expect(parse('un oignon').quantity, 1);
    });

    test('sans unité', () {
      final line = parse('3 œufs');
      expect(line.quantity, 3);
      expect(line.unit, '');
      expect(line.name, 'œufs');
    });

    test('sans quantité précise', () {
      final line = parse('poivre selon le goût');
      expect(line.quantity, isNull);
      expect(line.name, 'poivre');
      expect(line.note, 'selon le goût');
    });

    test('précision après une virgule', () {
      final line = parse('1 oignon, finement haché');
      expect(line.name, 'oignon');
      expect(line.note, 'finement haché');
    });

    test('facultatif', () {
      final line = parse('50 g de noix (facultatif)');
      expect(line.optional, isTrue);
      expect(line.name, 'noix');
    });

    test('titre de groupe', () {
      final line = parse('Pour la pâte :');
      expect(line.isSection, isTrue);
      expect(line.name, 'Pour la pâte');
    });

    test('un mot qui commence comme une unité reste le nom', () {
      final line = parse('2 lardons');
      expect(line.unit, '');
      expect(line.name, 'lardons');
    });

    test('un nombre suivi de lettres n’est pas une quantité', () {
      expect(parse('4x4 carrés').quantity, isNull);
    });
  });

  group('format', () {
    test('aller-retour', () {
      for (final text in [
        '200 g de farine',
        "2 gousses d'ail",
        '1 ½ L de lait',
        '3 œufs',
        'poivre, selon le goût',
        '50 g de noix (facultatif)',
        'Pour la pâte:',
        '1 pincée de sel',
      ]) {
        expect(IngredientText.format(parse(text)), text);
      }
    });

    test('quantités', () {
      expect(IngredientText.formatQuantity(2), '2');
      expect(IngredientText.formatQuantity(0.5), '½');
      expect(IngredientText.formatQuantity(2.25), '2 ¼');
      expect(IngredientText.formatQuantity(1 / 3), '⅓');
      expect(IngredientText.formatQuantity(1.4), '1,4');
    });
  });
}
