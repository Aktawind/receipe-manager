import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('la fiche montre statut, type de plat, catégorie, collections, '
      'recette liée, et le cœur change le favori', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final repo = app.services.recipes;

    final recipeId = (await tester.runAsync(() async {
      final dough = await repo.save(
        (await repo.create()).copyWith(title: 'Pâte brisée'),
      );
      final tart = await repo.save(
        (await repo.create()).copyWith(
          title: 'Tarte aux poireaux',
          status: () => RecipeStatus.toTest,
          course: 'Plat',
          category: 'Tartes',
          collections: ['Hiver', 'Automne'],
          linkedRecipeIds: [dough.id],
          ingredients: [
            IngredientLine(id: RecipeRepository.newId(), name: 'poireaux'),
          ],
        ),
      );
      return tart.id;
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Tarte aux poireaux'));
    await settle(tester);
    expect(find.text('À tester'), findsOneWidget);
    expect(find.text('Plat'), findsOneWidget);
    expect(find.text('Tartes'), findsOneWidget);

    await scrollTo(tester, find.text('Collections : Hiver · Automne'));
    await scrollTo(tester, find.text('Pâte brisée'));
    expect(find.text('Recettes utilisées'), findsOneWidget);

    // Le cœur de la barre du haut bascule le favori.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await tester.pump();
    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await settle(tester);
    final favorite = (await tester.runAsync(
      () async => (await repo.getRecipe(recipeId))!.isFavorite,
    ))!;
    expect(favorite, isTrue);
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
  });

  testWidgets('quantité en unités (12 blinis), statut modifiable d’un geste', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final repo = app.services.recipes;
    final id = (await tester.runAsync(() async {
      final created = await repo.create();
      final saved = await repo.save(
        created.copyWith(
          title: 'Blinis',
          servings: () => 12,
          servingsUnit: 'blinis',
        ),
      );
      return saved.id;
    }))!;
    await app.pump(tester);
    // La liste annonce « 12 blinis », pas « 12 portions ».
    expect(find.textContaining('12 blinis'), findsOneWidget);

    await tester.tap(find.text('Blinis'));
    await settle(tester);
    expect(find.text('Quantité'), findsOneWidget);
    expect(find.text('12 blinis'), findsOneWidget);

    await tester.tap(find.text('Statut'));
    await settle(tester);
    await tester.tap(find.text('Validée'), warnIfMissed: false);
    await settle(tester);
    final status = (await tester.runAsync(
      () async => (await repo.getRecipe(id))!.status,
    ))!;
    expect(status, RecipeStatus.validated);
    expect(find.text('Validée'), findsOneWidget);
  });
}
