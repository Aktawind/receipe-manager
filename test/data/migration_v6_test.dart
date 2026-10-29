import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/equipment_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/equipment.dart';

import 'generated_migrations/app/generated/schema.dart';
import 'generated_migrations/app/generated/schema_v5.dart' as v5;

/// Migration v5 → v6 avec les données de l'APK de test : le matériel écrit en
/// texte passe dans la liste commune, les recettes liées passent dans les
/// ingrédients. Rien ne se perd.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  v5.RecipesData recipe(String id, String title, {String equipment = ''}) =>
      v5.RecipesData(
        id: id,
        title: title,
        description: '',
        source: '',
        notes: 'Une note',
        tips: '',
        servingsUnit: '',
        timesCooked: 0,
        isFavorite: 0,
        course: '',
        category: '',
        collections: '',
        equipment: equipment,
        videoLinks: '',
        createdAt: '2026-10-28T08:00:00.000Z',
        updatedAt: '2026-10-28T08:00:00.000Z',
      );

  v5.IngredientsData ingredient(
    String id,
    String recipeId,
    int position,
    String name,
  ) => v5.IngredientsData(
    id: id,
    recipeId: recipeId,
    position: position,
    isSection: 0,
    name: name,
    quantity: position == 0 ? 1 : null,
    unit: '',
    note: '',
    optional: 0,
    substitutes: '',
  );

  test('matériel en texte → liste commune ; liens → ingrédients', () async {
    final schema = await verifier.schemaAt(5);
    final oldDb = v5.DatabaseAtV5(schema.newConnection());
    await oldDb.batch((batch) {
      batch.insertAll(oldDb.recipes, [
        recipe('pate', 'Pâte brisée', equipment: 'Rouleau'),
        recipe('sauce', 'Sauce tomate'),
        recipe(
          'quiche',
          'Quiche lorraine',
          equipment: 'Moule à tarte\n\nrouleau \nMoule  à tarte',
        ),
        recipe('vide', 'Sans rien'),
      ]);
      batch.insertAll(oldDb.ingredients, [
        // « 1 pâte brisée » existe déjà dans la liste : elle devient le lien.
        ingredient('q1', 'quiche', 0, 'pâte brisée'),
        ingredient('q2', 'quiche', 1, 'lardons'),
      ]);
      batch.insertAll(oldDb.recipeLinks, [
        v5.RecipeLinksData(
          recipeId: 'quiche',
          position: 0,
          linkedRecipeId: 'pate',
        ),
        // Pas dans la liste : une ligne est ajoutée à la fin.
        v5.RecipeLinksData(
          recipeId: 'quiche',
          position: 1,
          linkedRecipeId: 'sauce',
        ),
        // Recette liée disparue : ignorée sans erreur.
        v5.RecipeLinksData(
          recipeId: 'quiche',
          position: 2,
          linkedRecipeId: 'fantome',
        ),
      ]);
    });
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 8);
    final repo = RecipeRepository(db);
    final equipment = EquipmentRepository(db);

    // Matériel : « Rouleau » et « rouleau » sont le même, comme les deux
    // écritures de « Moule à tarte ».
    final catalog = await equipment.getAll();
    expect(catalog.map((e) => e.name).toList()..sort(), [
      'Moule à tarte',
      'Rouleau',
    ]);
    final rouleau = EquipmentItem.idForName('rouleau');
    final moule = EquipmentItem.idForName('moule à tarte');
    expect((await repo.getRecipe('quiche'))!.equipmentIds, [moule, rouleau]);
    expect((await repo.getRecipe('pate'))!.equipmentIds, [rouleau]);
    expect((await repo.getRecipe('vide'))!.equipmentIds, isEmpty);

    // Liens : la ligne « pâte brisée » est devenue le lien et garde sa
    // quantité ; la sauce a été ajoutée à la fin.
    final quiche = (await repo.getRecipe('quiche'))!;
    expect(quiche.ingredients.map((i) => i.name), [
      'Pâte brisée',
      'lardons',
      'Sauce tomate',
    ]);
    expect(quiche.ingredients.map((i) => i.linkedRecipeId), [
      'pate',
      null,
      'sauce',
    ]);
    expect(quiche.ingredients.first.id, 'q1');
    expect(quiche.ingredients.first.quantity, 1);
    expect(quiche.linkedRecipeIds, ['pate', 'sauce']);
    expect(quiche.notes, 'Une note');

    // Les tables de l'ancien modèle ont disparu, et le reste est intact.
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(
      tables.map((t) => t.read<String>('name')),
      isNot(contains('recipe_links')),
    );
    expect(await repo.getAllWithDetails(), hasLength(4));
    await db.close();
  });
}
