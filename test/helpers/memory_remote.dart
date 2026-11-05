import 'dart:typed_data';

import 'package:recettes/data/sync/drive_remote.dart';
import 'package:recettes/data/sync/sync_remote.dart';

/// Un dossier distant en mémoire, qui se comporte comme Drive : chaque écriture
/// a une version, et les changements se lisent depuis un jeton.
class MemoryRemote implements DriveFolder {
  final Map<String, Uint8List> files = {};
  final List<(int, RemoteChange)> _log = [];
  int _counter = 0;

  /// Appels reçus, pour vérifier ce qui circule.
  final List<String> calls = [];

  /// Les jetons non nuls sont refusés (trop anciens).
  bool expireTokens = false;

  /// Chemins dont la lecture échoue (réseau coupé…).
  final Set<String> failingReads = {};

  @override
  Future<RemoteChanges> changes(String? token) async {
    calls.add('changes');
    if (expireTokens && token != null) throw const ChangesTokenExpired();
    final since = token == null ? 0 : int.parse(token);
    // Seul le dernier état de chaque fichier compte, comme avec Drive.
    final latest = <String, (int, RemoteChange)>{};
    for (final entry in _log) {
      if (entry.$1 > since) latest[entry.$2.path] = entry;
    }
    return RemoteChanges([
      for (final entry in latest.values) entry.$2,
    ], '$_counter');
  }

  @override
  Future<Uint8List> read(String path) async {
    calls.add('read $path');
    if (failingReads.contains(path)) throw StateError('réseau coupé');
    final bytes = files[path];
    if (bytes == null) throw StateError('introuvable : $path');
    return bytes;
  }

  @override
  Future<String> write(String path, Uint8List bytes) async {
    calls.add('write $path');
    // Comme Drive : on n'écrit que dans les dossiers que l'app crée.
    final folder = path.split('/').first;
    if (!DriveRemote.subfolders.contains(folder)) {
      throw StateError('dossier inconnu sur Drive : $folder');
    }
    files[path] = bytes;
    final version = '${++_counter}';
    _log.add((_counter, RemoteChange(path, version: version)));
    return version;
  }

  @override
  Future<void> delete(String path) async {
    calls.add('delete $path');
    files.remove(path);
    _log.add((++_counter, RemoteChange(path, deleted: true)));
  }

  @override
  Future<void> deleteAll() async {
    calls.add('deleteAll');
    files.clear();
    backupFiles.clear();
  }

  /// Sauvegardes : identifiant → (nom, contenu, date).
  final Map<String, (String, Uint8List, DateTime)> backupFiles = {};
  int _backupCounter = 0;

  @override
  Future<List<RemoteBackup>> listBackups() async {
    final all = [
      for (final e in backupFiles.entries)
        RemoteBackup(
          id: e.key,
          name: e.value.$1,
          createdAt: e.value.$3,
          size: e.value.$2.length,
        ),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<void> uploadBackup(String name, Uint8List bytes) async {
    calls.add('uploadBackup $name');
    backupFiles['b${++_backupCounter}'] = (
      name,
      bytes,
      DateTime.utc(2030).add(Duration(minutes: _backupCounter)),
    );
  }

  @override
  Future<Uint8List> downloadBackup(String id) async => backupFiles[id]!.$2;

  @override
  Future<void> deleteBackup(String id) async {
    calls.add('deleteBackup $id');
    backupFiles.remove(id);
  }

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;
}
