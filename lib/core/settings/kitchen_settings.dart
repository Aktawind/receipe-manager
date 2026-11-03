import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/unit_conversion.dart';
import 'theme_mode_controller.dart';

/// Les unités dans lesquelles la fiche affiche les quantités.
final unitSystemProvider = NotifierProvider<UnitSystemController, UnitSystem>(
  UnitSystemController.new,
);

class UnitSystemController extends Notifier<UnitSystem> {
  static const _key = 'unit_system';

  @override
  UnitSystem build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return UnitSystem.values.asNameMap()[stored] ?? UnitSystem.recipe;
  }

  Future<void> set(UnitSystem system) async {
    state = system;
    await ref.read(sharedPreferencesProvider).setString(_key, system.name);
  }
}

/// L'unité des températures dans la préparation.
final temperatureUnitProvider =
    NotifierProvider<TemperatureUnitController, TemperatureUnit>(
      TemperatureUnitController.new,
    );

class TemperatureUnitController extends Notifier<TemperatureUnit> {
  static const _key = 'temperature_unit';

  @override
  TemperatureUnit build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_key);
    return TemperatureUnit.values.asNameMap()[stored] ?? TemperatureUnit.recipe;
  }

  Future<void> set(TemperatureUnit unit) async {
    state = unit;
    await ref.read(sharedPreferencesProvider).setString(_key, unit.name);
  }
}

/// Le nombre de personnes proposé pour une nouvelle recette ; `null` = aucun.
final defaultServingsProvider =
    NotifierProvider<DefaultServingsController, int?>(
      DefaultServingsController.new,
    );

class DefaultServingsController extends Notifier<int?> {
  static const _key = 'default_servings';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(_key);

  Future<void> set(int? servings) async {
    state = servings;
    final prefs = ref.read(sharedPreferencesProvider);
    if (servings == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setInt(_key, servings);
    }
  }
}
