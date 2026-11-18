import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v14.dart' as v14;

/// Migration v14 → v15 : les livres de cuisine arrivent ; les recettes
/// gardent tout (leur source comprise) et n'ont pas encore de livre.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test(
    'les recettes sont intactes, sans livre ; les livres s’ajoutent',
    () async {
      final schema = await verifier.schemaAt(14);
      final oldDb = v14.DatabaseAtV14(schema.newConnection());
      await oldDb
          .into(oldDb.recipes)
          .insert(
            const v14.RecipesData(
              id: 'a',
              title: 'Tarte au citron',
              description: '',
              source: 'Le grand livre de la pâtisserie p. 42',
              notes: 'Meringue bien cuite',
              tips: '',
              servingsUnit: '',
              timesCooked: 0,
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
      await verifier.migrateAndValidate(db, 15);

      final repo = RecipeRepository(db);
      final recipe = (await repo.getRecipe('a'))!;
      expect(recipe.title, 'Tarte au citron');
      expect(recipe.source, 'Le grand livre de la pâtisserie p. 42');
      expect(recipe.notes, 'Meringue bien cuite');
      expect((recipe.bookId, recipe.bookPage), (null, ''));
      expect(await repo.getAllBooks(), isEmpty);

      final book = await repo.createBook(
        title: 'Le grand livre de la pâtisserie',
      );
      await repo.save(recipe.copyWith(bookId: () => book.id, bookPage: '42'));
      final linked = (await repo.getRecipe('a'))!;
      expect((linked.bookId, linked.bookPage), (book.id, '42'));
      expect(
        (await repo.watchBooks().first).single.title,
        'Le grand livre de la pâtisserie',
      );
      await db.close();
    },
  );
}
