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

  group('texte collé', () {
    test('puces, numéros et cases à cocher sont ignorés', () {
      expect(parse('- 200 g de farine').name, 'farine');
      expect(parse('• 2 œufs').quantity, 2);
      expect(parse('* 1 pincée de sel').unit, 'pincée');
      expect(parse('1. 250 ml de lait').unit, 'ml');
      expect(parse('[ ] 3 pommes').quantity, 3);
      expect(parse('– 100 g de beurre').quantity, 100);
    });

    test('2 œufs n’est pas pris pour un numéro de liste', () {
      final line = parse('2 œufs');
      expect(line.quantity, 2);
      expect(line.name, 'œufs');
    });

    test('titres : gras, ##, deux-points, « Pour la pâte »', () {
      for (final text in [
        '**Pour la pâte**',
        '## Pour la pâte',
        'Pour la pâte :',
        'Pour la pâte',
        '**Pour la pâte :**',
      ]) {
        final line = parse(text);
        expect(line.isSection, isTrue, reason: text);
        expect(line.name, 'Pour la pâte', reason: text);
      }
    });

    test('titre en majuscules, avec ou sans emoji (export Recipe Keeper)', () {
      for (final text in ['🍐 INSERT POIRE', 'MOUSSE CHOCOLAT AU LAIT']) {
        expect(parse(text).isSection, isTrue, reason: text);
      }
      expect(parse('🍐 INSERT POIRE').name, '🍐 INSERT POIRE');
      // Un seul mot, un chiffre ou une phrase ne sont pas des titres.
      for (final text in ['SEL', '2 ŒUFS', 'SEL ET POIVRE.', 'Sel et poivre']) {
        expect(parse(text).isSection, isFalse, reason: text);
      }
    });

    test('remplaçants : ce qui suit « | »', () {
      final line = parse('100 g de beurre | huile de coco, margarine');
      expect(line.name, 'beurre');
      expect(line.quantity, 100);
      expect(line.unit, 'g');
      expect(line.substitutes, 'huile de coco, margarine');
      expect(
        IngredientText.format(line),
        '100 g de beurre | huile de coco, margarine',
      );
      expect(parse('sel | fleur de sel').substitutes, 'fleur de sel');
      expect(parse('2 œufs').substitutes, '');
    });

    test('recette liée : [[Titre]] avec ou sans quantité', () {
      RecipeRef? resolve(String title) => title.toLowerCase() == 'pâte brisée'
          ? (id: 'pate', title: 'Pâte brisée')
          : null;
      final plain = IngredientText.parse(
        '[[pâte brisée]]',
        id: 'x',
        resolveRecipe: resolve,
      );
      expect(plain.linkedRecipeId, 'pate');
      expect(plain.name, 'Pâte brisée');
      expect(plain.quantity, isNull);

      final counted = IngredientText.parse(
        '1 [[Pâte brisée]]',
        id: 'x',
        resolveRecipe: resolve,
      );
      expect(counted.linkedRecipeId, 'pate');
      expect(counted.quantity, 1);

      final weighed = IngredientText.parse(
        '300 g de [[Pâte brisée]]',
        id: 'x',
        resolveRecipe: resolve,
      );
      expect(
        (weighed.quantity, weighed.unit, weighed.name),
        (300, 'g', 'Pâte brisée'),
      );

      // Recette inconnue : un ingrédient ordinaire, sans les crochets.
      final unknown = IngredientText.parse(
        '[[Inconnue]]',
        id: 'x',
        resolveRecipe: resolve,
      );
      expect(unknown.linkedRecipeId, isNull);
      expect(unknown.name, 'Inconnue');

      // Aller-retour : le titre affiché est celui de la recette aujourd'hui.
      expect(
        IngredientText.format(counted, titleOf: (id) => 'Pâte brisée maison'),
        '1 [[Pâte brisée maison]]',
      );
      expect(
        IngredientText.format(weighed, titleOf: (id) => 'Pâte brisée'),
        '300 g de [[Pâte brisée]]',
      );
    });

    test('« Pour 4 personnes » et « pour le service, 2 c. » ne sont pas des titres', () {
      expect(parse('Pour 4 personnes').isSection, isFalse);
      expect(parse('Pour le service, 2 citrons').isSection, isFalse);
    });

    test('« Farine : 200 g » (liste générée)', () {
      final line = parse('- **Farine** : 200 g');
      expect(line.name, 'Farine');
      expect(line.quantity, 200);
      expect(line.unit, 'g');
    });

    test('précision entre parenthèses', () {
      final line = parse('1 oignon (haché finement)');
      expect(line.name, 'oignon');
      expect(line.note, 'haché finement');
    });

    test('cuillères : toutes les écritures', () {
      for (final text in [
        '2 c. à soupe de sucre',
        '2 cuillères à soupe de sucre',
        '2 c.à.s. de sucre',
        '2 c.s. de sucre',
        '2 c.s de sucre',
        '2 cs de sucre',
      ]) {
        final line = parse(text);
        expect(line.unit, 'c. à s.', reason: text);
        expect(line.name, 'sucre', reason: text);
      }
      expect(parse('1 c. à café de sel').unit, 'c. à c.');
    });

    test('fourchette : la ligne est gardée telle quelle', () {
      final line = parse('2 à 3 œufs');
      expect(line.quantity, isNull);
      expect(IngredientText.format(line), '2 à 3 œufs');
      expect(parse('1-2 gousses d’ail').quantity, isNull);
    });

    test('liste complète collée depuis un site', () {
      const pasted = """
Pour la pâte :
- 250 g de farine
- 125 g de beurre froid (en dés)
- 1 pincée de sel

**Pour la garniture**
• 200 g de lardons
• 3 œufs
• 20 cl de crème fraîche
---
Sel, poivre
""";
      final lines = IngredientText.parseList(pasted);
      expect(lines.map((l) => l.isSection), [
        true,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
      ]);
      expect(lines[2].note, 'en dés');
      expect(lines[3].unit, 'pincée');
      expect(lines.last.name, 'Sel');
    });

    test('parseList garde les identifiants déjà connus', () {
      final lines = IngredientText.parseList(
        '2 œufs\n100 g de sucre\n1 citron',
        previousIds: ['a', 'b'],
      );
      expect(lines.map((l) => l.id).take(2), ['a', 'b']);
      expect(lines[2].id, isNot(anyOf('a', 'b')));
    });

    test('affichage de la quantité', () {
      String amount(String text) => IngredientText.formatAmount(parse(text));
      expect(amount('250 g de farine'), '250 g');
      expect(amount('2 gousses d’ail'), '2 gousses');
      expect(amount('1 rouleau de pâte'), '1 rouleau');
      expect(amount('2 rouleaux de pâte'), '2 rouleaux');
      expect(amount('3 c. à soupe d’huile'), '3 c. à soupe');
      expect(amount('3 œufs'), '3');
      expect(amount('½ citron'), '½');
      expect(amount('sel'), '');
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
