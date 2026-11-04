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

  test(
    'réponse d’IA réelle : sans titre, « Préparation (15 minutes) », citation',
    () {
      final recipe = TextRecipeParser.parse('''
Voici une délicieuse recette de biscuits (ou petits gâteaux) moelleux à la banane, idéale pour utiliser deux bananes mûres tout en se régalant. Ils ont une texture ultra-fondante, parfaite pour le goûter !
Ingrédients
 * 2 bananes mûres (bien tachetées)
 * 1 œuf
 * 50 g de sucre (ou de sucre roux/vergeoise pour un goût caramélisé)
 * 40 g de beurre fondu (ou d'huile de coco)
 * 120 g de farine (ou un mélange farine / poudre d'amandes pour plus de moelleux)
 * 1 cuillère à café de levure chimique
 * 1 pincée de sel
 * Optionnel : Une pincée de cannelle, une poignée de pépites de chocolat ou de noix concassées.
Préparation (15 minutes)
 * Préchauffer le four à 180 °C (chaleur tournante de préférence) et tapisser une plaque de cuisson de papier sulfurisé.
 * Écraser les bananes : Dans un saladier, réduisez les deux bananes en purée bien lisse à l'aide d'une fourchette.
 * Mélanger les liquides : Ajoutez l'œuf, le sucre et le beurre fondu à la purée de bananes. Mélangez bien au fouet.
 * Ajouter les secs : Incorporez la farine, la levure chimique, la pincée de sel et la cannelle (si vous en mettez). Mélangez délicatement avec une spatule juste ce qu'il faut pour obtenir une pâte homogène (ne pas trop travailler la pâte).
 * Façonner les biscuits : La pâte obtenue est assez souple. Déposez des petits tas de pâte à l'aide d'une cuillère à soupe sur la plaque de cuisson, en espaçant bien chaque biscuit (ils vont un peu s'étaler).
 * Cuisson : Enfournez pour 12 à 15 minutes. Les bords doivent être légèrement dorés et le centre doit rester bien moelleux.
> 💡 Le petit plus : Si vous aimez le chocolat, ces biscuits se marient à merveille avec des pépites de chocolat noir (notamment du chocolat à 70 % de cacao) ou de petits morceaux de noix.
> 
Bon appétit ! Veux-tu une autre idée de gourmandise à faire avec des bananes ?
''');
      expect(recipe.title, 'Biscuits moelleux à la banane');
      expect(recipe.description, contains('texture ultra-fondante'));
      expect(recipe.prepMinutes, 15);
      expect(recipe.ingredients, hasLength(8));
      expect(recipe.steps, hasLength(6));
      expect(recipe.steps.first, contains('Préchauffer le four'));
      expect(recipe.steps.last, contains('Enfournez pour 12 à 15 minutes'));
      expect(
        recipe.notes,
        startsWith('Le petit plus : Si vous aimez le chocolat'),
      );
      expect(recipe.notes, isNot(contains('Bon appétit')));
    },
  );

  test('réponse d’IA en fiche : titre ###, infos sur deux lignes, image', () {
    final recipe = TextRecipeParser.parse('''
Je te propose une recette de petits biscuits moelleux à la banane, parfaits pour le goûter ou le petit-déjeuner ! 🍌

Ils sont naturellement sucrés grâce aux bananes, sans avoir besoin de beaucoup de sucre.

![Galletitas de avena y banana](https://images.openai.com/static-rsc-4/bwAtTe5c5HjE?purpose=fullsize)

### 🍌 Biscuits moelleux à la banane

PRÉPARATION

10 min

CUISSON

15 min

QUANTITÉ

12 biscuits

### Ingrédients

* 2 bananes bien mûres

* 150 g de farine

* 50 g de flocons d'avoine

* 40 g de beurre fondu

* 40 g de sucre roux

* 1 œuf

* ½ cuillère à café de bicarbonate alimentaire

* 1 cuillère à café de cannelle (facultatif)

* 1 pincée de sel

* Quelques pépites de chocolat (facultatif)

### Préparation

* Préchauffe ton four à 180 °C.

* Écrase les deux bananes dans un saladier à l'aide d'une fourchette.

* Ajoute l'œuf, le beurre fondu et le sucre. Mélange.

* Incorpore la farine, les flocons d'avoine, le bicarbonate, le sel et la cannelle.

* Ajoute éventuellement quelques pépites de chocolat.

* Dépose des petits tas de pâte sur une plaque recouverte de papier cuisson.

* Aplatis légèrement chaque biscuit avec le dos d'une cuillère.

* Enfourne pendant 12 à 15 minutes, jusqu'à ce que les bords soient légèrement dorés.

### Mes petites astuces

* Pour des biscuits plus croustillants : prolonge la cuisson de 2 à 3 minutes.

* Pour des biscuits plus gourmands : ajoute des noix concassées ou du chocolat noir.

* Pour une version plus saine : remplace le sucre par 20 g de miel ou supprime-le complètement.

Petit-déjeuner et goûter

Ils se conservent 3 à 4 jours dans une boîte hermétique.

Mon conseil : avec les deux bananes bien mûres, les flocons d'avoine et quelques pépites de chocolat, tu obtiens de délicieux petits biscuits façon banana bread ! 😋
''');
    expect(recipe.title, 'Biscuits moelleux à la banane');
    expect(recipe.description, contains('naturellement sucrés'));
    expect(recipe.imageUrl?.host, 'images.openai.com');
    expect(recipe.prepMinutes, 10);
    expect(recipe.cookMinutes, 15);
    expect(recipe.servings, 12);
    expect(recipe.servingsUnit, 'biscuits');
    expect(recipe.ingredients, hasLength(10));
    expect(recipe.steps, hasLength(8));
    expect(recipe.steps.first, contains('Préchauffe ton four'));
    expect(recipe.notes, contains('plus croustillants'));
    expect(recipe.notes, contains('se conservent 3 à 4 jours'));
    expect(recipe.notes, contains('Mon conseil'));
  });
}
