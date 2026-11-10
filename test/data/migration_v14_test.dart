import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe_filter.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v13.dart' as v13;

/// Migration v13 → v14 : les recherches enregistrées passent dans la base
/// (table vide au départ ; celles de l'appareil y sont reprises au démarrage) ;
/// les recettes ne bougent pas.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les recettes sont intactes, les recherches sont prêtes', () async {
    final schema = await verifier.schemaAt(13);
    final oldDb = v13.DatabaseAtV13(schema.newConnection());
    await oldDb
        .into(oldDb.recipes)
        .insert(
          const v13.RecipesData(
            id: 'a',
            title: 'Omelette',
            description: '',
            source: '',
            notes: 'Bien battre',
            tips: '',
            servingsUnit: '',
            timesCooked: 3,
            isFavorite: 1,
            course: '',
            category: '',
            collections: '',
            equipment: '',
            videoLinks: '',
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-02T08:00:00.000Z',
          ),
        );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 14);

    final repo = RecipeRepository(db);
    final recipe = (await repo.getRecipe('a'))!;
    expect(
      (recipe.title, recipe.notes, recipe.isFavorite),
      ('Omelette', 'Bien battre', true),
    );
    expect(await repo.getAllSavedSearches(), isEmpty);

    await repo.saveSearch(
      name: 'Express',
      filter: const RecipeFilter(times: TimeLimits(total: 20)),
    );
    // Même nom : remplacée, pas doublée.
    await repo.saveSearch(
      name: 'express',
      filter: const RecipeFilter(times: TimeLimits(total: 15)),
    );
    final searches = await repo.watchSavedSearches().first;
    expect(searches.single.filter.times.total, 15);
    await db.close();
  });
}
