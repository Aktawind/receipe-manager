import 'dart:typed_data';

import 'package:recettes/data/sync/sync_remote.dart';

/// Un dossier distant en mémoire, qui se comporte comme Drive : chaque écriture
/// a une version, et les changements se lisent depuis un jeton.
class MemoryRemote implements SyncRemote {
  final Map<String, Uint8List> files = {};
  final List<(int, RemoteChange)> _log = [];
  int _counter = 0;

  /// Appels reçus, pour vérifier ce qui circule.
  final List<String> calls = [];

  /// Chemins dont la lecture échoue (réseau coupé…).
  final Set<String> failingReads = {};

  @override
  Future<RemoteChanges> changes(String? token) async {
    calls.add('changes');
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

  int count(String prefix) => calls.where((c) => c.startsWith(prefix)).length;
}
