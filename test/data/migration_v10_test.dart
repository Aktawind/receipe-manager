import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/data/shopping_repository.dart';
import 'package:recettes/domain/default_aisles.dart';
import 'package:recettes/domain/shopping.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v9.dart' as v9;

/// Migration v9 → v10 : les listes de courses et les rayons s'ajoutent ; les
/// recettes ne bougent pas, et les rayons fournis sont créés.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les recettes sont intactes, les rayons sont prêts', () async {
    final schema = await verifier.schemaAt(9);
    final oldDb = v9.DatabaseAtV9(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insert(
        oldDb.labels,
        const v9.LabelsData(
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
        const v9.RecipesData(
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
        const v9.RecipeLabelsData(recipeId: 'a', labelId: 'noel', sortIndex: 3),
      );
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 10);

    final recipe = (await RecipeRepository(db).getRecipe('a'))!;
    expect(recipe.title, 'Bûche');
    expect(recipe.notes, 'Une note');
    expect(recipe.labelIds, ['noel']);

    final shopping = ShoppingRepository(db);
    final aisles = await shopping.watchAisles().first;
    expect([for (final a in aisles) a.name], DefaultAisles.names);
    expect(aisles.first.id, DefaultAisles.idFor('Fruits et légumes'));

    // Les nouvelles tables s'écrivent et se relisent.
    final list = await shopping.createList('Semaine');
    await shopping.save(
      list.copyWith(
        items: [
          ShoppingItem(
            id: 'i',
            name: 'Beurre',
            quantity: 250,
            unit: 'g',
            aisleId: aisles[6].id,
            sources: const [
              ShoppingSource(recipeId: 'a', recipeTitle: 'Bûche'),
            ],
          ),
        ],
      ),
    );
    final read = (await shopping.getList(list.id))!;
    expect(read.items.single.amount, '250 g');
    expect(read.items.single.sources.single.recipeTitle, 'Bûche');
    await db.close();
  });
}
