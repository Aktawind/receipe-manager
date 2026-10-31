import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recettes/data/sync/drive_auth.dart';
import 'package:recettes/data/sync/drive_remote.dart';

class _FakeAuth implements DriveAuth {
  bool signedIn = true;

  @override
  Future<Map<String, String>?> headers() async =>
      signedIn ? {'Authorization': 'Bearer jeton'} : null;

  @override
  Future<String> signIn() async => 'moi@example.org';

  @override
  Future<void> signOut() async {}
}

class _MemoryCache implements DriveCache {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late _MemoryCache cache;
  late List<http.Request> requests;

  // Les identifiants des dossiers sont déjà connus de l'appareil.
  const folders = {
    '': 'root-id',
    'recipes': 'f-recipes',
    'labels': 'f-labels',
    'equipment': 'f-equipment',
    'media': 'f-media',
    'history': 'f-history',
  };

  DriveRemote remote(
    http.Response Function(http.Request request) handler, {
    _FakeAuth? auth,
  }) {
    requests = [];
    return DriveRemote(
      auth: auth ?? _FakeAuth(),
      folderName: 'Recettes',
      cache: cache,
      client: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  setUp(() {
    cache = _MemoryCache()..values['drive_folders'] = jsonEncode(folders);
  });

  test('première synchro : tout le dossier, le jeton est pris avant', () async {
    final drive = remote((request) {
      if (request.url.path.endsWith('/changes/startPageToken')) {
        return _json({'startPageToken': '42'});
      }
      final q = request.url.queryParameters['q']!;
      if (q.contains("'f-recipes' in parents")) {
        return _json({
          'files': [
            {'id': 'r1', 'name': 'abc.json', 'version': '3'},
          ],
        });
      }
      if (q.contains("'f-media' in parents")) {
        return _json({
          'files': [
            {'id': 'm1', 'name': 'p1.jpg', 'version': '1'},
          ],
        });
      }
      return _json({'files': <Object>[]});
    });

    final result = await drive.changes(null);
    expect(result.token, '42');
    expect(
      {for (final c in result.items) c.path: c.version},
      {'recipes/abc.json': '3', 'media/p1.jpg': '1'},
    );
    expect(
      requests.first.url.path,
      endsWith('/changes/startPageToken'),
      reason: 'le jeton est demandé avant de lister',
    );
    expect(
      requests.every((r) => r.headers['Authorization'] == 'Bearer jeton'),
      isTrue,
    );
  });

  test(
    'changements : chemin d’après le dossier parent, corbeille = supprimé',
    () async {
      final drive = remote((request) {
        expect(request.url.path, endsWith('/changes'));
        expect(request.url.queryParameters['pageToken'], '42');
        return _json({
          'newStartPageToken': '45',
          'changes': [
            {
              'fileId': 'r1',
              'removed': false,
              'file': {
                'id': 'r1',
                'name': 'abc.json',
                'parents': ['f-recipes'],
                'trashed': false,
                'version': '4',
              },
            },
            {
              'fileId': 'l1',
              'removed': false,
              'file': {
                'id': 'l1',
                'name': 'xyz.json',
                'parents': ['f-labels'],
                'trashed': true,
                'version': '2',
              },
            },
            {
              // Un fichier hors de nos dossiers est ignoré.
              'fileId': 'x',
              'removed': false,
              'file': {
                'id': 'x',
                'name': 'autre.json',
                'parents': ['ailleurs'],
                'version': '1',
              },
            },
          ],
        });
      });

      final result = await drive.changes('42');
      expect(result.token, '45');
      final byPath = {for (final c in result.items) c.path: c};
      expect(byPath.keys, {'recipes/abc.json', 'labels/xyz.json'});
      expect(byPath['recipes/abc.json']!.version, '4');
      expect(byPath['recipes/abc.json']!.deleted, isFalse);
      expect(byPath['labels/xyz.json']!.deleted, isTrue);
    },
  );

  test('sans connexion valable, rien n’est envoyé à Google', () async {
    final auth = _FakeAuth()..signedIn = false;
    final drive = remote((request) => _json({}), auth: auth);
    await expectLater(drive.changes('42'), throwsA(isA<DriveSignInRequired>()));
    expect(requests, isEmpty);
  });

  test(
    'les dossiers sont créés une fois, puis leurs identifiants gardés',
    () async {
      cache.values.clear();
      var created = 0;
      final drive = remote((request) {
        if (request.method == 'POST') {
          created++;
          return _json({'id': 'dossier-$created'});
        }
        return _json({'files': <Object>[]});
      });
      await drive.changes('1');
      expect(
        created,
        6,
        reason: 'le dossier principal et ses cinq sous-dossiers',
      );
      final stored = jsonDecode(cache.values['drive_folders']!) as Map;
      expect(stored.keys, containsAll(['', 'recipes', 'media', 'history']));
    },
  );
}
