import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/text_recipe.dart';
import 'package:recettes/domain/ocr_text.dart';

void main() {
  test('lignes coupées par la largeur de la page', () {
    expect(
      OcrText.clean(
        'Mélanger la farine et le beurre du bout des\n'
        'doigts jusqu’à obtenir un sable grossier.\n'
        'Ajouter l’œuf.',
      ),
      'Mélanger la farine et le beurre du bout des doigts jusqu’à obtenir '
      'un sable grossier.\nAjouter l’œuf.',
    );
  });

  test('mot coupé en fin de ligne', () {
    expect(
      OcrText.clean('Laisser re-\nposer 1 heure.'),
      'Laisser reposer 1 heure.',
    );
  });

  test('un ingrédient par ligne reste un ingrédient par ligne', () {
    expect(
      OcrText.clean('200 g de farine\nSel\n3 œufs\nune pincée de muscade'),
      '200 g de farine\nSel\n3 œufs\nune pincée de muscade',
    );
  });

  test('confusions de lecture', () {
    expect(OcrText.clean('l00 g de sucre'), '100 g de sucre');
    expect(OcrText.clean('2O cl de lait'), '20 cl de lait');
    expect(OcrText.clean('25O g de beurre'), '250 g de beurre');
    expect(OcrText.clean('• 2 œufs'), '- 2 œufs');
    // Les mots ne sont pas touchés.
    expect(OcrText.clean('Il faut 10 min.'), 'Il faut 10 min.');
    expect(OcrText.clean('Oignons'), 'Oignons');
  });

  test('une page de livre, de la lecture à la recette', () {
    final text = OcrText.clean('''
TARTE AUX POMMES
Pour 6 personnes
Préparation : 20 min
Cuisson : 35 min

Ingrédients
1 pâte brisée
6 pommes
5O g de sucre
30 g de beurre

Préparation
Préchauffez le four à 180 °C. Étalez la pâte
dans un moule à tarte et piquez-la avec une
fourchette.
Épluchez les pommes, coupez-les en fines
lamelles et disposez-les sur la pâte.
Saupoudrez de sucre, parsemez de beurre et
enfournez pour 35 minutes.
''');
    final recipe = TextRecipeParser.parse(text);
    expect(recipe.title, 'Tarte aux pommes');
    expect(recipe.servings, 6);
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 35);
    expect(recipe.ingredients, [
      '1 pâte brisée',
      '6 pommes',
      '50 g de sucre',
      '30 g de beurre',
    ]);
    expect(recipe.steps, hasLength(3));
    expect(recipe.steps.first, endsWith('avec une fourchette.'));
  });
}
