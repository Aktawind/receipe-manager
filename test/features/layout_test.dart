import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

/// La barre de navigation Android (ici 48 dp) ne doit jamais recouvrir la fin
/// d'un écran.
void main() {
  const inset = 48.0;

  void useSystemBar(WidgetTester tester, Size physical, double ratio) {
    tester.view.physicalSize = physical;
    tester.view.devicePixelRatio = ratio;
    tester.view.padding = const FakeViewPadding(bottom: inset * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: inset * 3);
    addTearDown(tester.view.reset);
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<String> recipeWithEverything(WidgetTester tester, TestApp app) async {
    return (await tester.runAsync(() async {
      final created = await app.services.recipes.create();
      await app.services.recipes.save(
        created.copyWith(
          title: 'Quiche',
          description: 'Une quiche.',
          notes: 'Une note.',
          source: 'Livre de mamie',
          steps: const [RecipeStep(id: 's', text: 'Cuire.')],
          ingredients: const [IngredientLine(id: 'i', name: 'farine')],
        ),
      );
      return created.id;
    }))!;
  }

  testWidgets('la fiche : le bas de page est au-dessus de la barre Android', (
    tester,
  ) async {
    useSystemBar(tester, const Size(1080, 2340), 3);
    final app = (await tester.runAsync(TestApp.create))!;
    await recipeWithEverything(tester, app);
    await app.pump(tester);

    await tester.tap(find.text('Quiche'));
    await settle(tester);
    await scrollToEnd(tester);

    final bottom = tester.getBottomLeft(find.textContaining('Ajoutée le')).dy;
    expect(bottom, lessThanOrEqualTo(2340 / 3 - inset));
  });

  testWidgets(
    'l’éditeur : le dernier champ est au-dessus de la barre Android',
    (tester) async {
      useSystemBar(tester, const Size(1080, 2340), 3);
      final app = (await tester.runAsync(TestApp.create))!;
      await recipeWithEverything(tester, app);
      await app.pump(tester);

      await tester.tap(find.text('Quiche'));
      await settle(tester);
      await tester.tap(find.byTooltip('Modifier'));
      await settle(tester);
      await scrollToEnd(tester);

      final source = find.byKey(const ValueKey('field-source'));
      // Au moins 24 dp libres entre le champ et la barre de navigation.
      expect(
        tester.getBottomLeft(source).dy,
        lessThanOrEqualTo(2340 / 3 - inset - 24),
      );
    },
  );

  testWidgets('tablette : le menu latéral est au-dessus de la barre Android', (
    tester,
  ) async {
    useSystemBar(tester, const Size(2560, 1600), 2);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    final rail = tester.getRect(find.byType(NavigationRail));
    expect(rail.bottom, lessThanOrEqualTo(1600 / 2 - inset));
  });

  testWidgets('l’éditeur : portions et temps sont des champs de même taille', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(TestApp.create))!;
    await recipeWithEverything(tester, app);
    await app.pump(tester);

    await tester.tap(find.text('Quiche'));
    await settle(tester);
    await tester.tap(find.byTooltip('Modifier'));
    await settle(tester);

    double height(String label) =>
        tester.getSize(find.widgetWithText(TextField, label)).height;
    final title = height('Titre');
    for (final label in [
      'Portions',
      'Unité des portions',
      'Fois réalisée',
      'Préparation',
      'Cuisson',
      'Repos',
    ]) {
      await scrollTo(tester, find.widgetWithText(TextField, label));
      expect(
        height(label),
        moreOrLessEquals(title, epsilon: 24),
        reason: label,
      );
    }
    // Pas de texte d'aide sous les grands champs.
    expect(find.textContaining('Colle ta liste'), findsNothing);
    expect(find.textContaining('Colle toute la préparation'), findsNothing);
  });
}
