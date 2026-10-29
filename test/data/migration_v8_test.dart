import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/label.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v7.dart' as v7;

/// Migration v7 → v8 : le classement se limite à quatre familles. Étiquettes et
/// occasions utilisées deviennent des collections (les recettes gardent leur
/// classement), le type de repas disparaît, les éléments vides aussi.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  v7.LabelsData label(String id, String kind, String name) => v7.LabelsData(
    id: id,
    kind: kind,
    name: name,
    icon: '',
    color: '',
    position: 0,
    createdAt: '2026-10-29T08:00:00.000Z',
    updatedAt: '2026-10-29T08:00:00.000Z',
  );

  v7.RecipesData recipe(String id) => v7.RecipesData(
    id: id,
    title: 'Recette $id',
    description: '',
    source: '',
    notes: '',
    tips: '',
    servingsUnit: '',
    timesCooked: 0,
    isFavorite: 0,
    course: '',
    category: '',
    collections: '',
    equipment: '',
    videoLinks: '',
    createdAt: '2026-10-29T08:00:00.000Z',
    updatedAt: '2026-10-29T08:00:00.000Z',
  );

  test(
    'étiquettes et occasions → collections, type de repas supprimé',
    () async {
      final schema = await verifier.schemaAt(7);
      final oldDb = v7.DatabaseAtV7(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.labels, [
          label('plats', 'category', 'Plats'),
          label('hiver', 'season', 'Hiver'),
          label('rapide', 'tag', 'Rapide'),
          label('vege', 'tag', 'Végétarien'),
          label('eco', 'tag', 'Économique'), // inutilisé
          label('paques', 'occasion', 'Pâques'),
          label('noel', 'occasion', 'Noël'), // inutilisé
          label('diner', 'meal', 'Dîner'),
          label('coll-vege', 'collection', 'Végétarien'), // existe déjà
        ]);
        batch.insertAll(oldDb.recipes, [recipe('a'), recipe('b')]);
        batch.insertAll(oldDb.recipeLabels, [
          v7.RecipeLabelsData(recipeId: 'a', labelId: 'plats', sortIndex: 0),
          v7.RecipeLabelsData(recipeId: 'a', labelId: 'rapide', sortIndex: 0),
          v7.RecipeLabelsData(recipeId: 'a', labelId: 'vege', sortIndex: 0),
          v7.RecipeLabelsData(
            recipeId: 'a',
            labelId: 'coll-vege',
            sortIndex: 0,
          ),
          v7.RecipeLabelsData(recipeId: 'b', labelId: 'paques', sortIndex: 0),
          v7.RecipeLabelsData(recipeId: 'b', labelId: 'diner', sortIndex: 0),
          v7.RecipeLabelsData(recipeId: 'b', labelId: 'hiver', sortIndex: 0),
        ]);
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      final repo = RecipeRepository(db);
      final labels = {
        for (final l in await LabelRepository(db).getAll()) l.id: l,
      };

      // Plus que quatre familles ; rien d'inutilisé n'est resté.
      expect(labels.values.map((l) => l.kind).toSet(), {
        LabelKind.category,
        LabelKind.season,
        LabelKind.collection,
      });
      final collections =
          labels.values
              .where((l) => l.kind == LabelKind.collection)
              .map((l) => l.name)
              .toList()
            ..sort();
      expect(collections, ['Pâques', 'Rapide', 'Végétarien']);

      List<String> namesOf(String recipeId, dynamic r) =>
          [for (final id in r.labelIds) labels[id]!.name]..sort();
      final a = (await repo.getRecipe('a'))!;
      final b = (await repo.getRecipe('b'))!;
      // « Végétarien » (étiquette) et la collection du même nom ne font qu'un.
      expect(namesOf('a', a), ['Plats', 'Rapide', 'Végétarien']);
      expect(namesOf('b', b), ['Hiver', 'Pâques']);
      await db.close();
    },
  );
}
