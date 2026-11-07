import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/planning.dart';

import '../helpers/test_app.dart';

Future<List<PlannedMeal>> _meals(TestApp app, WidgetTester tester) async => [
  for (final m in (await tester.runAsync(
    () => app.services.planning.getAllMeals(),
  ))!)
    if (!m.isDeleted) m,
];

String _key(DateTime day) => PlannedMeal.dayKey(day);

void main() {
  final today = PlannedMeal.dayOf(DateTime.now());
  final monday = PlannedMeal.weekStart(today);
  final dinner = DefaultMealSlots.idFor('Dîner');
  final lunch = DefaultMealSlots.idFor('Déjeuner');

  Future<TestApp> open(WidgetTester tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final quiche = await repo.create();
      await repo.save(
        quiche.copyWith(title: 'Quiche lorraine', servings: () => 6),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Planning').last);
    await settle(tester);
    return app;
  }

  testWidgets('la semaine : ajouter une recette et une note', (tester) async {
    final app = await open(tester);
    // Les sept jours, du lundi au dimanche.
    expect(
      find.byKey(ValueKey('planning-day-${_key(monday)}')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey('planning-add-${_key(monday)}-$dinner')),
    );
    await settle(tester);
    await tester.tap(find.text('Quiche lorraine'));
    await settle(tester);
    // Le nombre de personnes de la recette, modifiable.
    expect(find.text('6'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-servings-less')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal-save')));
    await settle(tester);

    var meals = await _meals(app, tester);
    expect(meals.single.recipeTitle, 'Quiche lorraine');
    expect(meals.single.servings, 5);
    expect(meals.single.day, monday);
    expect(find.text('Quiche lorraine'), findsOneWidget);
    expect(find.text('5 portions'), findsOneWidget);

    final tuesday = DateTime(monday.year, monday.month, monday.day + 1);
    final add = find.byKey(ValueKey('planning-add-${_key(tuesday)}-$lunch'));
    await tester.ensureVisible(add);
    await settle(tester);
    await tester.tap(add);
    await settle(tester);
    await tester.tap(find.text('Note'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('meal-note')),
      'Restaurant',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meal-save')));
    await settle(tester);
    meals = await _meals(app, tester);
    expect(meals, hasLength(2));
    expect(find.text('Restaurant'), findsOneWidget);
  });

  testWidgets('restes, copier, changer de créneau, retirer', (tester) async {
    final app = await open(tester);
    final quiche = await tester.runAsync(
      () => app.services.planning.add(
        day: monday,
        slotId: dinner,
        recipeId: 'x',
        recipeTitle: 'Quiche lorraine',
        servings: 4,
      ),
    );
    await settle(tester);

    Future<void> menu(String id, String action) async {
      await tester.tap(find.byKey(ValueKey('planning-meal-menu-$id')));
      await settle(tester);
      await tester.tap(find.text(action));
      await settle(tester);
    }

    await menu(quiche!.id, 'Restes pour le lendemain');
    var meals = await _meals(app, tester);
    final rest = meals.firstWhere((m) => m.isLeftovers);
    expect(rest.day, DateTime(monday.year, monday.month, monday.day + 1));
    expect(rest.slotId, lunch);
    expect(find.textContaining('Restes'), findsWidgets);

    await menu(quiche.id, 'Copier sur d\'autres jours');
    final thursday = DateTime(monday.year, monday.month, monday.day + 3);
    await tester.tap(find.byKey(ValueKey('copy-${_key(thursday)}')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('copy-ok')));
    await settle(tester);
    meals = await _meals(app, tester);
    expect(
      meals.where((m) => m.day == thursday && !m.isLeftovers),
      hasLength(1),
    );

    await menu(quiche.id, 'Changer de créneau');
    await tester.tap(find.text('Déjeuner').last);
    await settle(tester);
    meals = await _meals(app, tester);
    expect(meals.firstWhere((m) => m.id == quiche.id).slotId, lunch);

    await menu(quiche.id, 'Retirer du planning');
    meals = await _meals(app, tester);
    expect(meals.any((m) => m.id == quiche.id), isFalse);
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    meals = await _meals(app, tester);
    expect(meals.any((m) => m.id == quiche.id), isTrue);
  });

  testWidgets('semaine suivante, vue jour', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('planning-next')));
    await settle(tester);
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    expect(
      find.byKey(ValueKey('planning-day-${_key(nextMonday)}')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('planning-today')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('planning-view')));
    await settle(tester);
    // Vue jour : un seul jour, tous ses créneaux.
    expect(find.byKey(ValueKey('planning-day-${_key(today)}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('planning-day-${_key(monday)}')),
      today == monday ? findsOneWidget : findsNothing,
    );
    expect(find.text('Petit-déjeuner'), findsOneWidget);
    expect(find.text('Goûter'), findsOneWidget);
  });

  testWidgets('Réglages → Créneaux : masquer, ajouter', (tester) async {
    final app = await open(tester);
    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('settings-meal-slots')));
    await tester.tap(find.byKey(const ValueKey('settings-meal-slots')));
    await settle(tester);
    await tester.tap(
      find.byKey(ValueKey('slot-shown-${DefaultMealSlots.idFor('Goûter')}')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('slot-add')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Brunch');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    final slots = (await tester.runAsync(app.services.planning.getAllSlots))!;
    expect(
      slots.firstWhere((s) => s.id == DefaultMealSlots.idFor('Goûter')).hidden,
      isTrue,
    );
    expect(slots.map((s) => s.name), contains('Brunch'));

    await goBack(tester);
    await tester.tap(find.text('Planning').last);
    await settle(tester);
    expect(
      find.byKey(
        ValueKey(
          'planning-add-${_key(monday)}-${DefaultMealSlots.idFor('Goûter')}',
        ),
      ),
      findsNothing,
    );
  });
}
