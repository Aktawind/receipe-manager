import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'drive_auth.dart';
import 'sync_remote.dart';

/// Le dossier de synchro dans Google Drive.
///
/// ```
/// <dossier>/            « Recettes » (ou « Recettes (test) »)
///   recipes/ labels/ equipment/ media/ history/
/// ```
/// Avec le droit `drive.file`, l'application ne voit que ce qu'elle a créé :
/// les fichiers du dossier, et rien d'autre dans le Drive.
class DriveRemote implements SyncRemote {
  DriveRemote({
    required DriveAuth auth,
    required this.folderName,
    required this.cache,
    http.Client? client,
  }) : _api = drive.DriveApi(_AuthClient(auth, client ?? http.Client()));

  final drive.DriveApi _api;
  final String folderName;

  /// Petit stockage propre à l'appareil (identifiants des dossiers Drive).
  final DriveCache cache;

  static const subfolders = [
    'recipes',
    'labels',
    'equipment',
    'media',
    'history',
  ];
  static const _folderMime = 'application/vnd.google-apps.folder';
  static const _foldersKey = 'drive_folders';

  /// Nom du sous-dossier → identifiant Drive (le dossier principal est `''`).
  Map<String, String>? _folders;

  /// Chemin → identifiant Drive, rempli à la demande (liste d'un dossier).
  final Map<String, String> _ids = {};
  final Set<String> _listed = {};

  // ------------------------------------------------------------------- dossiers

  Future<Map<String, String>> _ensureFolders() async {
    final known = _folders;
    if (known != null) return known;
    final stored = await cache.read(_foldersKey);
    if (stored != null && stored.isNotEmpty) {
      final decoded = (jsonDecode(stored) as Map).cast<String, String>();
      if (decoded.containsKey('') &&
          subfolders.every((name) => decoded.containsKey(name))) {
        return _folders = decoded;
      }
    }
    final root = await _findOrCreateFolder(folderName, 'root');
    final folders = <String, String>{'': root};
    for (final name in subfolders) {
      folders[name] = await _findOrCreateFolder(name, root);
    }
    await cache.write(_foldersKey, jsonEncode(folders));
    return _folders = folders;
  }

  Future<String> _findOrCreateFolder(String name, String parent) async {
    final found = await _api.files.list(
      q:
          "name = '${_escape(name)}' and mimeType = '$_folderMime' "
          "and '$parent' in parents and trashed = false",
      spaces: 'drive',
      $fields: 'files(id)',
      pageSize: 1,
    );
    final existing = found.files;
    if (existing != null && existing.isNotEmpty) return existing.first.id!;
    final created = await _api.files.create(
      drive.File(name: name, mimeType: _folderMime, parents: [parent]),
      $fields: 'id',
    );
    return created.id!;
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  /// Oublie les identifiants gardés (dossier supprimé ou déplacé dans Drive).
  Future<void> _forgetFolders() async {
    _folders = null;
    _ids.clear();
    _listed.clear();
    await cache.write(_foldersKey, '');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on drive.DetailedApiRequestError catch (error) {
      if (error.status == 404) await _forgetFolders();
      rethrow;
    }
  }

  // ------------------------------------------------------------------- lecture

  /// Les fichiers d'un sous-dossier, avec leur version.
  Future<List<drive.File>> _list(String folder) async {
    final folders = await _ensureFolders();
    final result = <drive.File>[];
    String? pageToken;
    do {
      final page = await _api.files.list(
        q: "'${folders[folder]}' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'nextPageToken, files(id, name, version)',
        pageSize: 1000,
        pageToken: pageToken,
      );
      result.addAll(page.files ?? const []);
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    for (final file in result) {
      _ids['$folder/${file.name}'] = file.id!;
    }
    _listed.add(folder);
    return result;
  }

  @override
  Future<RemoteChanges> changes(String? token) => _guard(() async {
    final folders = await _ensureFolders();
    if (token == null) {
      // Première synchro : tout le dossier. Le jeton est pris avant, pour ne
      // rien manquer de ce qui change pendant la lecture.
      final start = (await _api.changes.getStartPageToken()).startPageToken!;
      final items = <RemoteChange>[];
      for (final folder in subfolders) {
        for (final file in await _list(folder)) {
          items.add(
            RemoteChange('$folder/${file.name}', version: '${file.version}'),
          );
        }
      }
      return RemoteChanges(items, start);
    }

    final byFolder = {for (final e in folders.entries) e.value: e.key};
    final latest = <String, RemoteChange>{};
    String? pageToken = token;
    String next = token;
    while (pageToken != null) {
      final page = await _api.changes.list(
        pageToken,
        spaces: 'drive',
        includeRemoved: true,
        pageSize: 1000,
        $fields:
            'nextPageToken, newStartPageToken, '
            'changes(fileId, removed, file(id, name, parents, trashed, version))',
      );
      for (final change in page.changes ?? const <drive.Change>[]) {
        final file = change.file;
        if (file == null) {
          // Supprimé pour de bon : on ne retrouve son chemin que si on l'a vu.
          final path = _ids.entries
              .where((e) => e.value == change.fileId)
              .map((e) => e.key)
              .firstOrNull;
          if (path != null) {
            latest[path] = RemoteChange(path, deleted: true);
            _ids.remove(path);
          }
          continue;
        }
        final parent = (file.parents ?? const <String>[])
            .map((p) => byFolder[p])
            .nonNulls
            .firstOrNull;
        if (parent == null || parent.isEmpty || file.name == null) continue;
        final path = '$parent/${file.name}';
        if (change.removed == true || file.trashed == true) {
          latest[path] = RemoteChange(path, deleted: true);
          _ids.remove(path);
        } else {
          latest[path] = RemoteChange(path, version: '${file.version}');
          _ids[path] = file.id!;
        }
      }
      pageToken = page.nextPageToken;
      next = page.newStartPageToken ?? pageToken ?? next;
    }
    return RemoteChanges(latest.values.toList(), next);
  });

  @override
  Future<Uint8List> read(String path) => _guard(() async {
    final id = await _idOf(path);
    if (id == null) throw StateError('Fichier absent de Drive : $path');
    final media = await _api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final builder = BytesBuilder(copy: false);
    await for (final chunk in media.stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  });

  // ------------------------------------------------------------------- écriture

  @override
  Future<String> write(String path, Uint8List bytes) => _guard(() async {
    final (folder, name) = _split(path);
    final folders = await _ensureFolders();
    final id = await _idOf(path);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: folder == 'media' ? _imageType(name) : 'application/json',
    );
    final drive.File saved;
    if (id == null) {
      saved = await _api.files.create(
        drive.File(name: name, parents: [folders[folder]!]),
        uploadMedia: media,
        $fields: 'id, version',
      );
      _ids[path] = saved.id!;
    } else {
      saved = await _api.files.update(
        drive.File(),
        id,
        uploadMedia: media,
        $fields: 'id, version',
      );
    }
    return '${saved.version}';
  });

  /// Met à la corbeille de Drive (récupérable) plutôt que de supprimer.
  @override
  Future<void> delete(String path) => _guard(() async {
    final id = await _idOf(path);
    if (id == null) return;
    await _api.files.update(drive.File(trashed: true), id, $fields: 'id');
    _ids.remove(path);
  });

  Future<String?> _idOf(String path) async {
    final known = _ids[path];
    if (known != null) return known;
    final (folder, _) = _split(path);
    if (_listed.contains(folder)) return null;
    await _list(folder);
    return _ids[path];
  }

  static (String, String) _split(String path) {
    final slash = path.indexOf('/');
    return (path.substring(0, slash), path.substring(slash + 1));
  }

  static String _imageType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

/// Stockage clé/valeur de l'appareil pour [DriveRemote].
abstract class DriveCache {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Ajoute l'autorisation Google (renouvelée au besoin) à chaque requête.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._auth, this._inner);

  final DriveAuth _auth;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _auth.headers();
    if (headers == null) throw const DriveSignInRequired();
    request.headers.addAll(headers);
    return _inner.send(request);
  }
}

/// La connexion Google n'est plus valable : il faut se reconnecter.
class DriveSignInRequired implements Exception {
  const DriveSignInRequired();

  @override
  String toString() => 'DriveSignInRequired';
}
