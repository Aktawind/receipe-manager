import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/planning_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/meal_planner.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v11.dart' as v11;

/// Migration v11 → v12 : le planificateur s'ajoute (accompagnements fournis,
/// planifications enregistrées) ; les recettes ne bougent pas.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les recettes sont intactes, les accompagnements sont prêts', () async {
    final schema = await verifier.schemaAt(11);
    final oldDb = v11.DatabaseAtV11(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insert(
        oldDb.labels,
        const v11.LabelsData(
          id: 'noel',
          kind: 'collection',
          name: 'Noël',
          icon: '',
          color: '',
          position: 0,
          createdAt: '2026-10-29T08:00:00.000Z',
          updatedAt: '2026-10-29T08:00:00.000Z',
        ),
      );
      batch.insert(
        oldDb.recipes,
        const v11.RecipesData(
          id: 'a',
          title: 'Bûche',
          description: '',
          source: '',
          notes: 'Une note',
          tips: '',
          servingsUnit: '',
          timesCooked: 2,
          isFavorite: 1,
          course: '',
          category: '',
          collections: '',
          equipment: '',
          videoLinks: '',
          createdAt: '2026-10-29T08:00:00.000Z',
          updatedAt: '2026-10-29T09:00:00.000Z',
        ),
      );
      batch.insert(
        oldDb.recipeLabels,
        const v11.RecipeLabelsData(
          recipeId: 'a',
          labelId: 'noel',
          sortIndex: 3,
        ),
      );
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 12);

    final recipe = (await RecipeRepository(db).getRecipe('a'))!;
    expect(recipe.title, 'Bûche');

    final planning = PlanningRepository(db);
    final sides = await planning.watchSides().first;
    expect([
      for (final s in sides)
        if (s.kind == SideKind.starch) s.name,
    ], DefaultSideDishes.starches);
    final courgettes = sides.firstWhere((s) => s.name == 'Courgettes');
    expect(courgettes.seasons, {Season.summer});

    final setup = await planning.saveSetup('Semaine', const [
      PlannerSlot(weekday: 1, slotId: 'diner', minutes: 45),
    ]);
    final setups = await planning.watchSetups().first;
    expect(setups.single.id, setup.id);
    expect(setups.single.slots.single.minutes, 45);
    await db.close();
  });
}
