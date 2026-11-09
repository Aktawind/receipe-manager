import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/meal_planner.dart';
import 'package:recettes/domain/planning.dart';
import 'package:recettes/domain/side_emoji.dart';

import '../helpers/test_app.dart';

void main() {
  final today = PlannedMeal.dayOf(DateTime.now());
  final monday = PlannedMeal.weekStart(today);
  final tuesday = DateTime(monday.year, monday.month, monday.day + 1);
  final dinner = DefaultMealSlots.idFor('Dîner');

  testWidgets('le planificateur remplit les créneaux libres', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final gratin = await repo.create();
      await repo.save(gratin.copyWith(title: 'Gratin', servings: () => 4));
      // Lundi soir est déjà prévu.
      await app.services.planning.add(
        day: monday,
        slotId: dinner,
        note: 'Restaurant',
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Planning').last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('planning-planner')));
    await settle(tester);

    // Au départ : un dîner par jour ; on garde lundi et mardi.
    expect(find.byKey(const ValueKey('planner-slot-6')), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('planner-remove-2')));
      await settle(tester);
    }
    expect(find.byKey(const ValueKey('planner-slot-2')), findsNothing);
    expect(find.text('Déjà prévu'), findsOneWidget);
    // Mardi : pas de limite de temps.
    expect(find.text('30 min'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('planner-time-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('planner-time-1-0')));
    await settle(tester);
    expect(find.text('Sans limite'), findsOneWidget);

    // Enregistrer la planification.
    await tester.tap(find.byKey(const ValueKey('planner-save-setup')));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Semaine',
    );
    await tester.tap(find.text('Valider'));
    await settle(tester);
    final setups = (await tester.runAsync(app.services.planning.getAllSetups))!;
    expect(setups.single.name, 'Semaine');
    expect(setups.single.slots, hasLength(2));
    expect(setups.single.slots.first.minutes, 30);
    expect(setups.single.slots.last.minutes, isNull);

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await settle(tester);
    // Deux semaines.
    await tester.tap(find.byKey(const ValueKey('planner-weeks-more')));
    await settle(tester);
    expect(find.text('2 semaines'), findsOneWidget);
    expect(find.text('Déjà prévu certaines semaines'), findsOneWidget);

    final propose = find.byKey(const ValueKey('planner-propose'));
    await tester.ensureVisible(propose);
    await settle(tester);
    await tester.tap(propose);
    await settle(tester);
    // Mardi, puis lundi et mardi de la semaine suivante (ce lundi est déjà
    // prévu).
    expect(find.byKey(const ValueKey('planner-proposal-0')), findsOneWidget);
    expect(find.text('Gratin'), findsWidgets);

    final addStarch = find.byKey(const ValueKey('planner-add-starch-0'));
    await tester.ensureVisible(addStarch);
    await settle(tester);
    await tester.tap(addStarch);
    await settle(tester);
    final side = find.byKey(const ValueKey('planner-side-0-0'));
    expect(side, findsOneWidget);
    final sideName = (tester.widget<InputChip>(side).label as Text).data!;
    expect(DefaultSideDishes.starches, contains(sideName));
    // Avec son emoji.
    expect(
      (tester.widget<InputChip>(side).avatar! as Text).data,
      SideEmoji.forName(sideName, SideKind.starch),
    );

    final apply = find.byKey(const ValueKey('planner-apply'));
    await scrollTo(tester, apply);
    await tester.ensureVisible(apply);
    await settle(tester);
    await tester.tap(apply);
    await settle(tester);

    final all = [
      for (final m in (await tester.runAsync(
        app.services.planning.getAllMeals,
      ))!)
        if (!m.isDeleted) m,
    ];
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    final nextTuesday = DateTime(monday.year, monday.month, monday.day + 8);
    expect(all.where((m) => m.day == nextMonday && m.isRecipe), hasLength(1));
    expect(all.where((m) => m.day == nextTuesday && m.isRecipe), hasLength(1));
    final meals = [
      for (final m in all)
        if (m.day == tuesday) m,
    ];
    expect(meals, hasLength(2));
    final recipe = meals.firstWhere((m) => m.isRecipe);
    expect(recipe.recipeTitle, 'Gratin');
    expect(recipe.servings, 4);
    expect(recipe.slotId, dinner);
    expect(meals.firstWhere((m) => !m.isRecipe).note, sideName);
  });

  testWidgets('Réglages → Accompagnements : ajouter, saisons, retirer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('settings-side-dishes')));
    await tester.tap(find.byKey(const ValueKey('settings-side-dishes')));
    await settle(tester);
    expect(find.text('🍚  Riz'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('sides-add-starch')),
      'Fonio',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    Future<SideDish> boulgour() async =>
        (await tester.runAsync(app.services.planning.getAllSides))!
            .firstWhere((s) => s.name == 'Fonio' && !s.isDeleted);
    final added = await boulgour();
    expect(added.kind, SideKind.starch);
    expect(added.seasons, isEmpty);

    final winter = find.byKey(ValueKey('side-${added.id}-winter'));
    await tester.dragUntilVisible(
      winter,
      find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
      const Offset(0, -250),
    );
    await settle(tester);
    await tester.tap(winter);
    await settle(tester);
    expect(tester.widget<FilterChip>(winter).selected, isTrue);
    expect((await boulgour()).seasons, {Season.winter});

    await tester.tap(find.byKey(ValueKey('side-delete-${added.id}')));
    await settle(tester);
    final sides = (await tester.runAsync(app.services.planning.getAllSides))!;
    expect(sides.where((s) => s.name == 'Fonio' && !s.isDeleted), isEmpty);

    // Les légumes, dans leur onglet.
    await tester.tap(find.byKey(const ValueKey('sides-tab-vegetable')));
    await settle(tester);
    expect(find.byKey(const ValueKey('sides-add-vegetable')), findsOneWidget);
  });
}
