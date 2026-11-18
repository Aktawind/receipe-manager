import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/logging/error_log.dart';
import 'package:recettes/core/platform/export_actions.dart';

import '../helpers/test_app.dart';

class _FakeExport implements ExportActions {
  String? text;

  @override
  Future<void> shareText(String text, {String subject = ''}) async =>
      this.text = text;

  @override
  Future<void> printPdf(Uint8List pdf, {required String name}) async {}

  @override
  Future<void> sharePdf(Uint8List pdf, {required String name}) async {}
}

Future<void> _openSetting(WidgetTester tester, String key) async {
  await openSettings(tester);
  await scrollTo(tester, find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

void main() {
  testWidgets('le journal des erreurs : lire, envoyer', (tester) async {
    usePhoneSize(tester);
    ErrorLog.current = ErrorLog.memory()..add('Synchro', 'Drive injoignable');
    addTearDown(() => ErrorLog.current = ErrorLog.memory());
    final export = _FakeExport();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [exportActionsProvider.overrideWithValue(export)],
      ),
    ))!;
    await app.pump(tester);
    await _openSetting(tester, 'settings-error-log');
    expect(find.text('Drive injoignable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('error-log-share')));
    await settle(tester);
    expect(export.text, contains('Synchro\nDrive injoignable'));
  });

  testWidgets('supprimer toutes mes données : double confirmation', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(prefs: {'theme_mode': 'dark'}),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final r = await repo.create();
      await repo.save(r.copyWith(title: 'Quiche'));
      await app.services.shopping.createList('Semaine');
      final photos = app.services.photos.directory;
      await photos.create(recursive: true);
      await File('${photos.path}/a.jpg').writeAsBytes([1, 2, 3]);
    });
    await app.pump(tester);
    await _openSetting(tester, 'settings-privacy');
    expect(find.text('Sur cet appareil'), findsOneWidget);

    await scrollTo(tester, find.byKey(const ValueKey('privacy-delete-all')));
    await tester.tap(find.byKey(const ValueKey('privacy-delete-all')));
    await settle(tester);
    // Sans synchro : pas de case pour Drive.
    expect(find.byKey(const ValueKey('delete-all-drive')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('delete-all-next')));
    await settle(tester);
    expect(find.text('Dernière confirmation'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-all-confirm')));
    // La suppression touche la base et des fichiers : on lui laisse le temps.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await settle(tester);
    }

    expect(find.text('Toutes tes données ont été supprimées.'), findsOneWidget);
    final left = await tester.runAsync(() async {
      final s = app.services;
      return (
        recipes: (await s.recipes.getAllWithDetails()).length,
        lists: (await s.shopping.getAllLists()).length,
        labels: (await s.labels.getAll()).length,
        slots: (await s.planning.getAllSlots()).length,
      );
    });
    expect(left!.recipes, 0);
    expect(left.lists, 0);
    // Comme à la première ouverture : classement et créneaux fournis.
    expect(left.labels, greaterThan(0));
    expect(left.slots, 4);
    expect(app.services.photos.directory.existsSync(), isFalse);
    expect(app.prefs.getString('theme_mode'), isNull);
  });
}
