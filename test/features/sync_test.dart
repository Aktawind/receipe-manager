import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:recettes/data/sync/drive_auth.dart';
import 'package:recettes/data/sync/sync_remote.dart';
import 'package:recettes/features/sync/sync_providers.dart';

import '../helpers/memory_remote.dart';
import '../helpers/test_app.dart';

class _FakeAuth implements DriveAuth {
  @override
  Future<String> signIn() async => 'moi@example.org';

  @override
  Future<Map<String, String>?> headers() async => {};

  @override
  Future<void> signOut() async {}
}

class _RefusedAuth extends _FakeAuth {
  @override
  Future<String> signIn() async => throw const GoogleSignInException(
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
              (auth, folder, cache) => remote as SyncRemote,
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

      expect(find.text('Connecté : moi@example.org'), findsOneWidget);
      expect(
        remote.files.keys.where((k) => k.startsWith('recipes/')),
        hasLength(1),
        reason: 'la première synchro envoie les recettes',
      );
      expect(find.textContaining('À jour'), findsOneWidget);

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
}
