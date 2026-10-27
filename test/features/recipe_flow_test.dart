import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('créer une recette, la retrouver et l’ouvrir', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Nouvelle recette'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Titre'), 'Crêpes');
    final ingredient = find.widgetWithText(TextField, 'ex. 200 g de farine');
    await scrollTo(tester, ingredient);
    await tester.enterText(ingredient, '250 g de farine');
    final step = find.widgetWithText(TextField, 'Étape 1');
    await scrollTo(tester, step);
    await tester.enterText(step, 'Mélanger.');
    await tester.pump(const Duration(seconds: 1));

    // Retour à la liste : la recette y est, enregistrée automatiquement.
    await goBack(tester);
    expect(find.text('Crêpes'), findsOneWidget);

    final detail = (await tester.runAsync(() async {
      final saved = (await app.services.recipes.watchRecipes().first).single;
      return app.services.recipes.getRecipe(saved.id);
    }))!;
    expect(detail.ingredients.single.quantity, 250);
    expect(detail.ingredients.single.unit, 'g');
    expect(detail.steps.single.text, 'Mélanger.');

    await tester.tap(find.text('Crêpes'));
    await settle(tester);
    await scrollTo(tester, find.text('Mélanger.'));
    expect(find.text('250 g de farine'), findsOneWidget);
    expect(find.text('Mélanger.'), findsOneWidget);
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
