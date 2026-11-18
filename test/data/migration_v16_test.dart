import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v15.dart' as v15;

/// Migration v15 → v16 : la note se compte en demi-étoiles ; les notes
/// entières restent les mêmes (4 étoiles → 4 étoiles), les recettes non
/// notées le restent.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les notes sont gardées ; 4,5 étoiles s’enregistre ensuite', () async {
    final schema = await verifier.schemaAt(15);
    final oldDb = v15.DatabaseAtV15(schema.newConnection());
    for (final (id, title, rating) in [
      ('a', 'Tarte au citron', 4),
      ('b', 'Quiche', 1),
      ('c', 'Gratin', null),
    ]) {
      await oldDb
          .into(oldDb.recipes)
          .insert(
            v15.RecipesData(
              id: id,
              title: title,
              description: '',
              source: '',
              notes: 'Note de $title',
              tips: '',
              servingsUnit: '',
              timesCooked: 0,
              isFavorite: 0,
              rating: rating,
              course: '',
              category: '',
              collections: '',
              equipment: '',
              videoLinks: '',
              bookPage: '',
              createdAt: '2026-11-01T08:00:00.000Z',
              updatedAt: '2026-11-02T08:00:00.000Z',
            ),
          );
    }
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 16);

    final repo = RecipeRepository(db);
    expect((await repo.getRecipe('a'))!.rating, 4);
    expect((await repo.getRecipe('b'))!.rating, 1);
    expect((await repo.getRecipe('c'))!.rating, isNull);
    expect((await repo.getRecipe('a'))!.notes, 'Note de Tarte au citron');

    await repo.setRating('a', 4.5);
    expect((await repo.getRecipe('a'))!.rating, 4.5);
    await repo.setRating('c', 0.5);
    expect((await repo.getRecipe('c'))!.rating, 0.5);
    await db.close();
  });
}
