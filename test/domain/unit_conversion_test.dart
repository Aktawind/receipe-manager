import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_scaling.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/unit_conversion.dart';

String shown(String text, UnitSystem system, {double factor = 1}) {
  final scaled = IngredientScaling.scaleLine(
    IngredientText.parse(text, id: 'x'),
    factor,
    system: system,
  );
  final amount = IngredientText.formatAmount(scaled.scaledLine);
  return scaled.approximate ? '≈ $amount' : amount;
}

void main() {
  group('lecture des unités anglaises', () {
    test('oz, lb, fl oz, tbsp, tsp, cups', () {
      final butter = IngredientText.parse('8 oz butter', id: 'x');
      expect(butter.unit, 'oz');
      expect(butter.name, 'butter');
      expect(IngredientText.parse('1 lb ground beef', id: 'x').unit, 'lb');
      expect(IngredientText.parse('4 fl oz milk', id: 'x').unit, 'fl oz');
      expect(IngredientText.parse('2 tbsp sugar', id: 'x').unit, 'c. à s.');
      expect(IngredientText.parse('1/2 tsp salt', id: 'x').unit, 'c. à c.');
      expect(IngredientText.parse('1 ½ cups flour', id: 'x').unit, 'tasse');
      expect(IngredientText.parse('2 onces de beurre', id: 'x').unit, 'oz');
    });

    test('un mot qui commence comme une unité reste le nom', () {
      expect(IngredientText.parse('2 oignons', id: 'x').unit, '');
      expect(IngredientText.parse('3 lbs', id: 'x').unit, 'lb');
    });
  });

  group('vers le métrique', () {
    test('poids : exact', () {
      expect(shown('8 oz de beurre', UnitSystem.metric), '227 g');
      expect(shown('2 lb de bœuf', UnitSystem.metric), '905 g');
      expect(shown('3 lb de pommes', UnitSystem.metric), '1,35 kg');
    });

    test('tasses : poids estimé si l’ingrédient est connu, sinon volume', () {
      expect(shown('1 tasse de farine', UnitSystem.metric), '≈ 127 g');
      expect(shown('1 tasse de sucre', UnitSystem.metric), '≈ 204 g');
      expect(shown('½ tasse de sucre glace', UnitSystem.metric), '≈ 60 g');
      expect(shown('1 tasse de lait', UnitSystem.metric), '240 ml');
      expect(shown('1 tasse de myrtilles', UnitSystem.metric), '240 ml');
      expect(shown('4 fl oz de crème', UnitSystem.metric), '118 ml');
      expect(shown('5 tasses d\'eau', UnitSystem.metric), '1,2 L');
    });

    test('les cuillères, pièces et grammes restent tels quels', () {
      expect(shown('2 c. à soupe de miel', UnitSystem.metric), '2 c. à soupe');
      expect(shown('3 œufs', UnitSystem.metric), '3');
      expect(shown('200 g de farine', UnitSystem.metric), '200 g');
    });

    test('avec un changement de portions', () {
      expect(
        shown('1 tasse de farine', UnitSystem.metric, factor: 2),
        '≈ 255 g',
      );
    });
  });

  group('vers l’impérial', () {
    test('poids en onces, livres au-delà de 16 oz', () {
      expect(shown('100 g de beurre', UnitSystem.imperial), '3 ½ oz');
      expect(shown('500 g de farine', UnitSystem.imperial), '1 lb');
      expect(shown('1 kg de pommes', UnitSystem.imperial), '2 ¼ lb');
    });

    test('volumes en tasses ou cuillères', () {
      expect(shown('25 cl de lait', UnitSystem.imperial), '1 tasse');
      expect(shown('500 ml de bouillon', UnitSystem.imperial), '2 tasses');
      expect(shown('2 cl de rhum', UnitSystem.imperial), '1 ⅓ c. à soupe');
      expect(shown('5 ml de vanille', UnitSystem.imperial), '1 c. à café');
    });
  });

  group('températures', () {
    String c(String t) =>
        UnitConversion.convertTemperatures(t, TemperatureUnit.celsius);
    String f(String t) =>
        UnitConversion.convertTemperatures(t, TemperatureUnit.fahrenheit);

    test('°F → °C', () {
      expect(
        c('Préchauffer le four à 350°F.'),
        'Préchauffer le four à 175 °C.',
      );
      expect(
        c('Bake at 425 °F for 20 minutes'),
        'Bake at 220 °C for 20 minutes',
      );
      expect(c('Four à 180 °C'), 'Four à 180 °C');
    });

    test('°C → °F, au 25 près pour le four', () {
      expect(f('Enfourner à 180°C'), 'Enfourner à 350 °F');
      expect(f('Cuire 30 min à 200 degrés'), 'Cuire 30 min à 400 °F');
      expect(f('four à 160°'), 'four à 325 °F');
    });

    test('thermostat : la température entre parenthèses', () {
      expect(c('Four th. 6, 30 min'), 'Four th. 6 (180 °C), 30 min');
      expect(c('thermostat 7'), 'thermostat 7 (210 °C)');
      // Déjà précisé : rien n'est ajouté.
      expect(c('th. 6 (180 °C)'), 'th. 6 (180 °C)');
    });

    test('rien d’autre ne bouge', () {
      expect(
        c('Laisser reposer 2 h, puis 3 œufs.'),
        'Laisser reposer 2 h, puis 3 œufs.',
      );
      expect(
        UnitConversion.convertTemperatures('350°F', TemperatureUnit.recipe),
        '350°F',
      );
    });
  });

  group('dimensions des moules', () {
    test('cm ↔ pouces', () {
      expect(
        UnitConversion.convertLengths('un moule de 24 cm', UnitSystem.imperial),
        'un moule de 9 ½ pouces',
      );
      expect(
        UnitConversion.convertLengths('a 9-inch pan', UnitSystem.metric),
        'a 9-inch pan',
      );
      expect(
        UnitConversion.convertLengths('a 9 inch pan', UnitSystem.metric),
        'a 23 cm pan',
      );
      expect(
        UnitConversion.convertLengths('moule de 8"', UnitSystem.metric),
        'moule de 20 cm',
      );
    });
  });
}
