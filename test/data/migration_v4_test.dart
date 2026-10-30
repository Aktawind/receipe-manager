import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v3.dart' as v3;

/// Migration v3 → v4 : les quantités que l'import de test avait laissées en
/// tête des notes (« Quantité : 12 blinis ») redeviennent des portions.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  v3.RecipesData recipe(String id, {required String notes, int? servings}) =>
      v3.RecipesData(
        id: id,
        title: 'Recette $id',
        description: '',
        source: '',
        notes: notes,
        tips: '',
        servings: servings,
        timesCooked: 0,
        isFavorite: 0,
        course: '',
        category: '',
        collections: '',
        createdAt: '2026-10-28T08:00:00.000Z',
        updatedAt: '2026-10-28T08:00:00.000Z',
      );

  test(
    'les portions « 12 blinis » sont récupérées, le reste est intact',
    () async {
      final schema = await verifier.schemaAt(3);
      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.recipes, [
          recipe('blinis', notes: 'Quantité : 12 blinis\n\nUne bonne note'),
          recipe('seul', notes: 'Quantité : 6 ramequins'),
          recipe('dizaine', notes: 'Quantité : Une dizaine\n\nNote'),
          recipe('ecrit-a-la-main', notes: 'Quantité : 3 pots', servings: 4),
          recipe('normale', notes: 'Rien de spécial'),
        ]);
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      final repo = RecipeRepository(db);

      final blinis = (await repo.getRecipe('blinis'))!;
      expect(blinis.servings, 12);
      expect(blinis.servingsUnit, 'blinis');
      expect(blinis.notes, 'Une bonne note');

      final seul = (await repo.getRecipe('seul'))!;
      expect(seul.servings, 6);
      expect(seul.servingsUnit, 'ramequins');
      expect(seul.notes, '');

      // Sans nombre, ou quand des portions existent déjà : rien n'est touché.
      final dizaine = (await repo.getRecipe('dizaine'))!;
      expect(dizaine.servings, isNull);
      expect(dizaine.notes, 'Quantité : Une dizaine\n\nNote');
      final manual = (await repo.getRecipe('ecrit-a-la-main'))!;
      expect(manual.servings, 4);
      expect(manual.servingsUnit, '');
      expect(manual.notes, 'Quantité : 3 pots');

      final normal = (await repo.getRecipe('normale'))!;
      expect(normal.servings, isNull);
      expect(normal.servingsUnit, '');
      expect(normal.notes, 'Rien de spécial');
      await db.close();
    },
  );
}
