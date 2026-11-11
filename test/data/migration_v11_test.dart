import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/planning_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/planning.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v10.dart' as v10;

/// Migration v10 → v11 : le planning des repas s'ajoute ; les recettes ne
/// bougent pas, et les créneaux fournis sont créés.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les recettes sont intactes, les créneaux sont prêts', () async {
    final schema = await verifier.schemaAt(10);
    final oldDb = v10.DatabaseAtV10(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insert(
        oldDb.labels,
        const v10.LabelsData(
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
        const v10.RecipesData(
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
        const v10.RecipeLabelsData(
          recipeId: 'a',
          labelId: 'noel',
          sortIndex: 3,
        ),
      );
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    // Jusqu'à la dernière version : le dépôt lit les colonnes d'aujourd'hui.
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);

    final recipe = (await RecipeRepository(db).getRecipe('a'))!;
    expect(recipe.title, 'Bûche');
    expect(recipe.labelIds, ['noel']);

    final planning = PlanningRepository(db);
    final slots = await planning.watchSlots().first;
    expect([for (final s in slots) s.name], DefaultMealSlots.names);

    final meal = await planning.add(
      day: DateTime(2026, 11, 9),
      slotId: slots[3].id,
      recipeId: 'a',
      recipeTitle: 'Bûche',
      servings: 8,
    );
    final week = await planning
        .watchMeals(PlannedMeal.weekStart(DateTime(2026, 11, 11)))
        .first;
    expect(week.single.id, meal.id);
    expect(week.single.servings, 8);
    await db.close();
  });
}
