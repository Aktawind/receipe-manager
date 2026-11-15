import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_export.dart';
import 'package:recettes/domain/step_text.dart';

const _words = (
  ingredients: 'Ingrédients',
  steps: 'Préparation',
  notes: 'Notes',
  source: 'Source',
  or: 'ou',
);

void main() {
  final recipe = Recipe(
    id: 'q',
    title: 'Quiche lorraine',
    description: 'La vraie, sans fromage.',
    source: 'https://exemple.fr/quiche',
    notes: 'Meilleure tiède.',
    servings: 6,
    ingredients: IngredientText.parseList(
      'Pâte :\n'
      '250 g de farine\n'
      '125 g de beurre | margarine\n'
      'Garniture :\n'
      '200 g de lardons\n'
      '3 œufs\n'
      'muscade (facultatif)',
    ),
    steps: StepText.parse(
      'Pâte :\nMélanger la farine et le beurre.\n\n'
      'Garniture :\nBattre les œufs.\n\nCuire 35 min.',
    ),
    createdAt: DateTime(2026, 11, 15),
    updatedAt: DateTime(2026, 11, 15),
  );

  test('le texte à partager, pour les portions choisies', () {
    final text = RecipeExport.text(
      recipe,
      title: recipe.title,
      factor: 2,
      info: ['12 pers.', 'Préparation 20 min'],
      words: _words,
    );
    expect(
      text,
      startsWith(
        'Quiche lorraine\n12 pers. · Préparation 20 min\n\n'
        'La vraie, sans fromage.\n\nINGRÉDIENTS\nPâte :\n',
      ),
    );
    // Quantités doublées, substitut lisible (pas de « | »), facultatif gardé.
    expect(text, contains('- 500 g de farine'));
    expect(text, contains('- 250 g de beurre (ou margarine)'));
    expect(text, contains('- 6 œufs'));
    expect(text, contains('muscade (facultatif)'));
    expect(text, isNot(contains('|')));
    // Étapes numérotées à la suite, avec leurs parties.
    expect(
      text,
      contains(
        'PRÉPARATION\nPâte :\n1. Mélanger la farine et le beurre.\n'
        'Garniture :\n2. Battre les œufs.',
      ),
    );
    expect(text, contains('3. Cuire 35 min.'));
    expect(
      text,
      endsWith('NOTES\nMeilleure tiède.\n\nSource : https://exemple.fr/quiche'),
    );
  });

  test('une recette presque vide : seulement le titre', () {
    final empty = Recipe(
      id: 'v',
      title: 'Idée',
      createdAt: DateTime(2026, 11, 15),
      updatedAt: DateTime(2026, 11, 15),
    );
    expect(
      RecipeExport.text(
        empty,
        title: 'Idée',
        factor: 1,
        info: const [],
        words: _words,
      ),
      'Idée',
    );
  });
}
