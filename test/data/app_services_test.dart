import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/app_services.dart';
import 'package:recettes/data/database.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() => root = Directory.systemTemp.createTempSync('services_test'));
  tearDown(() => root.deleteSync(recursive: true));

  List<String> backups() {
    final dir = Directory('${root.path}/sauvegardes');
    if (!dir.existsSync()) return [];
    return dir.listSync().map((f) => f.uri.pathSegments.last).toList();
  }

  test('copie la base avant une migration de schéma', () async {
    File('${root.path}/recettes.sqlite').writeAsBytesSync([]);
    SharedPreferences.setMockInitialValues({'db_schema_version': 0});
    final prefs = await SharedPreferences.getInstance();

    final services = await AppServices.open(
      root: root,
      cache: root,
      prefs: prefs,
      appVersion: 'test',
    );
    await services.database.close();

    expect(backups().single, startsWith('avant-migration-v0-'));
    expect(prefs.getInt('db_schema_version'), AppDatabase.latestSchemaVersion);
  });

  test('pas de copie au premier lancement ni sans changement', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    var services = await AppServices.open(
      root: root,
      cache: root,
      prefs: prefs,
      appVersion: 'test',
    );
    await services.recipes.create();
    await services.database.close();

    services = await AppServices.open(
      root: root,
      cache: root,
      prefs: prefs,
      appVersion: 'test',
    );
    expect(await services.recipes.getAllWithDetails(), hasLength(1));
    await services.database.close();
    expect(backups(), isEmpty);
  });
}
