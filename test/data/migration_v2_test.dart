import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v1.dart' as v1;

/// Migration v1 → v4 (en passant par v2 et v3) avec de vraies données : les recettes saisies avec
/// l'application 0.1.0 doivent survivre, « Astuces » fusionnées dans « Notes ».
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  v1.RecipesData recipe(String id, {String notes = '', String tips = ''}) =>
      v1.RecipesData(
        id: id,
        title: 'Recette $id',
        description: 'Une description',
        source: 'Livre',
        notes: notes,
        tips: tips,
        servings: 4,
        prepMinutes: 10,
        timesCooked: 2,
        createdAt: '2026-10-20T08:00:00.000Z',
        updatedAt: '2026-10-21T08:00:00.000Z',
      );

  test('les recettes de la 0.1.0 survivent à la migration', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insertAll(oldDb.recipes, [
        recipe('both', notes: 'Ma note', tips: 'Une astuce'),
        recipe('tips-only', tips: '  Précuire la pâte  '),
        recipe('notes-only', notes: 'Seulement une note'),
        recipe('neither'),
      ]);
      batch.insert(
        oldDb.ingredients,
        v1.IngredientsData(
          id: 'i1',
          recipeId: 'both',
          position: 0,
          isSection: 0,
          name: 'farine',
          quantity: 250,
          unit: 'g',
          note: '',
          optional: 0,
        ),
      );
      batch.insertAll(oldDb.recipeSteps, [
        v1.RecipeStepsData(
          id: 's1',
          recipeId: 'both',
          position: 0,
          body: 'Mélanger.',
        ),
        v1.RecipeStepsData(
          id: 's2',
          recipeId: 'both',
          position: 1,
          body: 'Cuire.',
        ),
      ]);
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);

    final repo = RecipeRepository(db);
    final both = (await repo.getRecipe('both'))!;
    expect(both.title, 'Recette both');
    expect(both.notes, 'Ma note\n\nUne astuce');
    expect(both.servings, 4);
    expect(both.timesCooked, 2);
    expect(both.ingredients.single.name, 'farine');
    expect(both.ingredients.single.quantity, 250);
    expect(both.steps.map((s) => s.text), ['Mélanger.', 'Cuire.']);
    expect(both.steps.map((s) => s.title), ['', '']);

    expect((await repo.getRecipe('tips-only'))!.notes, 'Précuire la pâte');
    expect((await repo.getRecipe('notes-only'))!.notes, 'Seulement une note');
    expect((await repo.getRecipe('neither'))!.notes, '');
    expect(await repo.getAllWithDetails(), hasLength(4));

    // Après la migration, on peut écrire des titres d'étapes.
    final saved = await repo.save(
      both.copyWith(
        steps: [RecipeStep(id: 's1', title: 'Biscuit', text: 'Mélanger.')],
      ),
    );
    expect((await repo.getRecipe('both'))!.steps.single.title, 'Biscuit');
    expect(saved.steps, hasLength(1));
    await db.close();
  });
}
