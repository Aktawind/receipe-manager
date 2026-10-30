import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v4.dart' as v4;

/// Migration v4 → v6 (en passant par v5) avec des données de l'étape 1 de la 0.2 : tout est
/// conservé, matériel, vidéos et remplaçants sont vides.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'les recettes importées survivent, les nouveaux champs s’écrivent',
    () async {
      final schema = await verifier.schemaAt(4);
      final oldDb = v4.DatabaseAtV4(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insert(
          oldDb.recipes,
          v4.RecipesData(
            id: 'r1',
            title: 'Blinis',
            description: '',
            source: '',
            notes: 'Une note',
            tips: '',
            servings: 12,
            servingsUnit: 'blinis',
            timesCooked: 1,
            isFavorite: 1,
            rating: 4,
            status: 'validated',
            course: 'Apéritifs',
            category: 'Boulangerie',
            collections: 'Hiver\nÉté',
            createdAt: '2026-10-28T08:00:00.000Z',
            updatedAt: '2026-10-28T08:00:00.000Z',
          ),
        );
        batch.insert(
          oldDb.ingredients,
          v4.IngredientsData(
            id: 'i1',
            recipeId: 'r1',
            position: 0,
            isSection: 0,
            name: 'beurre',
            quantity: 100,
            unit: 'g',
            note: '',
            optional: 0,
          ),
        );
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 9);
      final repo = RecipeRepository(db);

      final recipe = (await repo.getRecipe('r1'))!;
      expect(recipe.title, 'Blinis');
      expect(recipe.servings, 12);
      expect(recipe.servingsUnit, 'blinis');
      expect(recipe.isFavorite, isTrue);
      expect(recipe.rating, 4);
      expect(recipe.status, RecipeStatus.validated);
      // Type de plat, catégorie et collections sont devenus du classement.
      final byId = {
        for (final l in await LabelRepository(db).getAll()) l.id: l,
      };
      expect(
        [
          for (final id in recipe.labelIds)
            [
              if (byId[id]!.parentId != null) byId[byId[id]!.parentId]!.name,
              byId[id]!.name,
            ].join(' › '),
        ]..sort(),
        ['Apéritifs et entrées › Boulangerie', 'Hiver', 'Été'],
      );
      expect(recipe.ingredients.single.name, 'beurre');
      expect(recipe.ingredients.single.substitutes, '');
      expect(recipe.equipmentIds, isEmpty);
      expect(recipe.videoLinks, isEmpty);

      await repo.put(
        recipe.copyWith(
          equipmentIds: ['poele', 'batteur'],
          videoLinks: ['https://youtu.be/abc'],
          ingredients: [
            const IngredientLine(
              id: 'i1',
              name: 'beurre',
              quantity: 100,
              unit: 'g',
              substitutes: 'huile de coco',
            ),
          ],
        ),
      );
      final again = (await repo.getRecipe('r1'))!;
      expect(again.equipmentIds, ['poele', 'batteur']);
      expect(again.videoLinks, ['https://youtu.be/abc']);
      expect(again.ingredients.single.substitutes, 'huile de coco');
      await db.close();
    },
  );
}
