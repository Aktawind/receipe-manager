import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/label.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v8.dart' as v8;

/// Migration v8 → v9 : le suivi de la synchronisation s'ajoute, rien d'autre ne
/// bouge. Aucune recette n'est « déjà synchronisée » : la première synchro les
/// enverra toutes.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'les recettes et le classement sont intacts, le suivi est vide',
    () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insert(
          oldDb.labels,
          v8.LabelsData(
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
          v8.RecipesData(
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
          v8.RecipeLabelsData(recipeId: 'a', labelId: 'noel', sortIndex: 3),
        );
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);

      final recipe = (await RecipeRepository(db).getRecipe('a'))!;
      expect(recipe.title, 'Bûche');
      expect(recipe.notes, 'Une note');
      expect(recipe.isFavorite, isTrue);
      expect(recipe.updatedAt.toUtc(), DateTime.utc(2026, 10, 29, 9));
      expect(recipe.labelIds, ['noel']);
      final noel = (await LabelRepository(
        db,
      ).getAll()).firstWhere((l) => l.id == 'noel');
      expect(noel.kind, LabelKind.collection);

      expect(await db.select(db.syncEntries).get(), isEmpty);
      expect(await db.select(db.syncSettings).get(), isEmpty);
      // Les nouvelles tables s'écrivent et se relisent.
      await db
          .into(db.syncSettings)
          .insert(
            SyncSettingsCompanion.insert(key: 'changes_token', value: '7'),
          );
      expect((await db.select(db.syncSettings).get()).single.value, '7');
      await db.close();
    },
  );
}
