import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/backup/backup_format.dart';
import 'package:recettes/data/backup/backup_service.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/equipment_repository.dart';
import 'package:recettes/data/photo_store.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

class _Env {
  _Env(Directory root)
    : db = AppDatabase(NativeDatabase.memory()),
      photos = PhotoStore(Directory('${root.path}/photos')) {
    repo = RecipeRepository(db);
    equipment = EquipmentRepository(db);
    service = BackupService(
      repository: repo,
      equipment: equipment,
      photos: photos,
      backupsDirectory: Directory('${root.path}/backups'),
      appVersion: '0.1.0',
    );
  }

  final AppDatabase db;
  final PhotoStore photos;
  late final RecipeRepository repo;
  late final EquipmentRepository equipment;
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

  test('l’export est en version 6, sans champ « tips »', () async {
    await addRecipe(source, 'Tarte');
    final archive = ZipDecoder().decodeBytes(await source.service.exportZip());
    final json = jsonDecode(
      utf8.decode(archive.findFile(BackupFormat.dataFile)!.content),
    ) as Map<String, Object?>;
    expect(json['version'], 6);
    final recipe = (json['recipes'] as List).single as Map<String, Object?>;
    expect(recipe.containsKey('tips'), isFalse);
  });

  test(
    'aller-retour des champs de la 0.2 (favori, statut, classement…)',
    () async {
      await source.photos.write('a.jpg', utf8.encode('a'));
      await source.photos.write('b.jpg', utf8.encode('b'));
      final base = await addRecipe(source, 'Quiche');
      final moule = await source.equipment.findOrCreate('Moule à tarte');
      final rouleau = await source.equipment.findOrCreate('Rouleau');
      final full = await source.repo.save(
        base.copyWith(
          isFavorite: true,
          rating: () => 4,
          status: () => RecipeStatus.validated,
          course: 'Plat',
          category: 'Tartes',
          collections: ['Hiver', 'Été'],
          mainPhoto: () => 'a.jpg',
          extraPhotos: ['b.jpg'],
          equipmentIds: [moule.id, rouleau.id],
          videoLinks: ['https://youtu.be/abc'],
          ingredients: [
            const IngredientLine(
              id: 'i-sub',
              name: 'beurre',
              quantity: 100,
              unit: 'g',
              substitutes: 'huile de coco',
            ),
            const IngredientLine(
              id: 'i-pate',
              name: 'Pâte brisée',
              quantity: 1,
              linkedRecipeId: 'pate',
            ),
          ],
        ),
      );

      final contents = target.service.readZip(await source.service.exportZip());
      await target.service.import(contents, ImportMode.merge);

      final imported = (await target.repo.getRecipe(full.id))!;
      expect(imported.isFavorite, isTrue);
      expect(imported.rating, 4);
      expect(imported.status, RecipeStatus.validated);
      expect(imported.course, 'Plat');
      expect(imported.category, 'Tartes');
      expect(imported.collections, ['Hiver', 'Été']);
      expect(imported.extraPhotos, ['b.jpg']);
      expect(imported.linkedRecipeIds, ['pate']);
      expect(imported.equipmentIds, [moule.id, rouleau.id]);
      expect(imported.videoLinks, ['https://youtu.be/abc']);
      expect(imported.ingredients.first.substitutes, 'huile de coco');
      // La liste commune du matériel suit la sauvegarde.
      expect(
        (await target.equipment.getAll()).map((e) => e.name).toList()..sort(),
        ['Moule à tarte', 'Rouleau'],
      );
      expect(await target.photos.file('b.jpg').readAsString(), 'b');
    },
  );

  test(
    'une sauvegarde v5 (test 0.2) se lit : matériel et liens convertis',
    () async {
      Map<String, Object?> recipe(
        String id,
        String title, {
        List<String> equipment = const [],
        List<String> linked = const [],
        List<Map<String, Object?>> ingredients = const [],
      }) => {
        'id': id,
        'title': title,
        'equipment': equipment,
        'linkedRecipes': linked,
        'ingredients': ingredients,
        'steps': [],
        'createdAt': '2026-10-28T08:00:00Z',
        'updatedAt': '2026-10-28T08:00:00Z',
      };
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            BackupFormat.dataFile,
            jsonEncode({
              'format': 'recettes-backup',
              'version': 5,
              'exportedAt': '2026-10-28T09:00:00Z',
              'recipes': [
                recipe('pate', 'Pâte brisée', equipment: ['Rouleau']),
                recipe(
                  'quiche',
                  'Quiche',
                  equipment: ['Moule à tarte', 'rouleau'],
                  linked: ['pate'],
                  ingredients: [
                    {
                      'id': 'i1',
                      'name': 'lardons',
                      'quantity': 200,
                      'unit': 'g',
                    },
                  ],
                ),
              ],
            }),
          ),
        );
      final contents = target.service.readZip(ZipEncoder().encode(archive));
      expect(contents.equipment.map((e) => e.name).toList()..sort(), [
        'Moule à tarte',
        'Rouleau',
      ]);
      await target.service.import(contents, ImportMode.merge);

      final quiche = (await target.repo.getRecipe('quiche'))!;
      expect(quiche.equipmentIds, hasLength(2));
      expect(
        quiche.equipmentIds.last,
        (await target.repo.getRecipe('pate'))!.equipmentIds.single,
        reason: 'même matériel, même identifiant',
      );
      expect(quiche.ingredients.map((i) => i.name), ['lardons', 'Pâte brisée']);
      expect(quiche.ingredients.last.linkedRecipeId, 'pate');
    },
  );

  test(
    'une sauvegarde v2 (0.1.0) se lit encore : champs 0.2 neutres',
    () async {
      final archive = Archive()
        ..addFile(
          ArchiveFile.string(
            BackupFormat.dataFile,
            jsonEncode({
              'format': 'recettes-backup',
              'version': 2,
              'recipes': [
                {
                  'id': 'v2-1',
                  'title': 'Ancienne',
                  'notes': 'Une note',
                  'createdAt': '2026-10-20T08:00:00Z',
                  'updatedAt': '2026-10-21T08:00:00Z',
                  'ingredients': [],
                  'steps': [],
                },
              ],
            }),
          ),
        );
      final contents = target.service.readZip(ZipEncoder().encode(archive));
      await target.service.import(contents, ImportMode.merge);
      final recipe = (await target.repo.getRecipe('v2-1'))!;
      expect(recipe.title, 'Ancienne');
      expect(recipe.isFavorite, isFalse);
      expect(recipe.rating, isNull);
      expect(recipe.collections, isEmpty);
      expect(recipe.extraPhotos, isEmpty);
    },
  );

  test('« addMissing » n’écrase jamais une recette déjà présente', () async {
    final mine = await addRecipe(target, 'Retouchée à la main');
    final incoming = mine.copyWith(
      title: 'Version du fichier',
      updatedAt: mine.updatedAt.add(const Duration(days: 30)),
    );
    final fresh = incoming.copyWith(title: 'Nouvelle');
    final result = await target.service.import(
      BackupContents([
        incoming,
        Recipe(
          id: 'new',
          title: 'Nouvelle',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ], const {}),
      ImportMode.addMissing,
    );
    expect(fresh.title, 'Nouvelle');
    expect(result.added, 1);
    expect(result.unchanged, 1);
    expect(
      (await target.repo.getRecipe(mine.id))!.title,
      'Retouchée à la main',
    );
  });

  test('aperçu Recipe Keeper : déjà présentes et titres semblables', () async {
    final known = await addRecipe(target, 'Banana Bread');
    await addRecipe(target, 'Crème brûlée');
    Recipe incoming(String id, String title) => Recipe(
      id: id,
      title: title,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final preview = await target.service.previewRecipeKeeper([
      incoming(known.id, 'Banana Bread'),
      incoming('x1', 'Creme brulee'),
      incoming('x2', 'Autre'),
    ]);
    expect(preview.found, 3);
    expect(preview.alreadyPresent, 1);
    expect(preview.toAdd, 2);
    expect(preview.sameTitle, ['Creme brulee']);
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
