import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

Future<TestApp> library(WidgetTester tester) async {
  usePhoneSize(tester);
  final app = (await tester.runAsync(TestApp.create))!;
  await tester.runAsync(() async {
    final cuisine = app.services.equipment;
    final cocotte = await cuisine.findOrCreate('cocotte');
    final robot = await cuisine.findOrCreate('robot pâtissier');

    Future<void> add(
      String title, {
      int? prep,
      int? cook,
      int? rating,
      List<String> ingredients = const [],
      List<String> equipment = const [],
    }) async {
      final created = await app.services.recipes.create();
      await app.services.recipes.save(
        created.copyWith(
          title: title,
          prepMinutes: () => prep,
          cookMinutes: () => cook,
          rating: () => rating,
          equipmentIds: equipment,
          ingredients: [
            for (final (i, name) in ingredients.indexed)
              IngredientLine(id: '$title$i', name: name),
          ],
        ),
      );
    }

    await add(
      'Omelette',
      prep: 5,
      cook: 5,
      rating: 3,
      ingredients: ['œufs', 'beurre', 'sel'],
    );
    await add(
      'Boeuf bourguignon',
      prep: 30,
      cook: 180,
      rating: 5,
      ingredients: ['bœuf', 'vin rouge', 'carottes', 'oignons'],
      equipment: [cocotte.id],
    );
    await add(
      'Brioche',
      prep: 20,
      cook: 30,
      ingredients: ['farine', 'œufs', 'beurre', 'sucre', 'levure'],
      equipment: [robot.id],
    );
    await add('Salade', ingredients: ['laitue', 'tomates']);
  });
  await app.pump(tester);
  return app;
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtrer'));
  await settle(tester);
}

Future<void> done(WidgetTester tester) async {
  await tester.tap(find.text('Terminé'));
  await settle(tester);
}

Future<void> openRow(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pump();
  await tester.tap(find.text(title));
  await settle(tester);
}

/// Les titres affichés, de haut en bas puis de gauche à droite.
List<String> shown(WidgetTester tester, List<String> candidates) {
  final present = [
    for (final c in candidates)
      if (find.text(c).evaluate().isNotEmpty) c,
  ];
  double key(String t) {
    final p = tester.getTopLeft(find.text(t));
    return p.dy * 1000 + p.dx;
  }

  return present..sort((a, b) => key(a).compareTo(key(b)));
}

const titles = ['Omelette', 'Boeuf bourguignon', 'Brioche', 'Salade'];

void main() {
  testWidgets(
    'durée : au plus X minutes, les recettes sans durée sont écartées',
    (tester) async {
      await library(tester);
      await openFilters(tester);
      await openRow(tester, 'Durée');
      await tester.tap(find.byKey(const ValueKey('limit-total')));
      await settle(tester);
      await tester.tap(find.text('1 h').last);
      await settle(tester);
      await tester.tap(find.text('Valider'));
      await settle(tester);
      await done(tester);

      // Omelette (10 min) et brioche (50 min) ; pas le bœuf (3 h 30) ni la salade.
      expect(find.text('Omelette'), findsOneWidget);
      expect(find.text('Brioche'), findsOneWidget);
      expect(find.text('Boeuf bourguignon'), findsNothing);
      expect(find.text('Salade'), findsNothing);
      expect(find.text('2 sur 4 recettes'), findsOneWidget);

      // Cuisson : au plus 15 min → l'omelette seule.
      await openFilters(tester);
      await openRow(tester, 'Durée');
      await tester.tap(find.byKey(const ValueKey('limit-cook')));
      await settle(tester);
      await tester.tap(find.text('15 min').last);
      await settle(tester);
      await tester.tap(find.text('Valider'));
      await settle(tester);
      await done(tester);
      expect(find.text('Omelette'), findsOneWidget);
      expect(find.text('Brioche'), findsNothing);
    },
  );

  testWidgets('tri par durée et par note', (tester) async {
    await library(tester);

    Future<void> sortBy(String label) async {
      await tester.tap(find.byTooltip('Affichage'));
      await settle(tester);
      await tester.tap(find.text(label), warnIfMissed: false);
      await settle(tester);
    }

    await sortBy('Durée (la plus courte d’abord)');
    expect(shown(tester, titles), [
      'Omelette',
      'Brioche',
      'Boeuf bourguignon',
      'Salade',
    ]);
    await sortBy('Note (la meilleure d’abord)');
    expect(shown(tester, titles), [
      'Boeuf bourguignon',
      'Omelette',
      'Brioche',
      'Salade',
    ]);
  });

  testWidgets('matériel : seulement les recettes qui utilisent ce matériel', (
    tester,
  ) async {
    await library(tester);
    await openFilters(tester);
    await openRow(tester, 'Matériel');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cocotte'));
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.text('1 matériel'), findsOneWidget);
    await done(tester);

    // La seule recette qui demande la cocotte.
    expect(shown(tester, titles), ['Boeuf bourguignon']);

    // Deux matériels : l'un et l'autre (aucune recette ne les demande ensemble).
    await openFilters(tester);
    await openRow(tester, 'Matériel');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Robot pâtissier'));
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await settle(tester);
    await done(tester);
    expect(shown(tester, titles), isEmpty);
    expect(find.textContaining('Aucune recette ne correspond'), findsOneWidget);
  });

  testWidgets('ingrédients : tous, au moins un, sans', (tester) async {
    await library(tester);

    Future<void> add(String field, String text) async {
      await tester.ensureVisible(find.byKey(ValueKey(field)));
      await tester.enterText(find.byKey(ValueKey(field)), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }

    await openFilters(tester);
    await openRow(tester, 'Ingrédients');
    await add('ingredients-all', 'oeuf');
    await tester.tap(find.byKey(const ValueKey('ingredients-validate')));
    await settle(tester);
    await done(tester);
    expect(shown(tester, titles), ['Brioche', 'Omelette']);

    // + sans beurre → plus rien (les deux en ont) ; sans levure → l'omelette.
    await openFilters(tester);
    await openRow(tester, 'Ingrédients');
    await add('ingredients-none', 'levure');
    await tester.tap(find.byKey(const ValueKey('ingredients-validate')));
    await settle(tester);
    await done(tester);
    expect(shown(tester, titles), ['Omelette']);

    // Au moins un parmi les tomates ou le bœuf, sans le critère « tous ».
    await openFilters(tester);
    await tester.tap(find.text('Tout effacer'));
    await settle(tester);
    await openRow(tester, 'Ingrédients');
    await add('ingredients-any', 'tomate');
    await add('ingredients-any', 'boeuf');
    await tester.tap(find.byKey(const ValueKey('ingredients-validate')));
    await settle(tester);
    await done(tester);
    expect(shown(tester, titles), ['Boeuf bourguignon', 'Salade']);
  });

  testWidgets('un bouton efface tous les filtres d’un geste', (tester) async {
    await library(tester);
    expect(find.byKey(const ValueKey('filters-clear')), findsNothing);

    await openFilters(tester);
    await openRow(tester, 'Matériel');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cocotte'));
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await settle(tester);
    await done(tester);
    expect(shown(tester, titles), ['Boeuf bourguignon']);

    // Sous le compteur : « Effacer les filtres ».
    expect(find.text('Effacer les filtres'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('filters-clear')));
    await settle(tester);
    expect(shown(tester, titles).length, 4);
    expect(find.byKey(const ValueKey('filters-clear')), findsNothing);
  });
}
