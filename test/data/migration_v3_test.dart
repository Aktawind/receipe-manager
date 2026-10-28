import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v2.dart' as v2;

/// Migration v2 → v3 avec de vraies données : les recettes de la 0.1.0
/// gardent tout leur contenu et reçoivent les nouveaux champs vides.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('les recettes de la 0.1.0 survivent à la migration', () async {
    final schema = await verifier.schemaAt(2);
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insert(
        oldDb.recipes,
        v2.RecipesData(
          id: 'r1',
          title: 'Quiche lorraine',
          description: 'Une description',
          source: 'Livre',
          notes: 'Ma note',
          tips: '',
          servings: 6,
          prepMinutes: 20,
          cookMinutes: 35,
          timesCooked: 3,
          mainPhoto: 'photo.jpg',
          createdAt: '2026-10-20T08:00:00.000Z',
          updatedAt: '2026-10-21T08:00:00.000Z',
        ),
      );
      batch.insert(
        oldDb.ingredients,
        v2.IngredientsData(
          id: 'i1',
          recipeId: 'r1',
          position: 0,
          isSection: 0,
          name: 'farine',
          quantity: 250,
          unit: 'g',
          note: '',
          optional: 0,
        ),
      );
      batch.insert(
        oldDb.recipeSteps,
        v2.RecipeStepsData(
          id: 's1',
          recipeId: 'r1',
          position: 0,
          title: 'Pâte',
          body: 'Mélanger.',
        ),
      );
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);

    final repo = RecipeRepository(db);
    final recipe = (await repo.getRecipe('r1'))!;
    expect(recipe.title, 'Quiche lorraine');
    expect(recipe.notes, 'Ma note');
    expect(recipe.servings, 6);
    expect(recipe.cookMinutes, 35);
    expect(recipe.timesCooked, 3);
    expect(recipe.mainPhoto, 'photo.jpg');
    expect(recipe.ingredients.single.name, 'farine');
    expect(recipe.steps.single.title, 'Pâte');
    // Nouveaux champs : valeurs neutres.
    expect(recipe.isFavorite, isFalse);
    expect(recipe.rating, isNull);
    expect(recipe.status, isNull);
    expect(recipe.category, '');
    expect(recipe.collections, isEmpty);
    expect(recipe.extraPhotos, isEmpty);
    expect(recipe.linkedRecipeIds, isEmpty);

    // Les nouveaux champs s'écrivent et se relisent.
    await repo.put(
      recipe.copyWith(
        isFavorite: true,
        rating: () => 4,
        status: () => RecipeStatus.toTest,
        course: 'Plat',
        category: 'Tartes',
        collections: ['Hiver', 'Été'],
        extraPhotos: ['a.jpg', 'b.jpg'],
        linkedRecipeIds: ['pate'],
      ),
    );
    final again = (await repo.getRecipe('r1'))!;
    expect(again.isFavorite, isTrue);
    expect(again.rating, 4);
    expect(again.status, RecipeStatus.toTest);
    expect(again.course, 'Plat');
    expect(again.category, 'Tartes');
    expect(again.collections, ['Hiver', 'Été']);
    expect(again.extraPhotos, ['a.jpg', 'b.jpg']);
    expect(again.linkedRecipeIds, ['pate']);
    await db.close();
  });
}
