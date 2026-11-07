import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../core/format/text_search.dart';
import '../../domain/equipment.dart';
import '../../domain/label.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../domain/shopping.dart';
import '../equipment_repository.dart';
import '../label_repository.dart';
import '../photo_store.dart';
import '../planning_repository.dart';
import '../recipe_repository.dart';
import '../shopping_repository.dart';
import 'backup_format.dart';

enum ImportMode {
  /// Ajoute les nouvelles recettes et met à jour celles qui ont été modifiées
  /// plus récemment dans la sauvegarde. Rien n'est supprimé.
  merge,

  /// Remplace toutes les recettes par celles de la sauvegarde.
  replace,

  /// N'ajoute que les recettes absentes : celles qui existent déjà (même
  /// identifiant) ne sont jamais modifiées. Sert à l'import Recipe Keeper, qui
  /// peut être refait sans écraser ce qu'on a retouché depuis.
  addMissing,
}

/// Contenu d'une sauvegarde lue et validée, prête à être importée.
class BackupContents {
  const BackupContents(
    this.recipes,
    this.photos, {
    this.equipment = const [],
    this.labels = const [],
    this.shoppingLists = const [],
    this.aisles = const [],
    this.productAisles = const [],
    this.mealSlots = const [],
    this.plannedMeals = const [],
  });

  final List<Recipe> recipes;

  /// Le planning : créneaux et repas.
  final List<MealSlot> mealSlots;
  final List<PlannedMeal> plannedMeals;

  /// Les listes de courses, les rayons et le rayon retenu pour les produits.
  final List<ShoppingList> shoppingLists;
  final List<Aisle> aisles;
  final List<ProductAisle> productAisles;

  /// La liste commune du matériel.
  final List<EquipmentItem> equipment;

  /// Le classement commun (catégories, étiquettes, saisons…).
  final List<Label> labels;
  final Map<String, List<int>> photos;
}

class ImportResult {
  const ImportResult({
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.safetyBackup,
  });

  final int added;
  final int updated;
  final int unchanged;

  /// Sauvegarde automatique faite juste avant l'import.
  final File safetyBackup;
}

/// Ce que l'import Recipe Keeper va faire, avant d'écrire quoi que ce soit.
class RecipeKeeperPreview {
  const RecipeKeeperPreview({
    required this.found,
    required this.alreadyPresent,
    required this.sameTitle,
  });

  final int found;

  /// Recettes déjà importées (même identifiant) : elles seront ignorées.
  final int alreadyPresent;

  /// Titres des recettes du fichier qui ressemblent à une recette déjà
  /// présente sous un autre identifiant (saisie à la main, par exemple).
  final List<String> sameTitle;

  int get toAdd => found - alreadyPresent;
}

/// Export et import des sauvegardes complètes (ZIP : JSON + photos).
class BackupService {
  BackupService({
    required this.repository,
    required this.equipment,
    required this.labels,
    required this.shopping,
    required this.planning,
    required this.photos,
    required this.backupsDirectory,
    required this.appVersion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RecipeRepository repository;
  final EquipmentRepository equipment;
  final LabelRepository labels;
  final ShoppingRepository shopping;
  final PlanningRepository planning;
  final PhotoStore photos;
  final Directory backupsDirectory;
  final String appVersion;
  final DateTime Function() _clock;

  /// Nombre de sauvegardes automatiques conservées.
  static const keptSafetyBackups = 5;

  /// Sauvegarde complète, corbeille comprise, au format ZIP.
  Future<List<int>> exportZip() async {
    final recipes = await repository.getAllWithDetails();
    final archive = Archive();
    final json = const JsonEncoder.withIndent('  ').convert(
      BackupFormat.encode(
        recipes,
        equipment: await equipment.getAll(),
        labels: await labels.getAll(),
        shoppingLists: await shopping.getAllLists(),
        aisles: await shopping.getAllAisles(),
        productAisles: await shopping.getAllProductAisles(),
        mealSlots: await planning.getAllSlots(),
        plannedMeals: await planning.getAllMeals(),
        exportedAt: _clock(),
        appVersion: appVersion,
      ),
    );
    archive.addFile(ArchiveFile.string(BackupFormat.dataFile, json));
    for (final name in recipes.expand((r) => r.allPhotos).toSet()) {
      final file = photos.file(name);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(
          ArchiveFile.bytes('${BackupFormat.photosFolder}$name', bytes)
            ..compression = CompressionType.none,
        );
      }
    }
    return ZipEncoder().encode(archive);
  }

  /// La sauvegarde sans les photos (données seules), pour Drive : les photos y
  /// sont déjà, dans `media/`, et ne sont jamais supprimées.
  Future<List<int>> exportJson() async {
    final json = const JsonEncoder.withIndent('  ').convert(
      BackupFormat.encode(
        await repository.getAllWithDetails(),
        equipment: await equipment.getAll(),
        labels: await labels.getAll(),
        shoppingLists: await shopping.getAllLists(),
        aisles: await shopping.getAllAisles(),
        productAisles: await shopping.getAllProductAisles(),
        mealSlots: await planning.getAllSlots(),
        plannedMeals: await planning.getAllMeals(),
        exportedAt: _clock(),
        appVersion: appVersion,
      ),
    );
    return utf8.encode(json);
  }

  /// Lit et valide une sauvegarde de données seules (sans photos).
  BackupContents readJson(List<int> bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const BackupFormatException(BackupError.invalid, 'json');
    }
    final decoded = BackupFormat.decode(json);
    return BackupContents(
      decoded.recipes,
      const {},
      equipment: decoded.equipment,
      labels: decoded.labels,
      shoppingLists: decoded.shoppingLists,
      aisles: decoded.aisles,
      productAisles: decoded.productAisles,
      mealSlots: decoded.mealSlots,
      plannedMeals: decoded.plannedMeals,
    );
  }

  /// Nom de fichier proposé pour un export.
  String exportFileName() {
    final now = _clock();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'recettes-${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.zip';
  }

  /// Lit et valide une sauvegarde sans rien modifier.
  BackupContents readZip(List<int> bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const BackupFormatException(BackupError.notABackup);
    }
    final data = archive.findFile(BackupFormat.dataFile);
    if (data == null) {
      throw const BackupFormatException(BackupError.notABackup);
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(data.content));
    } on FormatException {
      throw const BackupFormatException(BackupError.invalid, 'json');
    }
    final decoded = BackupFormat.decode(json);
    final recipes = decoded.recipes;
    final photoFiles = <String, List<int>>{};
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith(BackupFormat.photosFolder)) {
        final name = file.name.substring(BackupFormat.photosFolder.length);
        if (PhotoStore.isValidName(name)) photoFiles[name] = file.content;
      }
    }
    for (final name in recipes.expand((r) => r.allPhotos)) {
      if (!photoFiles.containsKey(name) && !photos.file(name).existsSync()) {
        throw BackupFormatException(BackupError.missingPhoto, name);
      }
    }
    return BackupContents(
      recipes,
      photoFiles,
      equipment: decoded.equipment,
      labels: decoded.labels,
      shoppingLists: decoded.shoppingLists,
      aisles: decoded.aisles,
      productAisles: decoded.productAisles,
      mealSlots: decoded.mealSlots,
      plannedMeals: decoded.plannedMeals,
    );
  }

  /// Compare un export Recipe Keeper avec les recettes de l'application.
  Future<RecipeKeeperPreview> previewRecipeKeeper(
    Iterable<Recipe> incoming,
  ) async {
    final existing = await repository.getAllWithDetails();
    final ids = {for (final r in existing) r.id};
    final titles = {
      for (final r in existing)
        if (r.title.trim().isNotEmpty) normalizeForSearch(r.title.trim()),
    };
    var found = 0, present = 0;
    final sameTitle = <String>[];
    for (final recipe in incoming) {
      found++;
      if (ids.contains(recipe.id)) {
        present++;
      } else if (titles.contains(normalizeForSearch(recipe.title.trim()))) {
        sameTitle.add(recipe.title);
      }
    }
    return RecipeKeeperPreview(
      found: found,
      alreadyPresent: present,
      sameTitle: sameTitle,
    );
  }

  /// Importe une sauvegarde validée. Une sauvegarde automatique est faite
  /// avant, et l'écriture se fait en une transaction : en cas d'échec, les
  /// données restent telles qu'avant l'import.
  Future<ImportResult> import(BackupContents contents, ImportMode mode) async {
    final safety = await writeSafetyBackup('avant-import');

    for (final entry in contents.photos.entries) {
      if (!await photos.file(entry.key).exists()) {
        await photos.write(entry.key, entry.value);
      }
    }

    var added = 0, updated = 0, unchanged = 0;
    await repository.transaction(() async {
      final existing = {
        for (final r in await repository.getAllWithDetails()) r.id: r,
      };
      final existingLabels = {
        for (final item in await labels.getAll()) item.id: item,
      };
      final existingEquipment = {
        for (final item in await equipment.getAll()) item.id: item,
      };
      final existingLists = {
        for (final l in await shopping.getAllLists()) l.id: l,
      };
      final existingAisles = {
        for (final a in await shopping.getAllAisles()) a.id: a,
      };
      final existingProducts = {
        for (final p in await shopping.getAllProductAisles()) p.key: p,
      };
      if (mode == ImportMode.replace) {
        // Les listes de courses d'une sauvegarde plus ancienne (sans listes)
        // ne doivent pas effacer celles de l'appareil.
        if (contents.shoppingLists.isNotEmpty) {
          await shopping.deleteAllLists();
          existingLists.clear();
        }
        await repository.deleteAll();
        await equipment.deleteAll();
        existingEquipment.clear();
        await labels.deleteAll();
        existingLabels.clear();
      }
      for (final item in contents.labels) {
        final current = existingLabels[item.id];
        if (current == null ||
            (mode != ImportMode.addMissing &&
                item.updatedAt.isAfter(current.updatedAt))) {
          await labels.put(item);
        }
      }
      bool newer(DateTime incoming, DateTime? current) =>
          current == null ||
          (mode != ImportMode.addMissing && incoming.isAfter(current));
      for (final aisle in contents.aisles) {
        if (newer(aisle.updatedAt, existingAisles[aisle.id]?.updatedAt)) {
          await shopping.putAisle(aisle);
        }
      }
      for (final product in contents.productAisles) {
        if (newer(
          product.updatedAt,
          existingProducts[product.key]?.updatedAt,
        )) {
          await shopping.putProductAisle(product);
        }
      }
      final existingSlots = {
        for (final s in await planning.getAllSlots()) s.id: s,
      };
      final existingMeals = {
        for (final m in await planning.getAllMeals()) m.id: m,
      };
      for (final slot in contents.mealSlots) {
        if (newer(slot.updatedAt, existingSlots[slot.id]?.updatedAt)) {
          await planning.putSlot(slot);
        }
      }
      for (final meal in contents.plannedMeals) {
        if (newer(meal.updatedAt, existingMeals[meal.id]?.updatedAt)) {
          await planning.putMeal(meal);
        }
      }
      for (final list in contents.shoppingLists) {
        if (newer(list.updatedAt, existingLists[list.id]?.updatedAt)) {
          await shopping.putList(list);
        }
      }
      for (final item in contents.equipment) {
        final current = existingEquipment[item.id];
        if (current == null ||
            (mode != ImportMode.addMissing &&
                item.updatedAt.isAfter(current.updatedAt))) {
          await equipment.put(item);
        }
      }
      for (final recipe in contents.recipes) {
        final current = existing[recipe.id];
        if (mode == ImportMode.replace) {
          await repository.put(recipe);
          current == null ? added++ : updated++;
        } else if (current == null) {
          await repository.put(recipe);
          added++;
        } else if (mode == ImportMode.addMissing) {
          unchanged++;
        } else if (recipe.updatedAt.isAfter(current.updatedAt)) {
          await repository.put(recipe);
          updated++;
        } else {
          unchanged++;
        }
      }
    });

    await photos.deleteUnused(await repository.usedPhotos());
    return ImportResult(
      added: added,
      updated: updated,
      unchanged: unchanged,
      safetyBackup: safety,
    );
  }

  /// Écrit une sauvegarde complète dans le dossier interne de l'app et ne
  /// garde que les [keptSafetyBackups] plus récentes.
  Future<File> writeSafetyBackup(String reason) async {
    await backupsDirectory.create(recursive: true);
    final bytes = await exportZip();
    final stamp = _clock().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(backupsDirectory.path, '$reason-$stamp.zip'));
    await file.writeAsBytes(bytes, flush: true);

    final existing =
        (await backupsDirectory.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.zip'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final old in existing.skip(keptSafetyBackups)) {
      await old.delete();
    }
    return file;
  }
}
