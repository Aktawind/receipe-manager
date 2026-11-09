import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
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
    expect(find.text('6 pers.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-servings-less')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal-save')));
    await settle(tester);

    var meals = await _meals(app, tester);
    expect(meals.single.recipeTitle, 'Quiche lorraine');
    expect(meals.single.servings, 5);
    expect(meals.single.day, monday);
    expect(find.text('Quiche lorraine'), findsOneWidget);
    // Les portions ne s'affichent pas sous la recette.
    expect(find.text('5 pers.'), findsNothing);

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

  testWidgets('restes, glisser-déposer, retirer', (tester) async {
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

    // Plus de « Copier sur d'autres jours ».
    await tester.tap(find.byKey(ValueKey('planning-meal-menu-${quiche.id}')));
    await settle(tester);
    expect(find.text('Copier sur d\'autres jours'), findsNothing);
    await tester.tapAt(Offset.zero);
    await settle(tester);

    // Glisser-déposer : appui long sur le repas, puis sur « Déjeuner ».
    expect(find.text('Changer de créneau'), findsNothing);
    final target = find.byKey(ValueKey('planning-slot-${_key(monday)}-$lunch'));
    // Le repas sous les yeux (pas sous la barre du haut), le créneau dessous.
    await tester.ensureVisible(
      find.byKey(ValueKey('planning-meal-${quiche.id}')),
    );
    await settle(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('planning-meal-${quiche.id}'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
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

  testWidgets('les quantités gardent le nom des portions (« 1 cake »)', (
    tester,
  ) async {
    final app = await open(tester);
    final cake = await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      return repo.save(
        created.copyWith(
          title: 'Cake citron',
          servings: () => 1,
          servingsUnit: 'cake',
        ),
      );
    });
    final meal = await tester.runAsync(
      () => app.services.planning.add(
        day: monday,
        slotId: dinner,
        recipeId: cake!.id,
        recipeTitle: 'Cake citron',
        servings: 1,
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('planning-meal-menu-${meal!.id}')));
    await settle(tester);
    await tester.tap(find.text('Modifier les quantités'));
    await settle(tester);
    expect(find.text('Quantité'), findsOneWidget);
    expect(find.text('Nombre de personnes'), findsNothing);
    expect(find.text('1 cake'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-servings-more')));
    await settle(tester);
    expect(find.byKey(const ValueKey('meal-servings')), findsOneWidget);
    expect(find.text('2 cake'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meal-save')));
    await settle(tester);
    final meals = await _meals(app, tester);
    expect(meals.firstWhere((m) => m.id == meal.id).servings, 2);
  });

  testWidgets('les repas de la semaine vers les courses ; changer de créneau', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final ids = await tester.runAsync(() async {
      final repo = app.services.recipes;
      final created = await repo.create();
      final quiche = await repo.save(
        created.copyWith(
          title: 'Quiche',
          servings: () => 6,
          ingredients: IngredientText.parseList(
            '200 g de lardons\n3 œufs\nSel',
          ),
        ),
      );
      final planning = app.services.planning;
      final tuesday = DateTime(monday.year, monday.month, monday.day + 1);
      final a = await planning.add(
        day: monday,
        slotId: dinner,
        recipeId: quiche.id,
        recipeTitle: 'Quiche',
        servings: 6,
      );
      await planning.add(
        day: tuesday,
        slotId: dinner,
        recipeId: quiche.id,
        recipeTitle: 'Quiche',
        servings: 3,
      );
      await planning.addLeftovers(a, lunch);
      await planning.add(day: tuesday, slotId: lunch, note: 'Pain');
      return (quiche: quiche.id, a: a.id);
    });
    await app.pump(tester);
    await tester.tap(find.text('Planning').last);
    await settle(tester);

    // Changer de créneau, par le menu (date et créneau ensemble).
    await tester.tap(find.byKey(ValueKey('planning-meal-menu-${ids!.a}')));
    await settle(tester);
    await tester.tap(find.text('Changer la date ou le créneau'));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('move-slot-$lunch')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('move-ok')));
    await settle(tester);
    var meals = await _meals(app, tester);
    expect(meals.firstWhere((m) => m.id == ids.a).slotId, lunch);

    await tester.tap(find.byKey(const ValueKey('planning-shopping')));
    await settle(tester);
    expect(find.text('Les repas à mettre dans les courses'), findsOneWidget);
    // « Tout cocher » : les repas, pas les restes.
    await tester.tap(find.byKey(const ValueKey('week-shop-all')));
    await settle(tester);
    final rest = meals.firstWhere((m) => m.isLeftovers);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(ValueKey('week-shop-${rest.id}')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('week-shop-ok')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('add-shopping-confirm')));
    await settle(tester);

    final list = (await tester.runAsync(app.services.shopping.getAllLists))!
        .single;
    String amountOf(String name) =>
        list.items.firstWhere((i) => i.name == name).amount;
    // 6 personnes + 3 personnes = une fois et demie la recette.
    expect(amountOf('Lardons'), '300 g');
    expect(amountOf('Œufs'), '5');
    expect(list.items.any((i) => i.name == 'Sel'), isFalse);
    expect(list.items.any((i) => i.name == 'Pain'), isTrue);
    meals = await _meals(app, tester);
    expect(meals, hasLength(4));
  });
}
