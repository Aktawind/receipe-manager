import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

void main() {
  Finder field(String name) => find.descendant(
    of: find.byKey(ValueKey('field-$name')),
    matching: find.byType(TextField),
  );

  testWidgets('la fiche : matériel, remplaçant, gras, vidéo et étoiles', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final repo = app.services.recipes;
    final id = (await tester.runAsync(() async {
      final cake = await app.services.equipment.findOrCreate('Moule à cake');
      final fouet = await app.services.equipment.findOrCreate('Fouet');
      final created = await repo.create();
      final saved = await repo.save(
        created.copyWith(
          title: 'Gâteau',
          equipmentIds: [cake.id, fouet.id],
          videoLinks: ['https://youtu.be/abc'],
          ingredients: [
            IngredientLine(
              id: RecipeRepository.newId(),
              name: 'beurre',
              quantity: 100,
              unit: 'g',
              substitutes: 'huile de coco',
            ),
          ],
          steps: [
            RecipeStep(
              id: RecipeRepository.newId(),
              text: 'Cuire **40 minutes** à feu *doux*.',
            ),
          ],
        ),
      );
      return saved.id;
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Gâteau'));
    await settle(tester);
    expect(find.text('100 g de beurre'), findsOneWidget);
    expect(find.text('Ou : huile de coco'), findsOneWidget);
    expect(find.text('Matériel'), findsOneWidget);
    expect(find.text('Moule à cake'), findsOneWidget);
    // Le gras et l'italique ne laissent pas leurs astérisques à l'écran.
    expect(find.text('Cuire 40 minutes à feu doux.'), findsOneWidget);
    await scrollTo(tester, find.text('https://youtu.be/abc'));

    // Étoiles : 4 étoiles, puis un second appui sur la même retire la note.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await tester.pump();
    await tester.tap(find.byTooltip('Noter 4 sur 5'));
    await settle(tester);
    Future<int?> rating() async {
      final recipe = await tester.runAsync(() => repo.getRecipe(id));
      return recipe!.rating;
    }

    expect(await rating(), 4);
    await tester.tap(find.byTooltip('Retirer la note'));
    await settle(tester);
    expect(await rating(), isNull);
  });

  testWidgets('l’éditeur : matériel, vidéos, gras et recette utilisée', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final repo = app.services.recipes;
    final rouleau = (await tester.runAsync(
      () => app.services.equipment.findOrCreate('Rouleau'),
    ))!;
    final ids = (await tester.runAsync(() async {
      final dough = await repo.save(
        (await repo.create()).copyWith(title: 'Pâte brisée'),
      );
      final tart = await repo.save(
        (await repo.create()).copyWith(
          title: 'Quiche',
          steps: [RecipeStep(id: RecipeRepository.newId(), text: 'Cuire')],
        ),
      );
      return (dough.id, tart.id);
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Quiche'));
    await settle(tester);
    await tester.tap(find.byTooltip('Modifier'));
    await settle(tester);

    await scrollTo(tester, field('ingredients'));
    await tester.enterText(field('ingredients'), '200 g de lardons');

    // Recette liée, insérée proprement dans les ingrédients.
    await tester.ensureVisible(find.text('Insérer une recette (pâte, sauce…)'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pump();
    await tester.tap(find.text('Insérer une recette (pâte, sauce…)'));
    await settle(tester);
    await tester.tap(find.text('Pâte brisée'));
    await settle(tester);
    expect(
      tester.widget<TextField>(field('ingredients')).controller!.text,
      '200 g de lardons\n[[Pâte brisée]]',
    );

    // Matériel : on coche dans la liste commune, ou on ajoute ce qui manque.
    await tester.ensureVisible(find.text('Choisir le matériel'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pump();
    await tester.tap(find.text('Choisir le matériel'));
    await settle(tester);
    await tester.tap(find.text('Rouleau'));
    await tester.enterText(
      find.byKey(const ValueKey('equipment-search')),
      'Moule',
    );
    await tester.pump();
    await tester.tap(find.text('Ajouter « Moule »'));
    await settle(tester);
    await tester.tap(find.text('Valider'));
    await settle(tester);

    // Gras : les marqueurs entourent le mot sélectionné.
    await scrollTo(tester, field('steps'));
    await tester.enterText(field('steps'), 'Cuire longtemps');
    final controller = tester.widget<TextField>(field('steps')).controller!;
    controller.selection = const TextSelection(baseOffset: 6, extentOffset: 15);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Gras'));
    await tester.pump();
    await tester.tap(find.byTooltip('Gras'));
    await tester.pump();
    expect(controller.text, 'Cuire **longtemps**');

    await scrollTo(tester, field('videos'));
    await tester.enterText(field('videos'), 'https://youtu.be/xyz');
    await tester.pump(const Duration(seconds: 1));

    await goBack(tester);
    final saved = (await tester.runAsync(() => repo.getRecipe(ids.$2)))!;
    final catalog = (await tester.runAsync(
      () => app.services.equipment.getAll(),
    ))!;
    final moule = catalog.firstWhere((e) => e.name == 'Moule');
    expect(saved.equipmentIds, [rouleau.id, moule.id]);
    expect(saved.steps.single.text, 'Cuire **longtemps**');
    expect(saved.ingredients.map((i) => i.name), ['lardons', 'Pâte brisée']);
    expect(saved.ingredients.last.linkedRecipeId, ids.$1);
    expect(saved.linkedRecipeIds, [ids.$1]);
    expect(saved.videoLinks, ['https://youtu.be/xyz']);
  });
}
