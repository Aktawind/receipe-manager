import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/planning.dart';
import 'database.dart';

/// Les créneaux de repas et les repas du planning.
class PlanningRepository {
  PlanningRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  // --- Créneaux ---

  /// Les créneaux actifs (masqués compris), dans l'ordre choisi.
  Stream<List<MealSlot>> watchSlots() {
    final query = _db.select(_db.mealSlots)
      ..where((s) => s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.asc(s.position)]);
    return query.watch().map((rows) => [for (final r in rows) _slot(r)]);
  }

  /// Tous les créneaux, supprimés compris (sauvegarde, synchro).
  Future<List<MealSlot>> getAllSlots() async => [
    for (final r in await _db.select(_db.mealSlots).get()) _slot(r),
  ];

  Future<MealSlot> createSlot(String name) async {
    final now = _clock();
    final all = await getAllSlots();
    final slot = MealSlot(
      id: _uuid.v4(),
      name: name.trim(),
      position: all.isEmpty
          ? 0
          : all.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1,
      createdAt: now,
      updatedAt: now,
    );
    await putSlot(slot);
    return slot;
  }

  Future<void> updateSlot(MealSlot slot) =>
      putSlot(slot.copyWith(updatedAt: _clock()));

  Future<void> deleteSlot(MealSlot slot) {
    final now = _clock();
    return putSlot(slot.copyWith(updatedAt: now, deletedAt: () => now));
  }

  Future<void> reorderSlots(List<MealSlot> ordered) =>
      _db.transaction(() async {
        final now = _clock();
        for (final (position, slot) in ordered.indexed) {
          if (slot.position != position) {
            await putSlot(slot.copyWith(position: position, updatedAt: now));
          }
        }
      });

  Future<void> putSlot(MealSlot slot) => _db
      .into(_db.mealSlots)
      .insertOnConflictUpdate(
        MealSlotsCompanion.insert(
          id: slot.id,
          name: slot.name,
          position: Value(slot.position),
          hidden: Value(slot.hidden),
          createdAt: slot.createdAt,
          updatedAt: slot.updatedAt,
          deletedAt: Value(slot.deletedAt),
        ),
      );

  static MealSlot _slot(MealSlotRow r) => MealSlot(
    id: r.id,
    name: r.name,
    position: r.position,
    hidden: r.hidden,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deletedAt: r.deletedAt,
  );

  // --- Repas ---

  /// Les repas de [days] jours à partir de [from], par jour puis position.
  Stream<List<PlannedMeal>> watchMeals(DateTime from, {int days = 7}) {
    final start = PlannedMeal.dayKey(PlannedMeal.dayOf(from));
    final endDay = PlannedMeal.dayOf(from);
    final end = PlannedMeal.dayKey(
      DateTime(endDay.year, endDay.month, endDay.day + days - 1),
    );
    final query = _db.select(_db.plannedMeals)
      ..where(
        (m) =>
            m.deletedAt.isNull() &
            m.day.isBiggerOrEqualValue(start) &
            m.day.isSmallerOrEqualValue(end),
      )
      ..orderBy([
        (m) => OrderingTerm.asc(m.day),
        (m) => OrderingTerm.asc(m.position),
      ]);
    return query.watch().map((rows) => [for (final r in rows) ?_meal(r)]);
  }

  /// Tous les repas, supprimés compris (sauvegarde, synchro).
  Future<List<PlannedMeal>> getAllMeals() async => [
    for (final r in await _db.select(_db.plannedMeals).get()) ?_meal(r),
  ];

  Future<PlannedMeal?> getMeal(String id) async {
    final row = await (_db.select(
      _db.plannedMeals,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    return row == null ? null : _meal(row);
  }

  /// Ajoute une recette ou une note au créneau [slotId] du jour [day], à la
  /// fin du créneau.
  Future<PlannedMeal> add({
    required DateTime day,
    required String slotId,
    String? recipeId,
    String recipeTitle = '',
    int? servings,
    String note = '',
    String? leftoverOf,
  }) async {
    final now = _clock();
    final meal = PlannedMeal(
      id: _uuid.v4(),
      day: PlannedMeal.dayOf(day),
      slotId: slotId,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      servings: servings,
      note: note.trim(),
      leftoverOf: leftoverOf,
      position: await _nextPosition(day, slotId),
      createdAt: now,
      updatedAt: now,
    );
    await putMeal(meal);
    return meal;
  }

  /// Déplace un repas (autre jour, autre créneau) ; il va à la fin du créneau.
  Future<void> move(PlannedMeal meal, {DateTime? day, String? slotId}) async {
    final target = PlannedMeal.dayOf(day ?? meal.day);
    final slot = slotId ?? meal.slotId;
    if (target == meal.day && slot == meal.slotId) return;
    await putMeal(
      meal.copyWith(
        day: target,
        slotId: slot,
        position: await _nextPosition(target, slot),
        updatedAt: _clock(),
      ),
    );
  }

  /// Le même repas sur d'autres jours (même créneau).
  Future<void> copyTo(PlannedMeal meal, Iterable<DateTime> days) =>
      _db.transaction(() async {
        for (final day in days) {
          final target = PlannedMeal.dayOf(day);
          if (target == meal.day) continue;
          await add(
            day: target,
            slotId: meal.slotId,
            recipeId: meal.recipeId,
            recipeTitle: meal.recipeTitle,
            servings: meal.servings,
            note: meal.note,
          );
        }
      });

  /// Les restes de [meal] au créneau [slotId] du lendemain.
  Future<PlannedMeal> addLeftovers(PlannedMeal meal, String slotId) {
    final next = DateTime(meal.day.year, meal.day.month, meal.day.day + 1);
    return add(
      day: next,
      slotId: slotId,
      recipeId: meal.recipeId,
      recipeTitle: meal.recipeTitle,
      servings: meal.servings,
      note: meal.note,
      leftoverOf: meal.id,
    );
  }

  Future<void> update(PlannedMeal meal) =>
      putMeal(meal.copyWith(updatedAt: _clock()));

  Future<void> delete(PlannedMeal meal) {
    final now = _clock();
    return putMeal(meal.copyWith(updatedAt: now, deletedAt: () => now));
  }

  Future<void> restore(PlannedMeal meal) =>
      putMeal(meal.copyWith(updatedAt: _clock(), deletedAt: () => null));

  Future<void> putMeal(PlannedMeal meal) => _db
      .into(_db.plannedMeals)
      .insertOnConflictUpdate(
        PlannedMealsCompanion.insert(
          id: meal.id,
          day: PlannedMeal.dayKey(meal.day),
          slotId: meal.slotId,
          recipeId: Value(meal.recipeId),
          recipeTitle: Value(meal.recipeTitle),
          servings: Value(meal.servings),
          note: Value(meal.note),
          leftoverOf: Value(meal.leftoverOf),
          position: Value(meal.position),
          createdAt: meal.createdAt,
          updatedAt: meal.updatedAt,
          deletedAt: Value(meal.deletedAt),
        ),
      );

  Future<int> _nextPosition(DateTime day, String slotId) async {
    final rows =
        await (_db.select(_db.plannedMeals)..where(
              (m) =>
                  m.deletedAt.isNull() &
                  m.day.equals(PlannedMeal.dayKey(PlannedMeal.dayOf(day))) &
                  m.slotId.equals(slotId),
            ))
            .get();
    return rows.isEmpty
        ? 0
        : rows.map((r) => r.position).reduce((a, b) => a > b ? a : b) + 1;
  }

  static PlannedMeal? _meal(PlannedMealRow r) {
    final day = PlannedMeal.parseDay(r.day);
    if (day == null) return null;
    return PlannedMeal(
      id: r.id,
      day: day,
      slotId: r.slotId,
      recipeId: r.recipeId,
      recipeTitle: r.recipeTitle,
      servings: r.servings,
      note: r.note,
      leftoverOf: r.leftoverOf,
      position: r.position,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      deletedAt: r.deletedAt,
    );
  }
}
