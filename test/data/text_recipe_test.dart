import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/text_recipe.dart';

void main() {
  test('réponse d’IA en Markdown', () {
    final recipe = TextRecipeParser.parse('''
Voici une recette de quiche lorraine traditionnelle :

# Quiche lorraine

Une quiche simple et généreuse, parfaite avec une salade verte.

**Pour 6 personnes** | ⏱️ Préparation : 20 min | 🔥 Cuisson : 40 min

## 🥕 Ingrédients

**Pour la pâte :**
- 250 g de farine
- 125 g de beurre froid
- 1 pincée de sel

**Pour la garniture :**
- 200 g de lardons
- 3 œufs
- 20 cl de crème fraîche

## 👩‍🍳 Préparation

1. **Préparer la pâte** : mélanger la farine et le beurre du bout des doigts.
2. Étaler la pâte dans un moule de 24 cm.
3. Faire revenir les lardons 5 minutes.
4. Battre les œufs et la crème, verser sur la pâte.
5. Cuire 40 minutes à 180 °C.

## 💡 Astuces

- Ajoutez une pincée de muscade.
- Se congèle très bien.

Bon appétit ! 😊
''');
    expect(recipe.title, 'Quiche lorraine');
    expect(recipe.description, contains('salade verte'));
    expect(recipe.servings, 6);
    expect(recipe.prepMinutes, 20);
    expect(recipe.cookMinutes, 40);
    expect(recipe.ingredients, [
      'Pour la pâte :',
      '- 250 g de farine',
      '- 125 g de beurre froid',
      '- 1 pincée de sel',
      'Pour la garniture :',
      '- 200 g de lardons',
      '- 3 œufs',
      '- 20 cl de crème fraîche',
    ]);
    expect(recipe.steps, hasLength(5));
    expect(recipe.steps.first, startsWith('1. Préparer la pâte'));
    expect(recipe.notes, contains('muscade'));
    expect(recipe.notes, contains('congèle'));
  });

  test('texte sans Markdown, rubriques suivies de « : »', () {
    final recipe = TextRecipeParser.parse('''
Crêpes de grand-mère
Pour 4 personnes
Temps de préparation : 10 minutes
Temps de cuisson : 1 h

Ingrédients :
250 g de farine
4 œufs
50 cl de lait

Préparation :
Mettre la farine dans un saladier.
Ajouter les œufs puis le lait petit à petit.
Laisser reposer 1 heure.
''');
    expect(recipe.title, 'Crêpes de grand-mère');
    expect(recipe.servings, 4);
    expect(recipe.prepMinutes, 10);
    expect(recipe.cookMinutes, 60);
    expect(recipe.ingredients, ['250 g de farine', '4 œufs', '50 cl de lait']);
    expect(recipe.steps, hasLength(3));
    expect(recipe.description, isEmpty);
  });

  test('« Préparation : 15 min » n’ouvre pas la rubrique des étapes', () {
    final recipe = TextRecipeParser.parse('''
Salade de lentilles
Préparation : 15 min
Ingrédients
200 g de lentilles
Étapes
Cuire les lentilles 20 minutes.
''');
    expect(recipe.prepMinutes, 15);
    expect(recipe.ingredients, ['200 g de lentilles']);
    expect(recipe.steps, ['Cuire les lentilles 20 minutes.']);
  });

  test('une ligne d’ingrédient n’est pas prise pour des portions', () {
    final recipe = TextRecipeParser.parse('''
## Ingrédients (pour 8 parts)
- 2 portions de fromage fondu
- 1 pâte feuilletée
''');
    expect(recipe.servings, 8);
    expect(recipe.ingredients, [
      '- 2 portions de fromage fondu',
      '- 1 pâte feuilletée',
    ]);
  });

  test('rendement en pièces', () {
    final recipe = TextRecipeParser.parse('''
Sablés au beurre
Pour environ 30 sablés

Ingrédients
200 g de farine
''');
    expect(recipe.servings, 30);
    expect(recipe.servingsUnit, 'sablés');
  });

  test('étapes avec parties', () {
    final recipe = TextRecipeParser.parse('''
# Bûche
## Ingrédients
- 4 œufs
## Préparation
### Biscuit
1. Monter les blancs.
### Montage
2. Rouler le biscuit.
''');
    expect(recipe.steps, [
      'Biscuit :',
      '1. Monter les blancs.',
      'Montage :',
      '2. Rouler le biscuit.',
    ]);
  });

  test('sans rubriques : quantités en ingrédients, phrases en étapes', () {
    final recipe = TextRecipeParser.parse('''
Pâtes au pesto
200 g de pâtes
2 c. à soupe de pesto
Faire cuire les pâtes dans l’eau bouillante salée.
Égoutter et mélanger avec le pesto.
''');
    expect(recipe.title, 'Pâtes au pesto');
    expect(recipe.ingredients, ['200 g de pâtes', '2 c. à soupe de pesto']);
    expect(recipe.steps, hasLength(2));
  });
}
