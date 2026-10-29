import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/equipment_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/equipment.dart';

void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late RecipeRepository recipes;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    equipment = EquipmentRepository(db);
    recipes = RecipeRepository(db);
  });

  tearDown(() => db.close());

  test('un nom = un matériel, à la casse et aux accents près', () async {
    final a = await equipment.findOrCreate('Moule à cake');
    final b = await equipment.findOrCreate('  moule  a CAKE ');
    expect(b.id, a.id);
    expect(await equipment.getAll(), hasLength(1));
    expect((await equipment.watchAll().first).single.name, 'Moule à cake');
  });

  test('la liste est triée par nom, sans tenir compte des accents', () async {
    for (final name in ['Robot', 'Écumoire', 'Fouet', 'cocotte']) {
      await equipment.findOrCreate(name);
    }
    expect((await equipment.watchAll().first).map((e) => e.name), [
      'Cocotte',
      'Écumoire',
      'Fouet',
      'Robot',
    ]);
  });

  test('renommer : refusé si le nom existe déjà', () async {
    final fouet = await equipment.findOrCreate('Fouet');
    await equipment.findOrCreate('Robot');
    expect(await equipment.rename(fouet.id, 'robot'), isFalse);
    expect(await equipment.rename(fouet.id, 'Fouet électrique'), isTrue);
    expect(await equipment.rename(fouet.id, '  '), isFalse);
    expect((await equipment.watchAll().first).map((e) => e.name), [
      'Fouet électrique',
      'Robot',
    ]);
  });

  test(
    'supprimer : retiré des recettes, ordre refermé, recette mise à jour',
    () async {
      final a = await equipment.findOrCreate('Moule');
      final b = await equipment.findOrCreate('Fouet');
      final c = await equipment.findOrCreate('Robot');
      final recipe = await recipes.save(
        (await recipes.create()).copyWith(equipmentIds: [a.id, b.id, c.id]),
      );
      expect(await equipment.watchUsage().first, {a.id: 1, b.id: 1, c.id: 1});

      await equipment.delete(b.id);
      final after = (await recipes.getRecipe(recipe.id))!;
      expect(after.equipmentIds, [a.id, c.id]);
      expect(
        after.updatedAt.isAfter(recipe.updatedAt) ||
            after.updatedAt == recipe.updatedAt,
        isTrue,
      );
      expect((await equipment.watchAll().first).map((e) => e.name), [
        'Moule',
        'Robot',
      ]);

      // Suppression douce : l'entrée reste (synchro), et un nom retapé la ressuscite.
      expect(
        (await equipment.getAll()).where((e) => e.isDeleted),
        hasLength(1),
      );
      final revived = await equipment.findOrCreate('fouet');
      expect(revived.id, b.id);
      expect(revived.isDeleted, isFalse);
    },
  );

  test('le matériel des recettes à la corbeille ne compte pas', () async {
    final a = await equipment.findOrCreate('Moule');
    final recipe = await recipes.save(
      (await recipes.create()).copyWith(equipmentIds: [a.id]),
    );
    await recipes.moveToTrash(recipe.id);
    expect(await equipment.watchUsage().first, isEmpty);
  });

  test('les noms commencent par une majuscule', () async {
    final a = await equipment.findOrCreate('moule à cake');
    expect(a.name, 'Moule à cake');
    final b = await equipment.findOrCreate('écumoire');
    expect(b.name, 'Écumoire');
    final fouet = await equipment.findOrCreate('Fouet');
    expect(await equipment.rename(fouet.id, 'fouet électrique'), isTrue);
    expect((await equipment.watchAll().first).map((e) => e.name), [
      'Écumoire',
      'Fouet électrique',
      'Moule à cake',
    ]);
  });

  test('capitalizeNames corrige les anciens noms, une seule fois', () async {
    final now = DateTime(2026, 10, 29);
    await equipment.put(
      EquipmentItem(id: 'old', name: 'robot', createdAt: now, updatedAt: now),
    );
    await equipment.put(
      EquipmentItem(id: 'ok', name: 'Fouet', createdAt: now, updatedAt: now),
    );
    await equipment.capitalizeNames();
    final items = {for (final e in await equipment.getAll()) e.id: e};
    expect(items['old']!.name, 'Robot');
    expect(items['old']!.updatedAt.isAfter(now), isTrue);
    expect(items['ok']!.updatedAt, now, reason: 'déjà propre : inchangé');
  });
}
