import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/planning.dart';

import '../helpers/test_app.dart';

/// Le minimum d'accessibilité sur les écrans principaux : zones à toucher
/// assez grandes, boutons nommés pour TalkBack, texte lisible.
void main() {
  Future<TestApp> open(WidgetTester tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(initialLocation: '/accueil'),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final r = await repo.create();
      await repo.save(
        r.copyWith(
          title: 'Quiche',
          servings: () => 4,
          isFavorite: true,
          ingredients: IngredientText.parseList('200 g de lardons\n3 œufs'),
        ),
      );
      await app.services.planning.add(
        day: DateTime.now(),
        slotId: DefaultMealSlots.idFor('Dîner'),
        recipeId: r.id,
        recipeTitle: 'Quiche',
      );
      final book = await repo.createBook(title: 'Simplissime');
      await repo.linkToBook(book.id, {r.id: '12'});
      final list = await app.services.shopping.createList('Semaine');
      await app.services.shopping.save(list);
    });
    await app.pump(tester);
    await settle(tester);
    return app;
  }

  Future<void> check(WidgetTester tester, String screen) async {
    final handle = tester.ensureSemantics();
    for (final (name, guideline) in [
      ('taille des zones à toucher', androidTapTargetGuideline),
      ('boutons nommés', labeledTapTargetGuideline),
      ('contraste du texte', textContrastGuideline),
    ]) {
      await expectLater(
        tester,
        meetsGuideline(guideline),
        reason: '$screen : $name',
      );
    }
    handle.dispose();
  }

  testWidgets('accueil, recettes, fiche, livres, planning, courses, réglages', (
    tester,
  ) async {
    await open(tester);
    await check(tester, 'Accueil');
    for (final tab in ['Recettes', 'Livres', 'Planning', 'Courses']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
      await check(tester, tab);
    }
    await openSettings(tester);
    await check(tester, 'Réglages');
    await goBack(tester);
    await tester.tap(find.text('Recettes').last);
    await settle(tester);
    await tester.tap(find.text('Quiche').first);
    await settle(tester);
    await check(tester, 'Fiche recette');
    // Retour système (la fiche n'a pas de BackButton classique).
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text('Livres').last);
    await settle(tester);
    await tester.tap(find.text('Simplissime'));
    await settle(tester);
    await check(tester, 'Fiche livre');
  });
}
