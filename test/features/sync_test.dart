import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:recettes/data/sync/drive_auth.dart';
import 'package:recettes/features/sync/sync_providers.dart';

import '../helpers/memory_remote.dart';
import '../helpers/test_app.dart';

class _FakeAuth implements DriveAuth {
  @override
  Future<DriveAccount> signIn() async =>
      const DriveAccount(email: 'moi@example.org', name: 'Audrick');

  @override
  Future<Map<String, String>?> headers() async => {};

  @override
  Future<void> signOut() async {}
}

class _RefusedAuth extends _FakeAuth {
  @override
  Future<DriveAccount> signIn() async => throw const GoogleSignInException(
    code: GoogleSignInExceptionCode.canceled,
    description: 'Access blocked',
  );
}

void main() {
  testWidgets(
    'connexion refusée par Google : le message et le détail s’affichent',
    (tester) async {
      usePhoneSize(tester);
      final app = (await tester.runAsync(
        () => TestApp.create(
          overrides: [driveAuthProvider.overrideWithValue(_RefusedAuth())],
        ),
      ))!;
      await app.pump(tester);
      await tester.tap(find.text('Réglages').last);
      await settle(tester);
      await scrollTo(tester, find.text('Synchronisation Google Drive'));
      await tester.tap(find.text('Synchronisation Google Drive'));
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('sync-connect')));
      await settle(tester);
      expect(
        find.textContaining('La connexion n’a pas abouti'),
        findsOneWidget,
      );
      expect(find.textContaining('canceled Access blocked'), findsOneWidget);
      expect(app.prefs.getBool('sync_enabled'), isNull);
    },
  );

  testWidgets(
    'Réglages → Synchronisation : explication, connexion, déconnexion',
    (tester) async {
      usePhoneSize(tester);
      final remote = MemoryRemote();
      final app = (await tester.runAsync(
        () => TestApp.create(
          overrides: [
            driveAuthProvider.overrideWithValue(_FakeAuth()),
            syncRemoteFactoryProvider.overrideWithValue(
              (auth, folder, cache) => remote,
            ),
          ],
        ),
      ))!;
      await tester.runAsync(() async {
        final recipe = await app.services.recipes.create();
        await app.services.recipes.save(recipe.copyWith(title: 'Quiche'));
      });
      await app.pump(tester);

      await tester.tap(find.text('Réglages').last);
      await settle(tester);
      await scrollTo(tester, find.text('Synchronisation Google Drive'));
      await tester.tap(find.text('Synchronisation Google Drive'));
      await settle(tester);

      // Avant la connexion : ce qui sera fait, et rien d'autre.
      expect(find.text('Garde tes recettes à jour partout'), findsOneWidget);
      expect(find.textContaining('dossier « Recettes »'), findsOneWidget);
      expect(
        find.textContaining('jamais au reste de ton Drive'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('sync-connect')));
      await settle(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);

      expect(find.text('Audrick'), findsOneWidget);
      expect(find.text('A'), findsOneWidget, reason: 'initiale du compte');
      expect(
        remote.files.keys.where((k) => k.startsWith('recipes/')),
        hasLength(1),
        reason: 'la première synchro envoie les recettes',
      );
      expect(find.textContaining('À jour'), findsOneWidget);

      // « Synchroniser maintenant » relance vraiment une synchro.
      remote.calls.clear();
      await tester.tap(find.byKey(const ValueKey('sync-now')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
      expect(remote.calls, contains('changes'));

      // La première synchro réussie déclenche la sauvegarde automatique (due).
      expect(remote.backupFiles, hasLength(1));
      await scrollTo(tester, find.byKey(const ValueKey('backup-now')));
      await tester.tap(find.byKey(const ValueKey('backup-now')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
      expect(remote.backupFiles, hasLength(2));
      expect(find.text('Sauvegarde faite.'), findsOneWidget);

      // Restaurer : liste, confirmation, résultat (la barre d'info disparaît).
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      await scrollTo(tester, find.byKey(const ValueKey('backup-restore')));
      await tester.tap(find.byKey(const ValueKey('backup-restore')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
      expect(find.text('Choisis la sauvegarde à restaurer'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.history).first);
      await settle(tester);
      expect(find.text('Restaurer cette sauvegarde ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restaurer'));
      // Les écritures en base avancent avec les images : on alterne.
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      expect(find.text('1 recette restaurée.'), findsOneWidget);

      await scrollTo(tester, find.byKey(const ValueKey('sync-disconnect')));
      await tester.tap(find.byKey(const ValueKey('sync-disconnect')));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
      expect(find.text('Garde tes recettes à jour partout'), findsOneWidget);
      expect(app.prefs.getBool('sync_enabled'), isFalse);
      // Rien n'est supprimé, ni ici ni dans le dossier distant.
      expect(
        remote.files.keys.where((k) => k.startsWith('recipes/')),
        hasLength(1),
      );
      // Laisse partir les minuteurs de la synchro.
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets(
    'supprimer mes données dans Drive : dossier à la corbeille, déconnexion',
    (tester) async {
      usePhoneSize(tester);
      final remote = MemoryRemote();
      final app = (await tester.runAsync(
        () => TestApp.create(
          overrides: [
            driveAuthProvider.overrideWithValue(_FakeAuth()),
            syncRemoteFactoryProvider.overrideWithValue(
              (auth, folder, cache) => remote,
            ),
          ],
        ),
      ))!;
      await tester.runAsync(() async {
        final recipe = await app.services.recipes.create();
        await app.services.recipes.save(recipe.copyWith(title: 'Quiche'));
      });
      await app.pump(tester);
      await tester.tap(find.text('Réglages').last);
      await settle(tester);
      await scrollTo(tester, find.text('Synchronisation Google Drive'));
      await tester.tap(find.text('Synchronisation Google Drive'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('sync-connect')));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
      expect(remote.files, isNotEmpty);

      await scrollTo(tester, find.byKey(const ValueKey('drive-delete')));
      await tester.tap(find.byKey(const ValueKey('drive-delete')));
      await settle(tester);
      expect(find.text('Supprimer les données dans Drive ?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);

      expect(remote.calls, contains('deleteAll'));
      expect(remote.files, isEmpty);
      expect(find.text('Garde tes recettes à jour partout'), findsOneWidget);
      expect(app.prefs.getBool('sync_enabled'), isFalse);
      // Les recettes de l'appareil, elles, sont toujours là.
      final left = await tester.runAsync(
        () => app.services.recipes.getAllWithDetails(),
      );
      expect(left!.map((r) => r.title), ['Quiche']);
      await tester.pump(const Duration(seconds: 10));
    },
  );

  testWidgets('se reconnecter au même compte reprend où on en était', (
    tester,
  ) async {
    usePhoneSize(tester);
    final remote = MemoryRemote();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [
          driveAuthProvider.overrideWithValue(_FakeAuth()),
          syncRemoteFactoryProvider.overrideWithValue(
            (auth, folder, cache) => remote,
          ),
        ],
      ),
    ))!;
    await tester.runAsync(() async {
      for (final title in ['Quiche', 'Tarte', 'Flan']) {
        final recipe = await app.services.recipes.create();
        await app.services.recipes.save(recipe.copyWith(title: title));
      }
    });
    await app.pump(tester);
    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.text('Synchronisation Google Drive'));
    await tester.tap(find.text('Synchronisation Google Drive'));
    await settle(tester);

    Future<void> wait() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await settle(tester);
    }

    await tester.tap(find.byKey(const ValueKey('sync-connect')));
    await wait();
    expect(
      remote.files.keys.where((k) => k.startsWith('recipes/')),
      hasLength(3),
    );

    // Déconnexion, puis reconnexion au même compte.
    await scrollTo(tester, find.byKey(const ValueKey('sync-disconnect')));
    await tester.tap(find.byKey(const ValueKey('sync-disconnect')));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter'));
    await wait();
    remote.calls.clear();
    await tester.tap(find.byKey(const ValueKey('sync-connect')));
    await wait();

    expect(remote.calls, contains('changes'));
    expect(remote.count('read'), 0, reason: 'rien n’est relu');
    expect(remote.count('write'), 0, reason: 'rien n’est renvoyé');
    await tester.pump(const Duration(seconds: 10));
  });
}
