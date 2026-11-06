import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/text_recipe.dart';
import 'package:recettes/domain/ocr_layout.dart';

/// Une ligne lue : position en pixels, largeur estimée d'après le texte.
OcrLine l(
  String text,
  double left,
  double top, {
  int block = 0,
  double height = 20,
  double? width,
}) => OcrLine(
  text,
  left: left,
  top: top,
  width: width ?? text.length * height * 0.45,
  height: height,
  block: block,
);

String read(List<OcrLine> page) {
  final text = OcrLayout.recipeText([page]);
  printOnFailure(text);
  return text;
}

void main() {
  test('titre, temps en pictogrammes, ingrédients et étapes sans rubrique '
      '(tartelettes)', () {
    final text = read([
      l('DESSERTS', 60, 20),
      l('Tartelettes au', 60, 90, height: 48, block: 1),
      l('chocolat blanc', 60, 145, height: 48, block: 1),
      l('POUR 6 TARTELETTES', 60, 230, block: 2),
      l('20 MIN 15 MIN 2 H', 60, 270, block: 3),
      l('6 fonds de tartelettes', 60, 330, block: 4),
      l('200 g de chocolat blanc', 60, 355, block: 4),
      l('20 cl de crème liquide', 60, 380, block: 4),
      l('1 citron vert', 60, 405, block: 4),
      l('Faites chauffer la crème dans une casserole.', 60, 470, block: 5),
      l('Versez-la sur le chocolat haché et mélangez.', 60, 495, block: 5),
      l('Garnissez les fonds de tartelettes et lais-', 60, 545, block: 6),
      l('sez prendre 2 h au réfrigérateur.', 60, 570, block: 6),
      l('42', 60, 960, block: 7),
    ]);
    expect(text, startsWith('# Tartelettes au chocolat blanc'));
    expect(text, contains('POUR 6 TARTELETTES'));
    expect(text, contains('Préparation : 20 min'));
    expect(text, contains('Cuisson : 15 min'));
    expect(text, contains('Repos : 120 min'));
    expect(text, contains('- 200 g de chocolat blanc'));
    expect(text, contains('- 1 citron vert'));
    expect(
      text,
      contains(
        '2. Garnissez les fonds de tartelettes et laissez prendre 2 h au '
        'réfrigérateur.',
      ),
    );
    expect(text, isNot(contains('DESSERTS')));
    expect(text, isNot(contains('42')));

    final recipe = TextRecipeParser.parse(text);
    expect(recipe.title, 'Tartelettes au chocolat blanc');
    expect(recipe.ingredients, hasLength(4));
    expect(recipe.steps, hasLength(2));
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 15);
  });

  test('ingrédients à gauche, préparation à droite (poulet impérial)', () {
    final text = read([
      l('POULET IMPÉRIAL', 60, 40, height: 50),
      l('Pour 4 personnes', 60, 130, block: 1),
      l('Préparation : 20 min', 60, 155, block: 1),
      l('Cuisson : 35 min', 60, 180, block: 1),
      l('Ingrédients', 60, 240, block: 2),
      l('4 cuisses de poulet', 60, 270, block: 3),
      l('2 oignons', 60, 295, block: 3),
      l('1 c. à soupe de sauce soja', 60, 320, block: 3),
      l('Sel, poivre', 60, 345, block: 3),
      l('Préparation', 520, 240, block: 4),
      l('1. Émincez les oignons et faites-les', 520, 270, block: 5),
      l('revenir dans un peu d’huile.', 520, 295, block: 5),
      l('2. Ajoutez les cuisses de poulet et la', 520, 320, block: 5),
      l('sauce soja. Laissez cuire 35 min.', 520, 345, block: 5),
    ]);
    expect(text, startsWith('# Poulet impérial'));
    expect(
      text,
      contains(
        '## Ingrédients\n- 4 cuisses de poulet\n- 2 oignons\n'
        '- 1 c. à soupe de sauce soja\n- Sel, poivre',
      ),
    );
    expect(
      text,
      contains(
        '1. Émincez les oignons et faites-les revenir dans un peu d’huile.\n'
        '2. Ajoutez les cuisses de poulet et la sauce soja. Laissez cuire '
        '35 min.',
      ),
    );
  });

  test('légendes sous les photos : nom puis quantité (dinde)', () {
    final text = read([
      l('Dinde & tomates aux herbes', 60, 40, height: 46),
      l('escalope de dinde', 60, 300, block: 1),
      l('800 g', 60, 325, block: 2),
      l('tomates cerises', 360, 300, block: 3),
      l('500 g', 360, 325, block: 4),
      l('romarin', 660, 300, block: 5),
      l('× 2 brins', 660, 325, block: 6),
      l(
        'Coupez la dinde en morceaux et faites-la dorer 5 min.',
        60,
        450,
        block: 7,
      ),
      l(
        'Ajoutez les tomates et le romarin, laissez cuire 10 min.',
        60,
        475,
        block: 7,
      ),
    ]);
    expect(text, contains('- 800 g escalope de dinde'));
    expect(text, contains('- 500 g tomates cerises'));
    expect(text, contains('- 2 brins romarin'));
    expect(text, contains('1. Coupez la dinde en morceaux'));
  });

  test('quantité au-dessus du nom (boudin aux pommes)', () {
    final text = read([
      l('Boudin aux pommes', 60, 40, height: 46),
      l('4', 100, 300, block: 1, width: 12),
      l('Boudins noirs', 60, 325, block: 2),
      l('3', 400, 300, block: 3, width: 12),
      l('pommes', 380, 325, block: 4),
      l('Beurre 30 g', 660, 300, block: 5),
      l(
        'Poêlez les boudins 10 min, ajoutez les pommes en quartiers.',
        60,
        450,
        block: 6,
      ),
    ]);
    expect(text, contains('- 4 Boudins noirs'));
    expect(text, contains('- 3 pommes'));
    expect(text, contains('- 30 g Beurre'));
    expect(text, isNot(contains('\n4\n')));
  });

  test('ingrédients à la suite, séparés par des « + » (gâteau)', () {
    final text = read([
      l('Gâteau sans farine aux marrons', 60, 40, height: 46),
      l('500 g de crème de marrons + 3 œufs + 100 g de', 60, 140, block: 1),
      l('beurre + 1 pincée de sel', 60, 165, block: 1),
      l(
        'Préchauffez le four à 180 °C. Mélangez le tout et faites',
        60,
        230,
        block: 2,
      ),
      l('cuire 25 min.', 60, 255, block: 2),
    ]);
    expect(
      text,
      contains(
        '- 500 g de crème de marrons\n- 3 œufs\n- 100 g de beurre\n'
        '- 1 pincée de sel',
      ),
    );
    expect(text, contains('1. Préchauffez le four à 180 °C.'));
  });

  test('gros numéros d’étapes sur deux colonnes (entrecôte)', () {
    final text = read([
      l('Entrecôte grillée bordelaise', 60, 40, height: 46),
      l('2 entrecôtes', 60, 130, block: 1),
      l('3 échalotes', 60, 155, block: 1),
      l('1', 60, 300, block: 2, height: 40, width: 20),
      l('Ciselez les échalotes et faites-les', 100, 300, block: 3),
      l('fondre dans le vin rouge.', 100, 325, block: 3),
      l('2', 60, 420, block: 4, height: 40, width: 20),
      l('Faites griller les entrecôtes 3 min', 100, 420, block: 5),
      l('de chaque côté.', 100, 445, block: 5),
      l('3', 540, 300, block: 6, height: 40, width: 20),
      l('Nappez de sauce et servez aussitôt.', 580, 300, block: 7),
    ]);
    expect(
      text,
      contains(
        '1. Ciselez les échalotes et faites-les fondre dans le vin rouge.\n'
        '2. Faites griller les entrecôtes 3 min de chaque côté.\n'
        '3. Nappez de sauce et servez aussitôt.',
      ),
    );
  });

  test('page à l’envers remise droite', () {
    // Une page tournée de 180° : coins inversés, angle de 180°.
    RawOcrLine flipped(String text, double left, double top, double height) {
      final width = text.length * height * 0.45;
      const size = 1000.0;
      final x0 = size - left;
      final y0 = size - top;
      return RawOcrLine(text, [
        (x: x0, y: y0),
        (x: x0 - width, y: y0),
        (x: x0 - width, y: y0 - height),
        (x: x0, y: y0 - height),
      ], angle: 180);
    }

    final lines = OcrLayout.upright([
      flipped('Empanadas de porc', 60, 40, 46),
      flipped('300 g de porc haché', 60, 140, 20),
      flipped('1 oignon', 60, 165, 20),
      flipped('Faites revenir le porc avec l’oignon émincé.', 60, 230, 20),
    ]);
    final text = OcrLayout.recipeText([lines]);
    expect(text, startsWith('# Empanadas de porc'));
    expect(text, contains('- 300 g de porc haché\n- 1 oignon'));
    expect(text, contains('1. Faites revenir le porc'));
  });

  test('légende sur deux lignes, quantité avec précision (saltimboccas)', () {
    final text = read([
      l('Saltimboccas de Pinocchio', 60, 40, height: 46),
      l('Escalopes de veau', 60, 300, block: 1),
      l('fines', 60, 322, block: 1),
      l('x 4 (petites et aplaties)', 60, 350, block: 2),
      l('Jambon cru 4 tranches', 460, 300, block: 3),
      l('Posez une tranche de jambon sur chaque escalope.', 60, 450, block: 4),
    ]);
    expect(text, contains('- 4 Escalopes de veau fines (petites et aplaties)'));
    expect(text, contains('- 4 tranches Jambon cru'));
    expect(text, contains('1. Posez une tranche de jambon'));
  });

  test('groupes d’ingrédients et astuce (bouillon)', () {
    final text = read([
      l('Bouillon de poulet', 60, 40, height: 46),
      l('Ingrédients pour 1,5 litre de bouillon', 60, 130, block: 1),
      l('POUR LE BOUILLON', 60, 170, block: 2),
      l('1 carcasse de poulet', 60, 195, block: 2),
      l('2 carottes', 60, 220, block: 2),
      l('POUR LA GARNITURE', 60, 260, block: 3),
      l('1 bouquet de persil', 60, 285, block: 3),
      l(
        'Mettez la carcasse dans une grande casserole d’eau froide.',
        60,
        340,
        block: 4,
      ),
      l('Portez à ébullition puis laissez frémir 2 h.', 60, 365, block: 4),
      l('Astuce : congelez le bouillon en portions.', 60, 430, block: 5),
    ]);
    expect(
      text,
      contains(
        '\nPour le bouillon :\n- 1 carcasse de poulet\n- 2 carottes\n'
        '\nPour la garniture :\n- 1 bouquet de persil',
      ),
    );
    expect(text, contains('1. Mettez la carcasse'));
    expect(text, contains('## Astuces\nAstuce : congelez le bouillon'));
  });

  test('page sur le côté remise droite', () {
    // Une page tournée d'un quart de tour : (x, y) → (size - y, x).
    RawOcrLine turned(String text, double left, double top, double height) {
      final width = text.length * height * 0.45;
      const size = 1000.0;
      ({double x, double y}) p(double x, double y) => (x: size - y, y: x);
      return RawOcrLine(text, [
        p(left, top),
        p(left + width, top),
        p(left + width, top + height),
        p(left, top + height),
      ], angle: 90);
    }

    final lines = OcrLayout.upright([
      turned('Entrecôte grillée', 60, 40, 46),
      turned('2 entrecôtes', 60, 140, 20),
      turned('3 échalotes', 60, 165, 20),
      turned('Faites griller les entrecôtes de chaque côté.', 60, 230, 20),
    ]);
    final text = OcrLayout.recipeText([lines]);
    expect(text, startsWith('# Entrecôte grillée'));
    expect(text, contains('- 2 entrecôtes\n- 3 échalotes'));
    expect(text, contains('1. Faites griller'));
  });

  test('une page à une colonne, avec rubriques (tarte aux pommes)', () {
    final text = read([
      l('TARTE AUX POMMES', 60, 40, height: 46),
      l('Pour 6 personnes', 60, 120, block: 1),
      l('Préparation : 20 min', 60, 145, block: 1),
      l('Cuisson : 35 min', 60, 170, block: 1),
      l('Ingrédients', 60, 230, block: 2),
      l('1 pâte brisée', 60, 260, block: 3),
      l('6 pommes', 60, 285, block: 3),
      l('5O g de sucre', 60, 310, block: 3),
      l('30 g de beurre', 60, 335, block: 3),
      l('Préparation', 60, 395, block: 4),
      l('Préchauffez le four à 180 °C. Étalez la pâte', 60, 425, block: 5),
      l('dans un moule à tarte et piquez-la avec une', 60, 450, block: 5),
      l('fourchette.', 60, 475, block: 5),
      l('Épluchez les pommes, coupez-les en fines', 60, 515, block: 6),
      l('lamelles et disposez-les sur la pâte.', 60, 540, block: 6),
      l('Saupoudrez de sucre, parsemez de beurre et', 60, 580, block: 7),
      l('enfournez pour 35 minutes.', 60, 605, block: 7),
    ]);
    final recipe = TextRecipeParser.parse(text);
    expect(recipe.title, 'Tarte aux pommes');
    expect(recipe.servings, 6);
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 35);
    expect(recipe.ingredients, [
      '- 1 pâte brisée',
      '- 6 pommes',
      '- 50 g de sucre',
      '- 30 g de beurre',
    ]);
    expect(recipe.steps, hasLength(3));
    expect(recipe.steps.first, endsWith('avec une fourchette.'));
  });
}
