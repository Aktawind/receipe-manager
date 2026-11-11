import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/planning.dart';

import '../helpers/test_app.dart';

void main() {
  final today = PlannedMeal.dayOf(DateTime.now());
  final dinner = DefaultMealSlots.idFor('Dîner');
  final lunch = DefaultMealSlots.idFor('Déjeuner');

  Future<TestApp> open(
    WidgetTester tester, {
    Future<void> Function(TestApp app)? seed,
  }) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(initialLocation: '/accueil'),
    ))!;
    if (seed != null) await tester.runAsync(() => seed(app));
    await app.pump(tester);
    await settle(tester);
    return app;
  }

  testWidgets('l’accueil montre d’abord les repas du jour', (tester) async {
    late String quicheId;
    await open(
      tester,
      seed: (app) async {
        final repo = app.services.recipes;
        final quiche = await repo.create();
        await repo.save(quiche.copyWith(title: 'Quiche'));
        quicheId = quiche.id;
        await repo.setFavorite(quiche.id, true);
        final planning = app.services.planning;
        await planning.add(
          day: today,
          slotId: dinner,
          recipeId: quiche.id,
          recipeTitle: 'Quiche',
          servings: 4,
        );
        await planning.add(day: today, slotId: lunch, note: 'Cantine');
      },
    );
    expect(find.text('Accueil'), findsWidgets);
    final todayTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-today')),
    );
    final favoritesTop = tester.getTopLeft(
      find.byKey(const ValueKey('home-favorites')),
    );
    expect(todayTop.dy < favoritesTop.dy, isTrue);
    // Le déjeuner avant le dîner (ordre des créneaux).
    final cantine = tester.getTopLeft(find.text('Cantine')).dy;
    final quiche = tester.getTopLeft(find.text('Quiche').first).dy;
    expect(cantine < quiche, isTrue);
    expect(find.text('Déjeuner'), findsOneWidget);

    // Toucher la recette du jour ouvre sa fiche.
    await tester.tap(find.text('Quiche').first);
    await settle(tester);
    expect(
      find.byKey(const ValueKey('recipe-add-to-shopping')),
      findsOneWidget,
    );
    expect(quicheId, isNotEmpty);
  });

  testWidgets('rien de prévu : le planificateur est proposé', (tester) async {
    await open(tester);
    expect(find.text('Rien de prévu aujourd\'hui.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-plan')));
    await settle(tester);
    expect(find.text('Planificateur'), findsOneWidget);
  });

  testWidgets('personnaliser : cacher une rubrique', (tester) async {
    final app = await open(tester);
    expect(find.byKey(const ValueKey('home-shortcut-new')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-customize')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('home-section-shortcuts')));
    await settle(tester);
    await goBack(tester);
    expect(find.byKey(const ValueKey('home-shortcut-new')), findsNothing);
    expect(app.prefs.getStringList('home_sections'), contains('shortcuts:0'));
  });
}
