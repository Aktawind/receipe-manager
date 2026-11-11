import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_services.dart';
import '../../domain/meal_planner.dart';
import '../../domain/planning.dart';

/// Les créneaux, dans l'ordre choisi (masqués compris).
final mealSlotsProvider = StreamProvider<List<MealSlot>>(
  (ref) => ref.watch(planningRepositoryProvider).watchSlots(),
);

/// Les repas de la semaine qui commence le lundi donné.
final weekMealsProvider = StreamProvider.family<List<PlannedMeal>, DateTime>(
  (ref, monday) => ref.watch(planningRepositoryProvider).watchMeals(monday),
);

/// Le lundi de la semaine affichée.
final plannedWeekProvider = NotifierProvider<PlannedWeek, DateTime>(
  PlannedWeek.new,
);

class PlannedWeek extends Notifier<DateTime> {
  @override
  DateTime build() => PlannedMeal.weekStart(DateTime.now());

  void show(DateTime day) => state = PlannedMeal.weekStart(day);

  void shift(int weeks) =>
      state = DateTime(state.year, state.month, state.day + 7 * weeks);
}

/// Le jour affiché en vue jour ; `null` = vue semaine.
final plannedDayProvider = NotifierProvider<PlannedDay, DateTime?>(
  PlannedDay.new,
);

class PlannedDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void show(DateTime? day) =>
      state = day == null ? null : PlannedMeal.dayOf(day);
}

/// Les accompagnements du planificateur.
final sideDishesProvider = StreamProvider<List<SideDish>>(
  (ref) => ref.watch(planningRepositoryProvider).watchSides(),
);

/// Les planifications enregistrées.
final plannerSetupsProvider = StreamProvider<List<PlannerSetup>>(
  (ref) => ref.watch(planningRepositoryProvider).watchSetups(),
);
