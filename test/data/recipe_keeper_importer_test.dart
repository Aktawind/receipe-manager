import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/import/recipe_keeper_importer.dart';
import 'package:recettes/domain/recipe.dart';

/// Un bloc de l'export Recipe Keeper, tel qu'il est écrit par l'application.
String block({
  required String id,
  String name = 'Recette',
  String favourite = 'False',
  String rating = '3',
  String course = 'Plat',
  List<String> categories = const [],
  List<String> collections = const [],
  String source = '',
  String yieldText = '4 personnes',
  String prep = 'PT10M',
  String cook = 'PT0S',
  List<String> linked = const [],
  String ingredients = '',
  String directions = '',
  String notes = '',
  List<String> photos = const [],
  String extra = '',
}) =>
    '''
    <div class="recipe-details">
        <meta content="$id" itemprop="recipeId">
        <meta content="" itemprop="recipeShareId">
        ${linked.map((l) => '<meta content="$l" itemprop="recipeLinkedRecipeId">').join()}
        <meta content="$favourite" itemprop="recipeIsFavourite">
        <meta content="$rating" itemprop="recipeRating">
        <table>
            <tr>
                <td><img src="images/${id}_0.jpg" class="recipe-photo"/></td>
                <td style="vertical-align:top">
                    <h2 itemprop="name">$name</h2>
                    <div>Plats: <span itemprop="recipeCourse">$course</span></div>
                    <div>Catégories: <span>${categories.join(', ')}</span>
                        ${categories.map((c) => '<meta content="$c" itemprop="recipeCategory">').join()}
                    </div>
                    <div>Les collections: <span></span>
                        ${collections.map((c) => '<meta content="$c" itemprop="recipeCollection">').join()}
                    </div>
                    <div>Source: <span itemprop="recipeSource">$source</span></div>
                    <div>Taille de portion: <span itemprop="recipeYield">$yieldText</span></div>
                    <div>Temps de préparation: <span>x</span>
                        <meta content="$prep" itemprop="prepTime"></div>
                    <div>Temps de cuisson: <span>x</span>
                        <meta content="$cook" itemprop="cookTime"></div>
                    $extra
                </td>
            </tr>
            <tr>
                <td>
                    <h3>Ingrédients</h3>
                    <div class="recipe-ingredients" itemprop="recipeIngredients">$ingredients</div>
                </td>
                <td>
                    <h3>Préparation</h3>
                    <div itemprop="recipeDirections">$directions</div>
                </td>
            </tr>
        </table>
        <h3>Notes</h3>
        <div class="recipe-notes" itemprop="recipeNotes">$notes</div>
        <h3>Photos</h3>
        ${photos.map((f) => '<div class="recipe-photos-div"><img src="images/$f" class="recipe-photos" itemprop=photo0 /></div>').join()}
        <hr />
    </div>''';

String page(List<String> blocks) =>
    '<!DOCTYPE html><html><head></head><body>${blocks.join('\n')}</body></html>';

String ps(List<String> lines) => lines.map((l) => '<p>$l</p>').join('\n');

final jpeg = [1, 2, 3];

void main() {
  final now = DateTime(2026, 10, 28, 8);

  RecipeKeeperExport read(
    List<String> blocks, [
    Set<String> images = const {},
  ]) => RecipeKeeperImporter.parse(
    page(blocks),
    images: {for (final name in images) name: jpeg},
    now: now,
  );

  test('une recette simple : tout est repris', () {
    final export = read(
      [
        block(
          id: 'aaaa-1',
          name: 'Aiguillettes de canard en sauce',
          favourite: 'True',
          course: 'Plat',
          categories: ['Viandes'],
          collections: ['Automne', 'Été'],
          source: 'Page 32',
          yieldText: '2 personnes ',
          prep: 'PT5M',
          cook: 'PT1H15M',
          ingredients: ps([
            '1 magret de canard coupé en aiguillettes',
            '30 ml de vinaigre balsamique ',
            '2 c.s. de sucre ',
            '1 c.c. de moutarde',
          ]),
          directions: ps([
            'Faire dorer les aiguillettes dans une poêle.',
            'Une fois colorée, retirer la viande.',
            '',
            'Déglacer la poêle avec le sucre.',
          ]),
          notes: ps(['Un régal !', 'A accompagner de riz']),
          photos: ['aaaa-1_0.jpg'],
        ),
      ],
      {'aaaa-1_0.jpg'},
    );

    expect(export.issues, isEmpty);
    final r = export.recipes.single;
    expect(r.id, 'aaaa-1');
    expect(r.title, 'Aiguillettes de canard en sauce');
    expect(r.servings, 2);
    expect(r.prepMinutes, 5);
    expect(r.cookMinutes, 75);
    expect(r.isFavorite, isTrue);
    expect(r.rating, isNull, reason: 'les étoiles ne sont pas reprises');
    expect(r.course, 'Plat');
    expect(r.category, 'Viandes');
    expect(r.collections, ['Automne', 'Été']);
    expect(r.source, 'Page 32');
    expect(r.notes, 'Un régal !\nA accompagner de riz');
    expect(r.mainPhoto, 'aaaa-1_0.jpg');
    expect(r.createdAt, now);

    expect(r.ingredients.map((i) => i.name), [
      'magret de canard coupé en aiguillettes',
      'vinaigre balsamique',
      'sucre',
      'moutarde',
    ]);
    expect(r.ingredients[1].quantity, 30);
    expect(r.ingredients[1].unit, 'ml');
    expect(r.ingredients[2].unit, 'c. à s.');
    expect(r.ingredients[3].unit, 'c. à c.');
    expect(r.steps.map((s) => s.text), [
      'Faire dorer les aiguillettes dans une poêle.',
      'Une fois colorée, retirer la viande.',
      'Déglacer la poêle avec le sucre.',
    ]);
    expect(export.photos.keys, ['aaaa-1_0.jpg']);
  });

  test('titres de groupes en gras, avec ou sans « : »', () {
    final export = read([
      block(
        id: 'b',
        ingredients: ps([
          '<b>Pour la purée </b><b><i>(à faire la veille)</i></b><b> :</b>',
          '3 poires',
          '',
          '<b>Pour la dacquoise</b>',
          '92 g de poudre de noisettes',
        ]),
      ),
    ]);
    final lines = export.recipes.single.ingredients;
    expect(lines.map((l) => l.isSection), [true, false, true, false]);
    expect(lines.first.name, 'Pour la purée (à faire la veille)');
    expect(lines[2].name, 'Pour la dacquoise');
    expect(lines[3].quantity, 92);
  });

  test('« _A tester » devient le statut, pas une catégorie', () {
    final export = read([
      block(id: 'a', categories: ['_A tester']),
      block(id: 'b', categories: ['_A tester', 'Gâteaux']),
      block(id: 'c', categories: ['Gâteaux']),
    ]);
    final [a, b, c] = export.recipes;
    expect(a.status, RecipeStatus.toTest);
    expect(a.category, '');
    expect(b.status, RecipeStatus.toTest);
    expect(b.category, 'Gâteaux');
    expect(c.status, isNull);
  });

  test('portions : « 12 blinis » est un nombre avec son unité', () {
    final export = read([
      block(id: 'a', yieldText: '15 biscuits', notes: ps(['Délicieux'])),
      block(id: 'b', yieldText: '4'),
      block(id: 'c', yieldText: ''),
      block(id: 'd', yieldText: '6 portions'),
      block(id: 'e', yieldText: 'Une dizaine'),
      block(id: 'f', yieldText: '4 personnes '),
      block(id: 'g', yieldText: '1 cake'),
    ]);
    final [a, b, c, d, e, f, g] = export.recipes;
    expect((a.servings, a.servingsUnit), (15, 'biscuits'));
    expect(a.notes, 'Délicieux');
    expect((b.servings, b.servingsUnit), (4, ''));
    expect(c.servings, isNull);
    expect(c.notes, '');
    expect((d.servings, d.servingsUnit), (6, ''));
    expect(e.servings, isNull);
    expect(e.notes, 'Quantité : Une dizaine');
    expect((f.servings, f.servingsUnit), (4, ''));
    expect((g.servings, g.servingsUnit), (1, 'cake'));
  });

  test('temps : PT0S est absent, PT2H vaut 120 minutes', () {
    final export = read([block(id: 'a', prep: 'PT2H', cook: 'PT0S')]);
    expect(export.recipes.single.prepMinutes, 120);
    expect(export.recipes.single.cookMinutes, isNull);
  });

  test('photos supplémentaires, et photo absente du fichier signalée', () {
    final export = read(
      [
        block(
          id: 'a',
          name: 'Tarte',
          photos: ['a_0.jpg', 'a_1.jpg', 'a_2.jpg'],
        ),
      ],
      {'a_0.jpg', 'a_1.jpg'},
    );
    final r = export.recipes.single;
    expect(r.mainPhoto, 'a_0.jpg');
    expect(r.extraPhotos, ['a_1.jpg']);
    expect(export.issues.single.recipeTitle, 'Tarte');
    expect(export.issues.single.message, contains('a_2.jpg'));
  });

  test('recettes liées, renvois [recipe:…] et valeurs nutritionnelles', () {
    final export = read([
      block(id: 'pate', name: 'Pâte brisée'),
      block(
        id: 'tarte',
        linked: ['pate'],
        ingredients: ps(['150 g de [recipe:Gianduja]']),
        notes: ps(['Avec la [recipe:Pâte brisée]']),
        extra: '''
          <meta content="1 portion" itemprop="recipeNutServingSize">
          <meta content="140" itemprop="recipeNutCalories">
          <meta content="6" itemprop="recipeNutProtein">''',
      ),
    ]);
    final tarte = export.recipes.last;
    expect(tarte.linkedRecipeIds, ['pate']);
    expect(tarte.ingredients.single.name, 'Gianduja');
    expect(tarte.notes, startsWith('Avec la Pâte brisée'));
    expect(
      tarte.notes,
      contains('Portion : 1 portion · Calories : 140 · Protéines : 6'),
    );
  });

  test('un identifiant en double dans le fichier n’est lu qu’une fois', () {
    final export = read([
      block(id: 'a', name: 'Première'),
      block(id: 'a', name: 'Seconde'),
    ]);
    expect(export.recipes.map((r) => r.title), ['Première']);
  });

  test('read : ZIP complet avec dossier images', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'recipes.html',
          page([
            block(id: 'x', name: 'Soupe', photos: ['x_0.jpg']),
          ]),
        ),
      )
      ..addFile(ArchiveFile.bytes('images/x_0.jpg', jpeg))
      ..addFile(ArchiveFile.bytes('images/y_0.jpg', jpeg));
    final export = RecipeKeeperImporter.read(
      ZipEncoder().encode(archive),
      now: now,
    );
    expect(export.recipes.single.title, 'Soupe');
    expect(export.photos.keys, [
      'x_0.jpg',
    ], reason: 'photos inutilisées ignorées');
  });

  test('read : un autre ZIP ou un fichier quelconque est refusé', () {
    final other = Archive()
      ..addFile(ArchiveFile.string('recettes.json', jsonEncode({})));
    expect(
      () => RecipeKeeperImporter.read(ZipEncoder().encode(other)),
      throwsFormatException,
    );
    expect(() => RecipeKeeperImporter.read([1, 2, 3]), throwsFormatException);
  });
}
