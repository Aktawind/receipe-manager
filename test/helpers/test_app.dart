import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/app.dart';
import 'package:recettes/core/settings/theme_mode_controller.dart';
import 'package:recettes/data/app_services.dart';
import 'package:recettes/data/sync/background_sync.dart';
import 'package:recettes/features/sync/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une app complète sur une base en mémoire, pour les tests de widgets.
class TestApp {
  TestApp._(
    this.prefs,
    this.services,
    this.root,
    this.overrides,
    this.initialLocation,
  );

  /// Le premier écran : la liste des recettes, sauf pour les tests de
  /// l'accueil.
  final String initialLocation;

  final SharedPreferences prefs;
  final AppServices services;
  final Directory root;

  /// Remplacements de fournisseurs propres à un test (connexion Google…).
  final List<Override> overrides;

  static Future<TestApp> create({
    Map<String, Object> prefs = const {},
    List<Override> overrides = const [],
    String initialLocation = '/recettes',
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues(prefs);
    final preferences = await SharedPreferences.getInstance();
    final root = Directory.systemTemp.createTempSync('recettes_test');
    final services = await AppServices.open(
      root: root,
      cache: root,
      prefs: preferences,
      appVersion: '0.0.0-test',
      executor: DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    // The in-memory database is dropped with the test; closing it from the
    // fake-async teardown zone would hang.
    addTearDown(() => root.deleteSync(recursive: true));
    return TestApp._(preferences, services, root, overrides, initialLocation);
  }

  Widget get widget => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appServicesProvider.overrideWithValue(services),
      backgroundSchedulerProvider.overrideWithValue(
        const NoBackgroundScheduler(),
      ),
      ...overrides,
    ],
    child: RecettesApp(initialLocation: initialLocation),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }
}

void usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Laisse la base en mémoire terminer ses écritures, puis attend la fin des
/// animations. `pumpAndSettle` seul rend la main avant la fin des requêtes.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Touche le bouton retour de la barre d'application.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await settle(tester);
}

/// Fait défiler l'écran jusqu'à [finder] (les listes ne construisent que ce
/// qui est visible).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(Scrollable).first,
    const Offset(0, -250),
  );
  await tester.pump();
}
