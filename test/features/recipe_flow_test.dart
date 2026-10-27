import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  /// Le champ de texte du formulaire repéré par sa clé.
  Finder field(String name) => find.descendant(
    of: find.byKey(ValueKey('field-$name')),
    matching: find.byType(TextField),
  );

  testWidgets('créer une recette en collant ingrédients et préparation', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Nouvelle recette'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Crêpes');
    await scrollTo(tester, field('ingredients'));
    await tester.enterText(field('ingredients'), '''
Pour la pâte :
- 250 g de farine
- 4 œufs
- 2 c. à soupe de sucre
- sel, selon le goût
''');
    await scrollTo(tester, field('steps'));
    await tester.enterText(field('steps'), '''
1. Mélanger la farine et les œufs.
2. Laisser reposer 1 heure.
3. Cuire dans une poêle chaude.
''');
    await scrollTo(tester, field('notes'));
    await tester.enterText(field('notes'), 'Doubler les quantités pour 8.');
    final source = find.byKey(const ValueKey('field-source'));
    await scrollTo(tester, source);
    await tester.enterText(source, 'https://example.org/crepes');
    await tester.pump(const Duration(seconds: 1));

    // Retour à la liste : la recette y est, enregistrée automatiquement.
    await goBack(tester);
    expect(find.text('Crêpes'), findsOneWidget);

    final detail = (await tester.runAsync(() async {
      final saved = (await app.services.recipes.watchRecipes().first).single;
      return app.services.recipes.getRecipe(saved.id);
    }))!;
    expect(detail.ingredients.map((i) => i.isSection), [
      true,
      false,
      false,
      false,
      false,
    ]);
    expect(detail.ingredients[1].quantity, 250);
    expect(detail.ingredients[1].unit, 'g');
    expect(detail.ingredients[3].unit, 'c. à s.');
    expect(detail.ingredients[4].note, 'selon le goût');
    expect(detail.steps.map((s) => s.text), [
      'Mélanger la farine et les œufs.',
      'Laisser reposer 1 heure.',
      'Cuire dans une poêle chaude.',
    ]);
    expect(detail.notes, 'Doubler les quantités pour 8.');
    expect(detail.source, 'https://example.org/crepes');

    // La fiche : titre de groupe, quantités à droite, étapes numérotées.
    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    await scrollTo(tester, find.text('Cuire dans une poêle chaude.'));
    expect(find.text('Pour la pâte'), findsOneWidget);
    expect(find.text('Farine'), findsOneWidget);
    expect(find.text('250 g'), findsOneWidget);
    expect(find.text('2 c. à soupe'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('selon le goût'), findsOneWidget);
    expect(find.text('Mélanger la farine et les œufs.'), findsOneWidget);
    await scrollTo(tester, find.text('SOURCE · SITE WEB'));
    expect(find.text('Doubler les quantités pour 8.'), findsOneWidget);
  });

  testWidgets('la préparation collée garde ses titres de parties', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final id = (await tester.runAsync(() async {
      final created = await app.services.recipes.create();
      await app.services.recipes.save(
        created.copyWith(
          title: 'Entremets',
          prepMinutes: () => 90,
          cookMinutes: () => 25,
          restMinutes: () => 600,
          servings: () => 8,
          steps: const [
            RecipeStep(id: 'a', title: 'Biscuit', text: 'Monter les blancs.'),
            RecipeStep(id: 'b', text: 'Cuire 25 minutes.'),
          ],
        ),
      );
      return created.id;
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Entremets'));
    await settle(tester);
    expect(find.text('Préparation'), findsWidgets);
    expect(find.text('1 h 30'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('10 h'), findsOneWidget);
    expect(
      find.text('Prêt en 12 h environ, dont 10 h de repos'),
      findsOneWidget,
    );
    expect(find.text('8 pers.'), findsOneWidget);

    await scrollTo(tester, find.text('Cuire 25 minutes.'));
    expect(find.text('BISCUIT'), findsOneWidget);

    // Réouvrir l'éditeur : le titre est rendu « Biscuit : » au-dessus de l'étape.
    await tester.tap(find.byTooltip('Modifier'));
    await settle(tester);
    await scrollTo(tester, field('steps'));
    final text = tester.widget<TextField>(field('steps')).controller!.text;
    expect(text, 'Biscuit :\nMonter les blancs.\n\nCuire 25 minutes.');
    expect(id, isNotEmpty);
  });

  testWidgets('une nouvelle recette laissée vide n’est pas gardée', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Nouvelle recette'));
    await settle(tester);
    await goBack(tester);

    final all = await tester.runAsync(app.services.recipes.getAllWithDetails);
    expect(all, isEmpty);
    expect(find.text('Aucune recette pour l\'instant'), findsOneWidget);
  });

  testWidgets('supprimer met à la corbeille, et on peut restaurer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final created = (await tester.runAsync(() async {
      final created = await app.services.recipes.create();
      return app.services.recipes.save(created.copyWith(title: 'Gratin'));
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Gratin'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('Supprimer'));
    await settle(tester);

    expect(find.text('Gratin'), findsNothing);
    // Laisse disparaître le message « … est dans la corbeille ».
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    final trashed = await tester.runAsync(
      () => app.services.recipes.getRecipe(created.id),
    );
    expect(trashed!.isDeleted, isTrue);

    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await tester.tap(find.text('Corbeille'));
    await settle(tester);
    await tester.tap(find.byTooltip('Restaurer'));
    await settle(tester);

    final restored = await tester.runAsync(
      () => app.services.recipes.getRecipe(created.id),
    );
    expect(restored!.isDeleted, isFalse);
  });

  testWidgets('« J’ai fait cette recette » incrémente le compteur', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final created = await app.services.recipes.create();
      await app.services.recipes.save(
        created.copyWith(
          title: 'Soupe',
          ingredients: const [IngredientLine(id: 'i', name: 'poireaux')],
        ),
      );
    });
    await app.pump(tester);

    await tester.tap(find.text('Soupe'));
    await settle(tester);
    expect(find.text('Jamais réalisée'), findsOneWidget);
    await tester.tap(find.text("J'ai fait cette recette"));
    await settle(tester);
    expect(find.text('Réalisée 1 fois'), findsOneWidget);
  });
}
