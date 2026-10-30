import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/label.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v6.dart' as v6;

/// Migration v6 → v8 (en passant par v7) avec les données de l'APK de test : le type de plat, la
/// catégorie et les collections en texte libre deviennent le classement commun.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  v6.RecipesData recipe(
    String id, {
    String course = '',
    String category = '',
    String collections = '',
  }) => v6.RecipesData(
    id: id,
    title: 'Recette $id',
    description: '',
    source: '',
    notes: 'Une note',
    tips: '',
    servingsUnit: '',
    timesCooked: 0,
    isFavorite: 0,
    course: course,
    category: category,
    collections: collections,
    equipment: '',
    videoLinks: '',
    createdAt: '2026-10-28T08:00:00.000Z',
    updatedAt: '2026-10-28T08:00:00.000Z',
  );

  test(
    'le classement en texte devient des catégories, saisons, collections',
    () async {
      final schema = await verifier.schemaAt(6);
      final oldDb = v6.DatabaseAtV6(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.recipes, [
          recipe(
            'a',
            course: 'Dessert',
            category: 'Gâteaux',
            collections: 'Automne\nÉté\nHiver\nPrintemps',
          ),
          recipe(
            'b',
            course: 'Dessert',
            category: 'Gâteau',
            collections: 'Été',
          ),
          recipe(
            'c',
            course: 'Plat',
            category: 'Riz',
            collections: 'Pique-nique',
          ),
          recipe('d', course: 'Plat', category: 'Riz et céréales'),
          recipe('e'),
        ]);
      });
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 8);
      final repo = RecipeRepository(db);
      final labels = {
        for (final l in await LabelRepository(db).getAll()) l.id: l,
      };

      Future<List<String>> pathsOf(String id) async => [
        for (final labelId in (await repo.getRecipe(id))!.labelIds)
          [
            if (labels[labelId]!.parentId != null)
              labels[labels[labelId]!.parentId]!.name,
            labels[labelId]!.name,
          ].join(' › '),
      ];

      expect(
        await pathsOf('a'),
        unorderedEquals(['Desserts › Gâteaux', 'Toute saison']),
      );
      expect(
        await pathsOf('b'),
        unorderedEquals(['Desserts › Gâteaux', 'Été']),
      );
      expect(
        await pathsOf('c'),
        unorderedEquals(['Plats › Riz et céréales', 'Pique-nique']),
      );
      expect(await pathsOf('d'), ['Plats › Riz et céréales']);
      expect(await pathsOf('e'), isEmpty);

      // Le classement par défaut est en place, même pour ce qui n'est pas utilisé.
      final names = labels.values
          .map((l) => '${l.kind.code}:${l.name}')
          .toSet();
      expect(
        names,
        containsAll([
          'category:Plats',
          'category:Desserts',
          'category:Boissons',
          'season:Toute saison',
          'cuisine:Italienne',
        ]),
      );
      // « Pique-nique » reste une collection (l'occasion du même nom, vide, a
      // disparu avec la version 8).
      final picnics = labels.values.where((l) => l.name == 'Pique-nique');
      expect(picnics.map((l) => l.kind), [LabelKind.collection]);
      expect(
        labels.values.where((l) => l.name == 'Gâteaux'),
        hasLength(1),
        reason: 'Gâteau et Gâteaux sont fusionnés',
      );

      // Les anciens champs sont vidés, le reste de la recette est intact.
      final old = await db
          .customSelect(
            "SELECT course, category, collections FROM recipes WHERE id = 'a'",
          )
          .getSingle();
      expect(old.read<String>('course'), '');
      expect(old.read<String>('category'), '');
      expect(old.read<String>('collections'), '');
      expect((await repo.getRecipe('a'))!.notes, 'Une note');
      await db.close();
    },
  );
}
