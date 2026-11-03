import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_scaling.dart';
import 'package:recettes/domain/ingredient_text.dart';

ScaledIngredient scaled(String text, double factor) =>
    IngredientScaling.scaleLine(IngredientText.parse(text, id: 'x'), factor);

String amount(String text, double factor) =>
    IngredientText.formatAmount(scaled(text, factor).scaledLine);

void main() {
  test('facteur entre portions', () {
    expect(IngredientScaling.factor(4, 6), 1.5);
    expect(IngredientScaling.factor(0, 6), 1);
  });

  test('sans changement, rien ne bouge', () {
    final s = scaled('3 œufs', 1);
    expect(s.quantity, 3);
    expect(s.notice, isNull);
  });

  group('arrondis', () {
    test('au gramme sur la balance', () {
      expect(amount('200 g de farine', 1.5), '300 g');
      expect(amount('125 g de beurre', 1 / 3), '42 g');
      expect(amount('7 g de sel fin', 0.5), '3 ½ g');
      expect(amount('750 g de pommes de terre', 1.5), '1130 g');
      expect(amount('330 g de sucre', 1.5), '495 g');
    });

    test('litres et kilos à 50 g près', () {
      expect(amount('1 L de lait', 1.5), '1 ½ L');
      expect(amount('1,2 kg de bœuf', 1 / 3), '0,4 kg');
    });

    test('cuillères au quart ou au tiers', () {
      expect(amount('1 c. à soupe de miel', 1.5), '1 ½ c. à soupe');
      expect(amount('2 c. à café de cannelle', 1 / 3), '⅔ c. à café');
      expect(amount('1 c. à café de vanille', 1 / 6), '¼ c. à café');
      expect(amount('3 tasses de riz', 0.5), '1 ½ tasse');
    });

    test('œufs et sachets entiers, signalés', () {
      final eggs = scaled('3 œufs', 1.5);
      expect(eggs.quantity, 5);
      expect(eggs.exact, 4.5);
      expect(eggs.notice, ScaleNotice.rounded);
      expect(scaled('2 jaunes d\'œufs', 0.25).quantity, 1);
      expect(scaled('1 sachet de sucre vanillé', 1.5).quantity, 2);
      expect(scaled('1 boîte de tomates concassées', 0.5).quantity, 1);
      expect(scaled('1 rouleau de pâte feuilletée', 1.5).quantity, 2);
    });

    test('quatre œufs pour six au lieu de quatre : pas d’alerte', () {
      final eggs = scaled('4 œufs', 1.5);
      expect(eggs.quantity, 6);
      expect(eggs.notice, isNull);
    });

    test('fruits et légumes à la demie', () {
      expect(amount('1 citron', 0.5), '½');
      expect(amount('3 oignons', 1.5), '4 ½');
      expect(amount('2 gousses d\'ail', 1.5), '3 gousses');
      expect(amount('24 blinis', 1.5), '36');
    });
  });

  group('avertissements', () {
    test('levure et bicarbonate', () {
      expect(
        scaled('1 sachet de levure chimique', 2).notice,
        ScaleNotice.leavening,
      );
      expect(
        scaled('20 g de levure de boulanger', 1.5).notice,
        ScaleNotice.leavening,
      );
      expect(
        scaled('1 c. à café de bicarbonate', 2).notice,
        ScaleNotice.leavening,
      );
    });

    test('sel, poivre et épices', () {
      expect(scaled('1 c. à café de sel', 2).notice, ScaleNotice.seasoning);
      expect(
        scaled('2 pincées de piment d\'Espelette', 2).notice,
        ScaleNotice.seasoning,
      );
      expect(scaled('1 c. à soupe de curry', 2).notice, ScaleNotice.seasoning);
      // « Céleri » ou « salade » ne sont pas du sel.
      expect(scaled('200 g de céleri', 2).notice, isNull);
      expect(scaled('1 salade', 2).notice, isNull);
    });

    test('à ajuster à la main', () {
      expect(scaled('2 à 3 œufs', 2).notice, ScaleNotice.manual);
      expect(scaled('Un peu de lait', 2).notice, ScaleNotice.manual);
      expect(scaled('Sel, poivre', 2).notice, isNull);
      expect(scaled('Huile pour la friture', 2).notice, isNull);
    });

    test('titres de groupe intacts', () {
      final s = scaled('Pour la pâte :', 2);
      expect(s.line.isSection, isTrue);
      expect(s.notice, isNull);
    });
  });
}
