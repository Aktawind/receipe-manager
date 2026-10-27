import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Les photos des recettes, stockées en fichiers dans un dossier de l'app.
/// La base ne garde que leur nom de fichier.
class PhotoStore {
  PhotoStore(this.directory);

  final Directory directory;
  static const _uuid = Uuid();

  File file(String name) => File(p.join(directory.path, name));

  /// Copie [source] dans le dossier des photos sous un nouveau nom.
  Future<String> add(File source) async {
    await directory.create(recursive: true);
    final extension = p.extension(source.path).toLowerCase();
    final name = '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}';
    await source.copy(file(name).path);
    return name;
  }

  /// Écrit une photo sous un nom donné (import d'une sauvegarde).
  Future<void> write(String name, List<int> bytes) async {
    await directory.create(recursive: true);
    await file(name).writeAsBytes(bytes, flush: true);
  }

  Future<void> deleteAll(Iterable<String> names) async {
    for (final name in names) {
      final target = file(name);
      if (await target.exists()) await target.delete();
    }
  }

  /// Supprime les fichiers qu'aucune recette n'utilise plus.
  Future<void> deleteUnused(Set<String> used) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list()) {
      if (entity is File && !used.contains(p.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  /// Un nom de photo valide : pas de dossier, pas de « .. ».
  static bool isValidName(String name) =>
      name.isNotEmpty &&
      p.basename(name) == name &&
      name != '.' &&
      name != '..';
}
