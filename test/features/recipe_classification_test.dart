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
}
