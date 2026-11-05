import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
class DriveRemote implements DriveFolder {
  DriveRemote({
    required DriveAuth auth,
    required this.folderName,
    required this.cache,
    http.Client? client,
  }) : _auth = _AuthClient(auth, client ?? http.Client()) {
    _api = drive.DriveApi(_auth);
  }

  final _AuthClient _auth;
  late final drive.DriveApi _api;
  final String folderName;

  /// Petit stockage propre à l'appareil (identifiants des dossiers Drive).
  final DriveCache cache;

  static const subfolders = [
    'recipes',
    'labels',
    'equipment',
    'media',
    'history',
    'backups',
  ];
  static const _folderMime = 'application/vnd.google-apps.folder';
  static const _foldersKey = 'drive_folders';

  /// Nom du sous-dossier → identifiant Drive (le dossier principal est `''`).
  Map<String, String>? _folders;

  /// Chemin → identifiant Drive, rempli à la demande (liste d'un dossier).
  final Map<String, String> _ids = {};
  final Set<String> _listed = {};
  final Map<String, Future<List<drive.File>>> _listings = {};

  // ------------------------------------------------------------------- dossiers

  /// Plusieurs requêtes peuvent le demander en même temps : une seule travaille.
  Future<Map<String, String>>? _foldersLoading;

  Future<Map<String, String>> _ensureFolders() async {
    final known = _folders;
    if (known != null) return known;
    try {
      return await (_foldersLoading ??= _loadFolders());
    } finally {
      _foldersLoading = null;
    }
  }

  Future<Map<String, String>> _loadFolders() async {
    final stored = await cache.read(_foldersKey);
    if (stored != null && stored.isNotEmpty) {
      final decoded = (jsonDecode(stored) as Map).cast<String, String>();
      if (decoded.containsKey('') && subfolders.every(decoded.containsKey)) {
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
    _listings.clear();
    _auth.invalidate();
    await cache.write(_foldersKey, '');
  }

  /// Rejoue une requête que Drive refuse pour une raison passagère : jeton
  /// expiré (on en redemande un), trop de requêtes ou panne momentanée.
  Future<T> _guard<T>(Future<T> Function() action) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await action();
      } on Object catch (error) {
        // Réseau coupé, délai dépassé : on réessaie quelques fois.
        if (error is TimeoutException ||
            error is SocketException ||
            error is http.ClientException) {
          if (attempt >= 3) rethrow;
          await Future<void>.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        if (error is! drive.DetailedApiRequestError) rethrow;
        final status = error.status ?? 0;
        if (status == 404) await _forgetFolders();
        final transient =
            status == 429 ||
            status == 403 && _isRateLimit(error) ||
            status >= 500;
        if (status == 401 && attempt == 1) {
          _auth.invalidate();
        } else if (!transient || attempt >= 4) {
          rethrow;
        } else {
          await Future<void>.delayed(
            Duration(milliseconds: 500 * attempt * attempt),
          );
        }
      }
    }
  }

  static bool _isRateLimit(drive.DetailedApiRequestError error) => error.errors
      .any((e) => (e.reason ?? '').toLowerCase().contains('ratelimit'));

  // ------------------------------------------------------------------- lecture

  /// Les fichiers d'un sous-dossier, avec leur version (un seul listage à la
  /// fois par dossier, même si plusieurs envois le demandent ensemble).
  Future<List<drive.File>> _list(String folder) =>
      _listings[folder] ??= _listFolder(folder).whenComplete(() {
        // Un bloc : une flèche renverrait ce même Future, qui s'attendrait lui-même.
        _listings.remove(folder);
      });

  Future<List<drive.File>> _listFolder(String folder) async {
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
      final drive.ChangeList page;
      try {
        page = await _api.changes.list(
          pageToken,
          spaces: 'drive',
          includeRemoved: true,
          pageSize: 1000,
          $fields:
              'nextPageToken, newStartPageToken, '
              'changes(fileId, removed, file(id, name, parents, trashed, version))',
        );
      } on drive.DetailedApiRequestError catch (error) {
        // Jeton refusé (trop ancien) : à l'appelant de relire tout le dossier.
        if (error.status == 400 || error.status == 410) {
          throw const ChangesTokenExpired();
        }
        rethrow;
      }
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

  /// Met le dossier à la corbeille de Drive : récupérable depuis Drive.
  @override
  Future<void> deleteAll() => _guard(() async {
    final folders = await _ensureFolders();
    await _api.files.update(
      drive.File(trashed: true),
      folders['']!,
      $fields: 'id',
    );
    await _forgetFolders();
  });

  // ---------------------------------------------------------------- sauvegardes

  @override
  Future<List<RemoteBackup>> listBackups() => _guard(() async {
    final folders = await _ensureFolders();
    final result = <RemoteBackup>[];
    String? pageToken;
    do {
      final page = await _api.files.list(
        q: "'${folders['backups']}' in parents and trashed = false",
        spaces: 'drive',
        $fields: 'nextPageToken, files(id, name, createdTime, size)',
        pageSize: 200,
        pageToken: pageToken,
      );
      for (final file in page.files ?? const <drive.File>[]) {
        result.add(
          RemoteBackup(
            id: file.id!,
            name: file.name ?? '',
            createdAt:
                file.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0),
            size: int.tryParse(file.size ?? '') ?? 0,
          ),
        );
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  });

  @override
  Future<void> uploadBackup(String name, Uint8List bytes) => _guard(() async {
    final folders = await _ensureFolders();
    await _api.files.create(
      drive.File(name: name, parents: [folders['backups']!]),
      uploadMedia: drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/json',
      ),
      $fields: 'id',
    );
  });

  @override
  Future<Uint8List> downloadBackup(String id) => _guard(() async {
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

  @override
  Future<void> deleteBackup(String id) => _guard(() async {
    await _api.files.update(drive.File(trashed: true), id, $fields: 'id');
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

/// Ajoute l'autorisation Google à chaque requête. Le jeton est gardé en
/// mémoire : le redemander à Android pour chaque fichier ralentirait tout.
class _AuthClient extends http.BaseClient {
  _AuthClient(this._auth, this._inner);

  final DriveAuth _auth;
  final http.Client _inner;
  static const _lifetime = Duration(minutes: 30);

  Future<Map<String, String>?>? _headers;
  DateTime? _since;

  void invalidate() {
    _headers = null;
    _since = null;
  }

  Future<Map<String, String>?> _current() {
    final since = _since;
    if (_headers == null ||
        since == null ||
        DateTime.now().difference(since) > _lifetime) {
      _since = DateTime.now();
      _headers = _auth.headers();
    }
    return _headers!;
  }

  /// Sans limite de temps, une connexion qui se fige (réseau perdu en plein
  /// transfert) bloquerait la synchro pour toujours.
  static const _requestTimeout = Duration(seconds: 90);
  static const _chunkTimeout = Duration(seconds: 60);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final Map<String, String>? headers;
    try {
      headers = await _current().timeout(_requestTimeout);
    } on Object {
      invalidate();
      rethrow;
    }
    if (headers == null) {
      invalidate();
      throw const DriveSignInRequired();
    }
    request.headers.addAll(headers);
    final response = await _inner.send(request).timeout(_requestTimeout);
    return http.StreamedResponse(
      response.stream.timeout(_chunkTimeout),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

/// La connexion Google n'est plus valable : il faut se reconnecter.
class DriveSignInRequired implements Exception {
  const DriveSignInRequired();

  @override
  String toString() => 'DriveSignInRequired';
}
