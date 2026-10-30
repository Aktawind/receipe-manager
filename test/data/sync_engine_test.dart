import 'dart:typed_data';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/equipment_repository.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/photo_store.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/data/sync/hybrid_clock.dart';
import 'package:recettes/data/sync/sync_codec.dart';
import 'package:recettes/data/sync/sync_engine.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/memory_remote.dart';

/// Un appareil : sa base, ses photos, son horloge (réglable) et son moteur.
class Device {
  Device._(
    this.db,
    this.recipes,
    this.labels,
    this.equipment,
    this.photos,
    this.clock,
    this.engine,
    this._time,
  );

  final AppDatabase db;
  final RecipeRepository recipes;
  final LabelRepository labels;
  final EquipmentRepository equipment;
  final PhotoStore photos;
  final HybridClock clock;
  final SyncEngine engine;
  final _Time _time;

  static Future<Device> create(
    MemoryRemote remote,
    DateTime start, {
    Directory? photoDir,
  }) async {
    final time = _Time(start);
    final db = AppDatabase(NativeDatabase.memory());
    final clock = await SyncEngine.loadClock(db, source: () => time.value);
    final recipes = RecipeRepository(db, clock: clock.now);
    final labels = LabelRepository(db, clock: clock.now);
    final equipment = EquipmentRepository(db, clock: clock.now);
    final photos = PhotoStore(
      photoDir ?? Directory.systemTemp.createTempSync('recettes-sync'),
    );
    final engine = SyncEngine(
      database: db,
      recipes: recipes,
      labels: labels,
      equipment: equipment,
      photos: photos,
      remote: remote,
      clock: clock,
      now: () => time.value,
    );
    return Device._(
      db,
      recipes,
      labels,
      equipment,
      photos,
      clock,
      engine,
      time,
    );
  }

  /// Avance l'horloge de cet appareil.
  void at(DateTime moment) => _time.value = moment;

  Future<Recipe> addRecipe(
    String title, {
    List<String> labelIds = const [],
  }) async {
    final created = await recipes.create();
    return recipes.save(created.copyWith(title: title, labelIds: labelIds));
  }

  Future<Recipe> edit(String id, String title) async {
    final recipe = (await recipes.getRecipe(id))!;
    return recipes.save(recipe.copyWith(title: title));
  }

  Future<String?> titleOf(String id) async =>
      (await recipes.getRecipe(id))?.title;

  Future<void> close() async {
    await db.close();
    await photos.directory.delete(recursive: true);
  }
}

class _Time {
  _Time(this.value);
  DateTime value;
}

DateTime t(int minute) => DateTime.utc(2026, 11, 1, 10, minute);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late MemoryRemote remote;
  late Device a;
  late Device b;

  setUp(() async {
    remote = MemoryRemote();
    a = await Device.create(remote, t(0));
    b = await Device.create(remote, t(0));
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test(
    'recette, classement, matériel et photo arrivent sur l’autre appareil',
    () async {
      final noel = await a.labels.findOrCreate(LabelKind.collection, 'Noël');
      final moule = await a.equipment.findOrCreate('moule à cake');
      await a.photos.write('p1.jpg', [1, 2, 3]);
      final created = await a.addRecipe('Bûche', labelIds: [noel.id]);
      await a.recipes.save(
        created.copyWith(
          mainPhoto: () => 'p1.jpg',
          equipmentIds: [moule.id],
          notes: 'Au frais',
        ),
      );

      final first = await a.engine.sync();
      expect(first.ok, isTrue, reason: '${first.errors}');
      expect(remote.files.keys, contains('recipes/${created.id}.json'));
      expect(remote.files.keys, contains('media/p1.jpg'));
      expect(remote.files.keys, contains('labels/${noel.id}.json'));
      expect(remote.files.keys, contains('equipment/${moule.id}.json'));

      final second = await b.engine.sync();
      expect(second.ok, isTrue, reason: '${second.errors}');
      final copy = (await b.recipes.getRecipe(created.id))!;
      expect(copy.title, 'Bûche');
      expect(copy.notes, 'Au frais');
      expect(copy.labelIds, [noel.id]);
      expect(copy.equipmentIds, [moule.id]);
      expect(copy.mainPhoto, 'p1.jpg');
      expect(await b.photos.file('p1.jpg').readAsBytes(), [1, 2, 3]);
      expect(
        (await b.labels.getAll()).firstWhere((l) => l.id == noel.id).name,
        'Noël',
      );
      expect(second.conflicts, isEmpty);
    },
  );

  test(
    'les éléments par défaut créés des deux côtés ne font pas de conflit',
    () async {
      await a.engine.sync();
      final report = await b.engine.sync();
      expect(report.ok, isTrue);
      expect(report.conflicts, isEmpty);
      expect(report.uploaded, 0, reason: 'rien de nouveau à envoyer');
      // Les deux côtés ont maintenant les mêmes dates.
      final left = {for (final l in await a.labels.getAll()) l.id: l.updatedAt};
      final right = {
        for (final l in await b.labels.getAll()) l.id: l.updatedAt,
      };
      for (final id in left.keys) {
        expect(right[id]!.isAtSameMomentAs(left[id]!), isTrue);
      }
    },
  );

  test('sans changement, une synchro ne fait qu’une requête', () async {
    await a.addRecipe('Quiche');
    await a.engine.sync();
    await b.engine.sync();

    remote.calls.clear();
    final report = await b.engine.sync();
    expect(report.changedNothing, isTrue);
    expect(remote.calls, ['changes']);
    remote.calls.clear();
    await a.engine.sync();
    expect(remote.calls, [
      'changes',
    ], reason: 'ses propres envois sont ignorés');
  });

  test(
    'seul ce qui a changé circule, une photo n’est envoyée qu’une fois',
    () async {
      await a.photos.write('p1.jpg', [9]);
      final recipe = await a.addRecipe('Tarte');
      await a.recipes.save(recipe.copyWith(mainPhoto: () => 'p1.jpg'));
      await a.addRecipe('Flan');
      await a.engine.sync();
      await b.engine.sync();

      a.at(t(5));
      await a.edit(recipe.id, 'Tarte aux pommes');
      remote.calls.clear();
      await a.engine.sync();
      expect(remote.count('write'), 1);
      expect(remote.calls, contains('write recipes/${recipe.id}.json'));
      expect(remote.calls.where((c) => c.contains('media')), isEmpty);

      remote.calls.clear();
      await b.engine.sync();
      expect(remote.count('read'), 1);
      expect(await b.titleOf(recipe.id), 'Tarte aux pommes');
    },
  );

  test(
    'modifié des deux côtés : le plus récent gagne, l’autre est gardé',
    () async {
      final recipe = await a.addRecipe('Gratin');
      await a.engine.sync();
      await b.engine.sync();

      a.at(t(10));
      b.at(t(20));
      await a.edit(recipe.id, 'Gratin de A');
      await b.edit(recipe.id, 'Gratin de B');

      final fromA = await a.engine
          .sync(); // A envoie, B n'a pas encore rien dit
      expect(fromA.conflicts, isEmpty);
      final fromB = await b.engine.sync();
      expect(fromB.conflicts, hasLength(1));
      expect(fromB.conflicts.single.localWon, isTrue);
      expect(fromB.conflicts.single.title, 'Gratin de B');

      // La version écartée est dans l'historique distant.
      final history = remote.files.keys.where((k) => k.startsWith('history/'));
      expect(history, hasLength(1));
      expect(
        SyncCodec.decodeRecipe(remote.files[history.single]!).title,
        'Gratin de A',
      );

      final back = await a.engine.sync();
      expect(back.ok, isTrue);
      expect(await a.titleOf(recipe.id), 'Gratin de B');
      expect(await b.titleOf(recipe.id), 'Gratin de B');
    },
  );

  test('conflit perdu ici : la version distante remplace la locale, qui est gardée', () async {
    final recipe = await a.addRecipe('Soupe');
    await a.engine.sync();
    await b.engine.sync();

    b.at(t(10));
    a.at(t(20));
    await b.edit(recipe.id, 'Soupe de B');
    await a.edit(recipe.id, 'Soupe de A');
    await a.engine.sync();

    final report = await b.engine.sync();
    expect(report.conflicts.single.localWon, isFalse);
    expect(await b.titleOf(recipe.id), 'Soupe de A');
    final history = remote.files.keys.singleWhere(
      (k) => k.startsWith('history/'),
    );
    expect(SyncCodec.decodeRecipe(remote.files[history]!).title, 'Soupe de B');
  });

  test(
    'la corbeille se synchronise, la suppression définitive aussi',
    () async {
      final recipe = await a.addRecipe('Crêpes');
      await a.engine.sync();
      await b.engine.sync();

      a.at(t(5));
      await a.recipes.moveToTrash(recipe.id);
      await a.engine.sync();
      await b.engine.sync();
      expect((await b.recipes.getRecipe(recipe.id))!.deletedAt, isNotNull);

      await a.recipes.deletePermanently([recipe.id]);
      final sent = await a.engine.sync();
      expect(sent.deletedRemote, 1);
      expect(remote.files.keys, isNot(contains('recipes/${recipe.id}.json')));
      final received = await b.engine.sync();
      expect(received.deletedLocal, 1);
      expect(await b.recipes.getRecipe(recipe.id), isNull);
    },
  );

  test(
    'une modification faite ailleurs l’emporte sur une suppression',
    () async {
      final recipe = await a.addRecipe('Cake');
      await a.engine.sync();
      await b.engine.sync();

      b.at(t(10));
      await b.edit(recipe.id, 'Cake aux olives');
      await a.recipes.deletePermanently([recipe.id]);
      await a.engine.sync();
      expect(remote.files.keys, isNot(contains('recipes/${recipe.id}.json')));

      final report = await b.engine.sync();
      expect(report.ok, isTrue);
      expect(await b.titleOf(recipe.id), 'Cake aux olives');
      expect(remote.files.keys, contains('recipes/${recipe.id}.json'));
      await a.engine.sync();
      expect(await a.titleOf(recipe.id), 'Cake aux olives');
    },
  );

  test('un fichier illisible : le reste est reçu, rien n’est envoyé, reprise ensuite', () async {
    final one = await a.addRecipe('Un');
    final two = await a.addRecipe('Deux');
    await a.engine.sync();

    await b.addRecipe('Local à B');
    remote.failingReads.add('recipes/${one.id}.json');
    final failed = await b.engine.sync();
    expect(failed.ok, isFalse);
    expect(await b.titleOf(two.id), 'Deux');
    expect(await b.recipes.getRecipe(one.id), isNull);
    expect(
      remote.files.keys.where((k) => k.startsWith('recipes/')),
      hasLength(2),
      reason: 'rien n’a été envoyé tant que la réception est incomplète',
    );

    remote.failingReads.clear();
    final retry = await b.engine.sync();
    expect(retry.ok, isTrue, reason: '${retry.errors}');
    expect(await b.titleOf(one.id), 'Un');
    expect(
      remote.files.keys.where((k) => k.startsWith('recipes/')),
      hasLength(3),
    );
  });

  test(
    'l’horloge en retard n’annule pas une modification faite après réception',
    () async {
      final recipe = await a.addRecipe('Pizza');
      a.at(t(30));
      await a.edit(recipe.id, 'Pizza reine'); // 10:30 chez A
      await a.engine.sync();

      b.at(t(0)); // l'horloge de B retarde de 30 minutes
      await b.engine.sync();
      final edited = await b.edit(recipe.id, 'Pizza 4 fromages');
      expect(edited.updatedAt.isAfter(t(30)), isTrue);

      await b.engine.sync();
      await a.engine.sync();
      expect(await a.titleOf(recipe.id), 'Pizza 4 fromages');
    },
  );

  test(
    'le jeton et l’horloge sont conservés d’une ouverture à l’autre',
    () async {
      final recipe = await a.addRecipe('Riz');
      a.at(t(40));
      await a.edit(recipe.id, 'Riz cantonais');
      await a.engine.sync();
      await b.engine.sync();

      final reopened = await SyncEngine.loadClock(b.db);
      expect(reopened.lastSeen, isNotNull);
      expect(reopened.lastSeen!.isAtSameMomentAs(t(40)), isTrue);
      expect(await b.engine.lastSync(), isNotNull);
    },
  );

  test('un chemin distant inconnu est ignoré', () async {
    await remote.write('history/x.json', Uint8List(0));
    await remote.write('autre/chose', Uint8List(0));
    final report = await a.engine.sync();
    expect(report.ok, isTrue, reason: '${report.errors}');
    expect(SyncKind.parse('recipes/abc.json'), (SyncKind.recipe, 'abc'));
    expect(SyncKind.parse('media/p.jpg'), (SyncKind.media, 'p.jpg'));
    expect(SyncKind.parse('recipes/a/b.json'), isNull);
    expect(SyncKind.parse('recipes/abc.txt'), isNull);
  });
}
