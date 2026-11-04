import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recettes/data/import/web_import.dart';
import 'package:recettes/data/photo_store.dart';
import 'package:recettes/features/recipes/web_import_page.dart';

import '../helpers/test_app.dart';

const _page = '''
<html><head><script type="application/ld+json">
{"@type":"Recipe","name":"Tarte aux pommes","recipeYield":"6",
 "cookTime":"PT35M",
 "recipeIngredient":["1 pâte brisée","4 pommes","50 g de sucre"],
 "recipeInstructions":[{"@type":"HowToStep","text":"Éplucher les pommes."},
   {"@type":"HowToStep","text":"Cuire 35 minutes."}]}
</script></head><body></body></html>''';

MockClient _client() => MockClient((request) async {
  final path = request.url.path;
  if (path == '/tarte') {
    return http.Response.bytes(
      utf8.encode(_page),
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }
  if (path == '/photo.png') {
    return http.Response.bytes(
      [137, 80, 78, 71],
      200,
      headers: {'content-type': 'image/png'},
    );
  }
  if (path == '/vide') {
    return http.Response('<html><body>Rien</body></html>', 200);
  }
  return http.Response('not found', 404);
});

void main() {
  testWidgets('importer une page : aperçu, puis la recette est créée', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [
          webImporterProvider.overrideWithValue(WebImporter(client: _client())),
        ],
      ),
    ))!;
    await app.pump(tester);

    await tester.tap(find.byKey(const ValueKey('web-import-open')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('web-import-url')),
      'Regarde ça : https://cuisine.exemple.fr/tarte !',
    );
    await tester.tap(find.byKey(const ValueKey('web-import-read')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);

    expect(find.text('Tarte aux pommes'), findsOneWidget);
    expect(find.text('3 ingrédients'), findsOneWidget);
    expect(find.text('2 étapes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('web-import-save')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);

    final all = (await tester.runAsync(
      app.services.recipes.getAllWithDetails,
    ))!;
    expect(all, hasLength(1));
    final recipe = all.single;
    expect(recipe.title, 'Tarte aux pommes');
    expect(recipe.source, 'https://cuisine.exemple.fr/tarte');
    expect(recipe.servings, 6);
    expect(recipe.cookMinutes, 35);
    expect(recipe.ingredients.map((l) => l.name), [
      'pâte brisée',
      'pommes',
      'sucre',
    ]);
    expect(recipe.steps, hasLength(2));
  });

  testWidgets('page sans recette : message et saisie à la main', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [
          webImporterProvider.overrideWithValue(WebImporter(client: _client())),
        ],
      ),
    ))!;
    await app.pump(tester);
    await tester.tap(find.byKey(const ValueKey('web-import-open')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('web-import-url')),
      'https://cuisine.exemple.fr/vide',
    );
    await tester.tap(find.byKey(const ValueKey('web-import-read')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('web-import-error')), findsOneWidget);
    expect(find.textContaining('Aucune recette lisible'), findsOneWidget);
    expect(find.byKey(const ValueKey('web-import-by-hand')), findsOneWidget);
  });

  testWidgets('coller le texte d’une recette (réponse d’IA)', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await tester.tap(find.byKey(const ValueKey('web-import-open')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('import-mode-text')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('text-import-field')),
      '''Voici une recette simple :

# Gâteau au yaourt
**Pour 6 personnes** – Préparation : 10 min – Cuisson : 35 min

## Ingrédients
- 1 pot de yaourt
- 3 œufs
- 2 pots de farine

## Préparation
1. Mélanger le yaourt et les œufs.
2. Ajouter la farine, cuire 35 minutes.

## Astuce
Ajoutez un zeste de citron.''',
    );
    await tester.tap(find.byKey(const ValueKey('text-import-read')));
    await settle(tester);
    await tester.ensureVisible(find.text('2 étapes', skipOffstage: false));
    await settle(tester);
    expect(find.text('Gâteau au yaourt'), findsOneWidget);
    expect(find.text('3 ingrédients'), findsOneWidget);
    expect(find.text('2 étapes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('web-import-save')));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
    final recipe = (await tester.runAsync(
      app.services.recipes.getAllWithDetails,
    ))!.single;
    expect(recipe.title, 'Gâteau au yaourt');
    expect(recipe.servings, 6);
    expect(recipe.prepMinutes, 10);
    expect(recipe.cookMinutes, 35);
    expect(recipe.ingredients, hasLength(3));
    expect(recipe.steps, hasLength(2));
    expect(recipe.notes, 'Ajoutez un zeste de citron.');
    expect(recipe.source, isEmpty);
  });

  testWidgets('un texte sans recette : message', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await tester.tap(find.byKey(const ValueKey('web-import-open')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('import-mode-text')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('text-import-field')),
      'Bonjour',
    );
    await tester.tap(find.byKey(const ValueKey('text-import-read')));
    await settle(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('web-import-error'), skipOffstage: false),
    );
    await settle(tester);
    expect(find.textContaining('ni ingrédients ni étapes'), findsOneWidget);
  });

  test('texte partagé : recette ou adresse', () {
    expect(looksLikeRecipeText('https://www.marmiton.org/x'), isFalse);
    expect(
      looksLikeRecipeText(
        'Crêpes\nIngrédients\n250 g de farine\n4 œufs\nMélanger la farine et les œufs, puis cuire à la poêle.',
      ),
      isTrue,
    );
  });

  test('adresse dans un texte partagé', () {
    expect(
      findUrl('Super recette https://www.marmiton.org/recettes/x.aspx.')
          .toString(),
      'https://www.marmiton.org/recettes/x.aspx',
    );
    expect(findUrl('pas d’adresse'), isNull);
  });

  test('photo téléchargée, ou ignorée en cas d’erreur', () async {
    final dir = Directory.systemTemp.createTempSync('photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photos = PhotoStore(dir);
    final importer = WebImporter(client: _client());
    final name = await importer.downloadPhoto(
      Uri.parse('https://cuisine.exemple.fr/photo.png'),
      photos,
    );
    expect(name, endsWith('.png'));
    expect(photos.file(name!).existsSync(), isTrue);
    expect(
      await importer.downloadPhoto(
        Uri.parse('https://cuisine.exemple.fr/absente.jpg'),
        photos,
      ),
      isNull,
    );
  });

  test('erreurs du site', () async {
    final importer = WebImporter(client: _client());
    await expectLater(
      importer.fetch(Uri.parse('https://cuisine.exemple.fr/inconnue')),
      throwsA(
        isA<WebImportException>().having(
          (e) => e.error,
          'error',
          WebImportError.http,
        ),
      ),
    );
    await expectLater(
      importer.fetch(Uri.parse('ftp://exemple.fr/x')),
      throwsA(
        isA<WebImportException>().having(
          (e) => e.error,
          'error',
          WebImportError.invalidUrl,
        ),
      ),
    );
  });
}
