import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/backup/backup_format.dart';
import 'package:recettes/data/backup/backup_service.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/photo_store.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

class _Env {
  _Env(Directory root)
    : db = AppDatabase(NativeDatabase.memory()),
      photos = PhotoStore(Directory('${root.path}/photos')) {
    repo = RecipeRepository(db);
    service = BackupService(
      repository: repo,
      photos: photos,
      backupsDirectory: Directory('${root.path}/backups'),
      appVersion: '0.1.0',
    );
  }

  final AppDatabase db;
  final PhotoStore photos;
  late final RecipeRepository repo;
  late final BackupService service;
}

void main() {
  late Directory temp;
  late _Env source;
  late _Env target;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('backup_test');
    source = _Env(Directory('${temp.path}/source'));
    target = _Env(Directory('${temp.path}/target'));
  });

  tearDown(() async {
    await source.db.close();
    await target.db.close();
    await temp.delete(recursive: true);
  });

  Future<Recipe> addRecipe(_Env env, String title, {String? photo}) async {
    if (photo != null) await env.photos.write(photo, utf8.encode('img-$photo'));
    final created = await env.repo.create();
    return env.repo.save(
      created.copyWith(
        title: title,
        servings: () => 4,
        mainPhoto: () => photo,
        ingredients: [
          IngredientLine(
            id: RecipeRepository.newId(),
            name: 'farine',
            quantity: 1.5,
            unit: 'kg',
          ),
        ],
        steps: [
          RecipeStep(
            id: RecipeRepository.newId(),
            title: 'Pâte',
            text: 'Mélanger.',
          ),
        ],
      ),
    );
  }

  test('aller-retour complet : recettes, détails, photos, corbeille', () async {
    final tart = await addRecipe(source, 'Tarte', photo: 'tarte.jpg');
    final soup = await addRecipe(source, 'Soupe');
    await source.repo.moveToTrash(soup.id);

    final zip = await source.service.exportZip();
    final contents = target.service.readZip(zip);
    final result = await target.service.import(contents, ImportMode.merge);

    expect(result.added, 2);
    final imported = (await target.repo.getRecipe(tart.id))!;
    expect(imported.title, 'Tarte');
    expect(imported.ingredients.single.quantity, 1.5);
    expect(imported.steps.single.text, 'Mélanger.');
    expect(imported.steps.single.title, 'Pâte');
    expect(imported.updatedAt, tart.updatedAt);
    expect(
      await target.photos.file('tarte.jpg').readAsString(),
      'img-tarte.jpg',
    );
    expect((await target.repo.getRecipe(soup.id))!.isDeleted, isTrue);
  });

  test('fusion : garde la version la plus récente, ne supprime rien', () async {
    final shared = await addRecipe(source, 'Version sauvegarde');
    final zip = await source.service.exportZip();

    // Sur la cible : la même recette modifiée plus tard, et une autre.
    await target.repo.put(
      shared.copyWith(
        title: 'Version plus récente',
        updatedAt: shared.updatedAt.add(const Duration(days: 1)),
      ),
    );
    final local = await addRecipe(target, 'Locale');

    final result = await target.service.import(
      target.service.readZip(zip),
      ImportMode.merge,
    );
    expect(result.unchanged, 1);
    expect(
      (await target.repo.getRecipe(shared.id))!.title,
      'Version plus récente',
    );
    expect(await target.repo.getRecipe(local.id), isNotNull);
  });

  test('remplacement : seules les recettes de la sauvegarde restent', () async {
    await addRecipe(source, 'A');
    final zip = await source.service.exportZip();
    final local = await addRecipe(target, 'Locale', photo: 'locale.jpg');

    await target.service.import(
      target.service.readZip(zip),
      ImportMode.replace,
    );
    expect(await target.repo.getRecipe(local.id), isNull);
    expect((await target.repo.watchRecipes().first).single.title, 'A');
    expect(await target.photos.file('locale.jpg').exists(), isFalse);
  });

  test('une sauvegarde automatique est faite avant l’import', () async {
    await addRecipe(target, 'Avant');
    final zip = await source.service.exportZip();
    final result = await target.service.import(
      target.service.readZip(zip),
      ImportMode.replace,
    );
    final safety = target.service.readZip(
      await result.safetyBackup.readAsBytes(),
    );
    expect(safety.recipes.single.title, 'Avant');
  });

  test('une sauvegarde de la 0.1.0 (version 1) est encore lue', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          BackupFormat.dataFile,
          jsonEncode({
            'format': 'recettes-backup',
            'version': 1,
            'recipes': [
              {
                'id': 'old-1',
                'title': 'Tarte',
                'notes': 'Ma note',
                'tips': 'Précuire la pâte',
                'createdAt': '2026-10-01T08:00:00Z',
                'updatedAt': '2026-10-02T08:00:00Z',
                'ingredients': [
                  {'id': 'i1', 'name': 'farine', 'quantity': 250, 'unit': 'g'},
                ],
                'steps': [
                  {'id': 's1', 'text': 'Mélanger.'},
                ],
              },
              {
                'id': 'old-2',
                'title': 'Soupe',
                'tips': 'Mixer très fin',
                'createdAt': '2026-10-01T08:00:00Z',
                'updatedAt': '2026-10-02T08:00:00Z',
              },
            ],
          }),
        ),
      );
    final contents = target.service.readZip(ZipEncoder().encode(archive));
    expect(contents.recipes[0].notes, 'Ma note\n\nPrécuire la pâte');
    expect(contents.recipes[1].notes, 'Mixer très fin');
    expect(contents.recipes[0].steps.single.title, '');
    await target.service.import(contents, ImportMode.merge);
    expect((await target.repo.getRecipe('old-1'))!.notes, contains('Précuire'));
  });

  test('l’export est en version 2, sans champ « tips »', () async {
    await addRecipe(source, 'Tarte');
    final archive = ZipDecoder().decodeBytes(await source.service.exportZip());
    final json = jsonDecode(
      utf8.decode(archive.findFile(BackupFormat.dataFile)!.content),
    ) as Map<String, Object?>;
    expect(json['version'], 2);
    final recipe = (json['recipes'] as List).single as Map<String, Object?>;
    expect(recipe.containsKey('tips'), isFalse);
  });

  group('fichiers refusés', () {
    List<int> zipWith(String json) {
      final archive = Archive()
        ..addFile(ArchiveFile.string(BackupFormat.dataFile, json));
      return ZipEncoder().encode(archive);
    }

    void expectError(List<int> bytes, BackupError error) {
      expect(
        () => target.service.readZip(bytes),
        throwsA(
          isA<BackupFormatException>().having((e) => e.error, 'error', error),
        ),
      );
    }

    test('pas un ZIP', () {
      expectError(utf8.encode('bonjour'), BackupError.notABackup);
    });

    test('autre format', () {
      expectError(zipWith('{"format":"autre"}'), BackupError.notABackup);
    });

    test('version plus récente', () {
      expectError(
        zipWith('{"format":"recettes-backup","version":99,"recipes":[]}'),
        BackupError.newerVersion,
      );
    });

    test('photo manquante', () {
      expectError(
        zipWith(
          jsonEncode({
            'format': 'recettes-backup',
            'version': 1,
            'recipes': [
              {
                'id': 'r1',
                'mainPhoto': 'absente.jpg',
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            ],
          }),
        ),
        BackupError.missingPhoto,
      );
    });

    test('nom de photo dangereux', () {
      expectError(
        zipWith(
          jsonEncode({
            'format': 'recettes-backup',
            'version': 1,
            'recipes': [
              {
                'id': 'r1',
                'mainPhoto': '../evil.jpg',
                'createdAt': '2026-01-01T00:00:00Z',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            ],
          }),
        ),
        BackupError.invalid,
      );
    });

    test('un import invalide ne modifie rien', () async {
      final kept = await addRecipe(target, 'Conservée');
      expectError(zipWith('{"format":"recettes-backup"}'), BackupError.invalid);
      expect(await target.repo.getRecipe(kept.id), isNotNull);
    });
  });
}
