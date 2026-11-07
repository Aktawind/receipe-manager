import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/planning_repository.dart';
import 'package:recettes/domain/planning.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late PlanningRepository planning;
  final lunch = DefaultMealSlots.idFor('Déjeuner');
  final dinner = DefaultMealSlots.idFor('Dîner');
  final monday = DateTime(2026, 11, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    planning = PlanningRepository(db);
  });
  tearDown(() => db.close());

  Future<List<PlannedMeal>> week() => planning.watchMeals(monday).first;

  test('la semaine commence le lundi', () {
    expect(PlannedMeal.weekStart(DateTime(2026, 11, 7)), DateTime(2026, 11, 2));
    expect(PlannedMeal.weekStart(DateTime(2026, 11, 9, 20)), monday);
    expect(PlannedMeal.dayKey(monday), '2026-11-09');
    expect(PlannedMeal.parseDay('2026-11-09'), monday);
  });

  test('ajouter, déplacer, copier, restes, supprimer', () async {
    final quiche = await planning.add(
      day: monday,
      slotId: dinner,
      recipeId: 'q',
      recipeTitle: 'Quiche',
      servings: 4,
    );
    await planning.add(day: monday, slotId: dinner, note: 'Salade');
    var meals = await week();
    expect([for (final m in meals) m.position], [0, 1]);

    // Changer la date : à la fin du créneau du jour choisi.
    await planning.move(quiche, day: DateTime(2026, 11, 11));
    meals = await week();
    final moved = meals.firstWhere((m) => m.id == quiche.id);
    expect(moved.day, DateTime(2026, 11, 11));

    // Les restes : le lendemain, au déjeuner, marqués comme restes.
    final rest = await planning.addLeftovers(moved, lunch);
    expect(rest.day, DateTime(2026, 11, 12));
    expect(rest.leftoverOf, quiche.id);
    expect(rest.recipeTitle, 'Quiche');

    // Copier sur d'autres jours (le jour même est ignoré).
    await planning.copyTo(moved, [
      DateTime(2026, 11, 11),
      DateTime(2026, 11, 13),
      DateTime(2026, 11, 14),
    ]);
    meals = await week();
    expect(meals.where((m) => m.recipeId == 'q'), hasLength(4));

    // Supprimer, puis annuler.
    await planning.delete(rest);
    expect((await week()).any((m) => m.id == rest.id), isFalse);
    await planning.restore(rest);
    expect((await week()).any((m) => m.id == rest.id), isTrue);

    // La semaine suivante ne voit rien de tout ça.
    expect(await planning.watchMeals(DateTime(2026, 11, 16)).first, isEmpty);
  });

  test('créneaux : ajouter, masquer, réordonner, supprimer', () async {
    final brunch = await planning.createSlot('Brunch');
    var slots = await planning.watchSlots().first;
    expect(slots.last.name, 'Brunch');
    await planning.updateSlot(slots.first.copyWith(hidden: true));
    slots = await planning.watchSlots().first;
    await planning.reorderSlots([...slots.reversed]);
    slots = await planning.watchSlots().first;
    expect(slots.first.id, brunch.id);
    expect(slots.last.hidden, isTrue);
    await planning.deleteSlot(brunch);
    expect(
      (await planning.watchSlots().first).map((s) => s.name),
      isNot(contains('Brunch')),
    );
  });
}
