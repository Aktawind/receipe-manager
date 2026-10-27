import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../domain/recipe.dart';
import '../photo_store.dart';
import '../recipe_repository.dart';
import 'backup_format.dart';

enum ImportMode {
  /// Ajoute les nouvelles recettes et met à jour celles qui ont été modifiées
  /// plus récemment dans la sauvegarde. Rien n'est supprimé.
  merge,

  /// Remplace toutes les recettes par celles de la sauvegarde.
  replace,
}

/// Contenu d'une sauvegarde lue et validée, prête à être importée.
class BackupContents {
  const BackupContents(this.recipes, this.photos);

  final List<Recipe> recipes;
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

/// Export et import des sauvegardes complètes (ZIP : JSON + photos).
class BackupService {
  BackupService({
    required this.repository,
    required this.photos,
    required this.backupsDirectory,
    required this.appVersion,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RecipeRepository repository;
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
        exportedAt: _clock(),
        appVersion: appVersion,
      ),
    );
    archive.addFile(ArchiveFile.string(BackupFormat.dataFile, json));
    for (final name in recipes.map((r) => r.mainPhoto).nonNulls.toSet()) {
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
    final recipes = BackupFormat.decode(json);
    final photoFiles = <String, List<int>>{};
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith(BackupFormat.photosFolder)) {
        final name = file.name.substring(BackupFormat.photosFolder.length);
        if (PhotoStore.isValidName(name)) photoFiles[name] = file.content;
      }
    }
    for (final name in recipes.map((r) => r.mainPhoto).nonNulls) {
      if (!photoFiles.containsKey(name) && !photos.file(name).existsSync()) {
        throw BackupFormatException(BackupError.missingPhoto, name);
      }
    }
    return BackupContents(recipes, photoFiles);
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
      if (mode == ImportMode.replace) await repository.deleteAll();
      for (final recipe in contents.recipes) {
        final current = existing[recipe.id];
        if (mode == ImportMode.replace) {
          await repository.put(recipe);
          current == null ? added++ : updated++;
        } else if (current == null) {
          await repository.put(recipe);
          added++;
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
