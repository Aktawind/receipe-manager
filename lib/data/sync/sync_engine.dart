import 'package:drift/drift.dart';

import '../../domain/equipment.dart';
import '../../domain/label.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../domain/shopping.dart';
import '../database.dart';
import '../equipment_repository.dart';
import '../label_repository.dart';
import '../photo_store.dart';
import '../planning_repository.dart';
import '../recipe_repository.dart';
import '../shopping_repository.dart';
import 'hybrid_clock.dart';
import 'sync_codec.dart';
import 'sync_remote.dart';

/// Un élément modifié des deux côtés depuis la dernière synchro. La version
/// la plus récente a été gardée ; l'autre est dans [historyPath] (dossier
/// distant), jamais perdue.
class SyncConflict {
  const SyncConflict({
    required this.kind,
    required this.id,
    required this.title,
    required this.localWon,
    required this.historyPath,
  });

  final SyncKind kind;
  final String id;
  final String title;

  /// `true` : la version de cet appareil a été gardée.
  final bool localWon;
  final String historyPath;
}

/// Le résultat d'une synchro.
class SyncReport {
  int uploaded = 0;
  int downloaded = 0;
  int deletedRemote = 0;
  int deletedLocal = 0;
  final List<SyncConflict> conflicts = [];
  final List<String> errors = [];

  bool get ok => errors.isEmpty;
  bool get changedNothing =>
      uploaded == 0 &&
      downloaded == 0 &&
      deletedRemote == 0 &&
      deletedLocal == 0 &&
      conflicts.isEmpty;
}

/// Synchronise la base locale avec un dossier distant.
///
/// - **Réception** : seuls les fichiers modifiés depuis le dernier jeton sont
///   lus. Un élément propre à cet appareil (non modifié depuis la dernière
///   synchro) est simplement remplacé par la version distante.
/// - **Envoi** : un élément est « à envoyer » quand sa date de modification
///   diffère de celle notée à la dernière synchro. Les photos sont envoyées
///   une seule fois, avant la recette qui les utilise.
/// - **Conflit** : modifié des deux côtés, la modification la plus récente
///   l'emporte, élément par élément ; l'autre version va dans `history/`.
/// - **Suppression** : la corbeille se synchronise comme une modification. Une
///   suppression définitive supprime le fichier distant ; une modification
///   faite ailleurs depuis l'emporte sur la suppression.
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required RecipeRepository recipes,
    required LabelRepository labels,
    required EquipmentRepository equipment,
    required ShoppingRepository shopping,
    required PlanningRepository planning,
    required this._photos,
    required this._remote,
    required this._clock,
    DateTime Function()? now,
  }) : _db = database,
       _recipes = recipes,
       _now = now ?? DateTime.now {
    _adapters = [
      _Adapter.of<Label>(
        kind: SyncKind.label,
        stamps: () => _stamps(_db.labels, _db.labels.id, _db.labels.updatedAt),
        load: (id) async =>
            {for (final l in await labels.getAll()) l.id: l}[id],
        loadAll: () async => {for (final l in await labels.getAll()) l.id: l},
        idOf: (l) => l.id,
        updatedAt: (l) => l.updatedAt,
        encode: SyncCodec.label,
        decode: SyncCodec.decodeLabel,
        put: labels.put,
        titleOf: (l) => l.name,
      ),
      _Adapter.of<EquipmentItem>(
        kind: SyncKind.equipment,
        stamps: () => _stamps(
          _db.equipmentItems,
          _db.equipmentItems.id,
          _db.equipmentItems.updatedAt,
        ),
        load: (id) async =>
            {for (final e in await equipment.getAll()) e.id: e}[id],
        loadAll: () async => {
          for (final e in await equipment.getAll()) e.id: e,
        },
        idOf: (e) => e.id,
        updatedAt: (e) => e.updatedAt,
        encode: SyncCodec.equipment,
        decode: SyncCodec.decodeEquipment,
        put: equipment.put,
        titleOf: (e) => e.name,
      ),
      _Adapter.of<Aisle>(
        kind: SyncKind.aisle,
        stamps: () => _stamps(_db.aisles, _db.aisles.id, _db.aisles.updatedAt),
        load: (id) async =>
            {for (final a in await shopping.getAllAisles()) a.id: a}[id],
        loadAll: () async => {
          for (final a in await shopping.getAllAisles()) a.id: a,
        },
        idOf: (a) => a.id,
        updatedAt: (a) => a.updatedAt,
        encode: SyncCodec.aisle,
        decode: SyncCodec.decodeAisle,
        put: shopping.putAisle,
        titleOf: (a) => a.name,
      ),
      _Adapter.of<ProductAisle>(
        kind: SyncKind.product,
        stamps: () async => {
          for (final p in await shopping.getAllProductAisles())
            p.id: p.updatedAt,
        },
        load: (id) async =>
            {for (final p in await shopping.getAllProductAisles()) p.id: p}[id],
        loadAll: () async => {
          for (final p in await shopping.getAllProductAisles()) p.id: p,
        },
        idOf: (p) => p.id,
        updatedAt: (p) => p.updatedAt,
        encode: SyncCodec.product,
        decode: SyncCodec.decodeProduct,
        put: shopping.putProductAisle,
        titleOf: (p) => p.key,
      ),
      _Adapter.of<ShoppingList>(
        kind: SyncKind.shoppingList,
        stamps: () => _stamps(
          _db.shoppingLists,
          _db.shoppingLists.id,
          _db.shoppingLists.updatedAt,
        ),
        load: shopping.getList,
        loadAll: null,
        idOf: (l) => l.id,
        updatedAt: (l) => l.updatedAt,
        encode: SyncCodec.shoppingList,
        decode: SyncCodec.decodeShoppingList,
        put: shopping.putList,
        titleOf: (l) => l.name,
      ),
      _Adapter.of<MealSlot>(
        kind: SyncKind.mealSlot,
        stamps: () =>
            _stamps(_db.mealSlots, _db.mealSlots.id, _db.mealSlots.updatedAt),
        load: (id) async =>
            {for (final s in await planning.getAllSlots()) s.id: s}[id],
        loadAll: () async => {
          for (final s in await planning.getAllSlots()) s.id: s,
        },
        idOf: (s) => s.id,
        updatedAt: (s) => s.updatedAt,
        encode: SyncCodec.mealSlot,
        decode: SyncCodec.decodeMealSlot,
        put: planning.putSlot,
        titleOf: (s) => s.name,
      ),
      _Adapter.of<PlannedMeal>(
        kind: SyncKind.plannedMeal,
        stamps: () => _stamps(
          _db.plannedMeals,
          _db.plannedMeals.id,
          _db.plannedMeals.updatedAt,
        ),
        load: planning.getMeal,
        loadAll: () async => {
          for (final m in await planning.getAllMeals()) m.id: m,
        },
        idOf: (m) => m.id,
        updatedAt: (m) => m.updatedAt,
        encode: SyncCodec.plannedMeal,
        decode: SyncCodec.decodePlannedMeal,
        put: planning.putMeal,
        titleOf: (m) => m.recipeTitle.isNotEmpty ? m.recipeTitle : m.note,
      ),
      _Adapter.of<Recipe>(
        kind: SyncKind.recipe,
        stamps: () =>
            _stamps(_db.recipes, _db.recipes.id, _db.recipes.updatedAt),
        load: recipes.getRecipe,
        loadAll: null,
        idOf: (r) => r.id,
        updatedAt: (r) => r.updatedAt,
        encode: SyncCodec.recipe,
        decode: SyncCodec.decodeRecipe,
        put: recipes.put,
        titleOf: (r) => r.title,
      ),
    ];
  }

  final AppDatabase _db;
  final RecipeRepository _recipes;
  final PhotoStore _photos;
  final SyncRemote _remote;
  final HybridClock _clock;
  final DateTime Function() _now;
  late final List<_Adapter> _adapters;

  static const _tokenKey = 'changes_token';
  static const _maxSeenKey = 'max_seen';
  static const _lastSyncKey = 'last_sync';

  /// Les versions de nos propres envois, pour ne pas les relire.
  final Map<String, String> _own = {};

  /// Photos en cours d'envoi (deux recettes peuvent partager une photo).
  final Map<String, Future<void>> _mediaUploads = {};

  /// Nombre de fichiers lus ou envoyés en même temps : Drive répond en une
  /// fraction de seconde, mais chaque requête attend son tour sur le réseau.
  static const _parallel = 6;

  void Function(int done, int total)? _onProgress;
  int _done = 0;
  int _total = 0;

  void _plan(int count) {
    _total += count;
    _onProgress?.call(_done, _total);
  }

  void _step() {
    _done++;
    _onProgress?.call(_done, _total);
  }

  /// Exécute [task] sur chaque élément, [_parallel] à la fois.
  static Future<void> _forEach<T>(
    List<T> items,
    Future<void> Function(T item) task,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        await task(items[next++]);
      }
    }

    await Future.wait([
      for (var i = 0; i < _parallel && i < items.length; i++) worker(),
    ]);
  }

  /// Charge l'horloge corrigée de cet appareil (à l'ouverture de l'app).
  static Future<HybridClock> loadClock(
    AppDatabase database, {
    DateTime Function()? source,
  }) async {
    final row = await (database.select(
      database.syncSettings,
    )..where((s) => s.key.equals(_maxSeenKey))).getSingleOrNull();
    return HybridClock(
      source: source,
      lastSeen: row == null ? null : DateTime.tryParse(row.value),
    );
  }

  /// Oublie tout ce qu'on sait du dossier distant (déconnexion, autre compte) :
  /// la prochaine synchro relit tout et renvoie ce qui manque. Les données de
  /// l'appareil ne sont pas touchées.
  Future<void> reset() async {
    await _db.delete(_db.syncEntries).go();
    await (_db.delete(
          _db.syncSettings,
        )..where((s) => s.key.isIn([_tokenKey, _lastSyncKey, 'drive_folders'])))
        .go();
  }

  /// La date de la dernière synchro réussie, `null` si jamais.
  Future<DateTime?> lastSync() async {
    final value = await _setting(_lastSyncKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Une synchro complète : réception, envoi, puis relecture du dossier pour
  /// avancer le jeton au-delà de nos propres envois.
  ///
  /// [onProgress] reçoit le nombre de fichiers traités et le total connu.
  Future<SyncReport> sync({
    void Function(int done, int total)? onProgress,
  }) async {
    final report = SyncReport();
    _own.clear();
    _mediaUploads.clear();
    _onProgress = onProgress;
    _done = 0;
    _total = 0;
    try {
      if (!await _pull(report)) return report;
      final sent = await _push(report);
      if (report.ok && sent > 0) await _pull(report);
      if (report.ok) {
        await _setSetting(_lastSyncKey, _now().toUtc().toIso8601String());
      }
    } on Object catch (error) {
      report.errors.add('$error');
    }
    return report;
  }

  // ---------------------------------------------------------------- réception

  /// Renvoie `false` si la réception a échoué (on n'envoie alors rien : on
  /// risquerait d'écraser une version distante qu'on n'a pas pu lire).
  Future<bool> _pull(SyncReport report) async {
    RemoteChanges changes;
    try {
      changes = await _remote.changes(await _setting(_tokenKey));
    } on ChangesTokenExpired {
      // Jeton trop ancien : on relit tout le dossier (rien n'est perdu, les
      // éléments identiques sont simplement reconnus).
      changes = await _remote.changes(null);
    }
    final before = report.errors.length;
    final wanted = [
      for (final change in changes.items)
        if (SyncKind.parse(change.path) case (final kind, final id)?
            when kind != SyncKind.media &&
                (change.deleted || _own[change.path] != change.version))
          (change, kind, id),
    ];
    _plan(wanted.length);
    // Le classement et le matériel d'abord, puis les recettes.
    for (final recipes in [false, true]) {
      await _forEach(
        [
          for (final item in wanted)
            if ((item.$2 == SyncKind.recipe) == recipes) item,
        ],
        (item) async {
          final (change, kind, id) = item;
          try {
            if (change.deleted) {
              await _applyRemoteDelete(kind, id, report);
            } else {
              final bytes = await _remote.read(change.path);
              await _applyRemote(kind, id, bytes, report);
            }
          } on Object catch (error) {
            report.errors.add('${change.path} : $error');
          }
          _step();
        },
      );
    }
    final seen = _clock.lastSeen;
    if (seen != null) {
      await _setSetting(_maxSeenKey, seen.toUtc().toIso8601String());
    }
    if (report.errors.length > before) return false;
    await _setSetting(_tokenKey, changes.token);
    return true;
  }

  Future<void> _applyRemote(
    SyncKind kind,
    String id,
    Uint8List bytes,
    SyncReport report,
  ) async {
    final adapter = _adapter(kind);
    final remote = adapter.decode(bytes);
    final remoteStamp = adapter.updatedAt(remote);
    _clock.observe(remoteStamp);

    final local = await adapter.load(id);
    final entry = await _entry(kind, id);
    final synced = entry?.syncedUpdatedAt;

    if (local == null) {
      // Supprimé ici depuis la dernière synchro (la suppression part au
      // prochain envoi), sauf si une modification distante est plus récente.
      if (synced != null && !remoteStamp.isAfter(synced)) return;
      await _store(adapter, remote, report);
      return;
    }
    final localStamp = adapter.updatedAt(local);
    final dirty = synced == null || !_same(localStamp, synced);
    if (!dirty) {
      if (remoteStamp.isAfter(localStamp)) {
        await _store(adapter, remote, report);
      }
      return;
    }

    // Modifié ici depuis la dernière synchro.
    final localBytes = adapter.encode(local);
    if (SyncCodec.sameContent(localBytes, bytes)) {
      // Même contenu (éléments par défaut créés des deux côtés…) : on adopte
      // les dates distantes pour que les deux côtés soient identiques.
      await _store(adapter, remote, report, count: false);
      return;
    }
    final localWon = localStamp.isAfter(remoteStamp);
    final loser = localWon ? bytes : localBytes;
    final loserStamp = localWon ? remoteStamp : localStamp;
    final historyPath = _historyPath(kind, id, loserStamp);
    await _remote.write(historyPath, loser);
    report.conflicts.add(
      SyncConflict(
        kind: kind,
        id: id,
        title: adapter.titleOf(localWon ? local : remote),
        localWon: localWon,
        historyPath: historyPath,
      ),
    );
    if (!localWon) await _store(adapter, remote, report);
  }

  Future<void> _store(
    _Adapter adapter,
    Object remote,
    SyncReport report, {
    bool count = true,
  }) async {
    if (remote is Recipe) {
      for (final name in remote.allPhotos) {
        if (_photos.file(name).existsSync()) continue;
        final bytes = await _remote.read(SyncKind.media.path(name));
        await _photos.write(name, bytes);
      }
    }
    await adapter.put(remote);
    await _markSynced(
      adapter.kind,
      adapter.idOf(remote),
      adapter.updatedAt(remote),
    );
    if (count) report.downloaded++;
  }

  Future<void> _applyRemoteDelete(
    SyncKind kind,
    String id,
    SyncReport report,
  ) async {
    // Seules les recettes se suppriment pour de bon ; le classement et le
    // matériel supprimés restent des éléments marqués supprimés.
    if (kind != SyncKind.recipe) return;
    final local = await _recipes.getRecipe(id);
    final entry = await _entry(kind, id);
    if (local == null) {
      await _forget(kind, id);
      return;
    }
    final synced = entry?.syncedUpdatedAt;
    final dirty = synced == null || !_same(local.updatedAt, synced);
    if (dirty) return; // modifié ici depuis : la modification l'emporte
    final unused = await _recipes.deletePermanently([id]);
    await _photos.deleteAll(unused);
    await _forget(kind, id);
    report.deletedLocal++;
  }

  // -------------------------------------------------------------------- envoi

  Future<int> _push(SyncReport report) async {
    var sent = 0;
    for (final adapter in _adapters) {
      final stamps = await adapter.stamps();
      final entries = await _entries(adapter.kind);
      final cache = adapter.loadAll == null ? null : await adapter.loadAll!();
      final dirty = <String>[];
      for (final MapEntry(key: id, value: stamp) in stamps.entries) {
        final synced = entries[id]?.syncedUpdatedAt;
        if (synced == null || !_same(stamp, synced)) dirty.add(id);
      }
      final gone = adapter.kind == SyncKind.recipe
          ? [
              for (final id in entries.keys)
                if (!stamps.containsKey(id)) id,
            ]
          : const <String>[];
      _plan(dirty.length + gone.length);

      await _forEach(dirty, (id) async {
        try {
          final item = cache != null ? cache[id] : await adapter.load(id);
          if (item != null) {
            if (item is Recipe) await _pushPhotos(item, report);
            final path = adapter.kind.path(id);
            _own[path] = await _remote.write(path, adapter.encode(item));
            await _markSynced(adapter.kind, id, adapter.updatedAt(item));
            sent++;
            report.uploaded++;
          }
        } on Object catch (error) {
          report.errors.add('${adapter.kind.path(id)} : $error');
        }
        _step();
      });

      await _forEach(gone, (id) async {
        try {
          await _remote.delete(adapter.kind.path(id));
          await _forget(adapter.kind, id);
          sent++;
          report.deletedRemote++;
        } on Object catch (error) {
          report.errors.add('${adapter.kind.path(id)} : $error');
        }
        _step();
      });
    }
    return sent;
  }

  Future<void> _pushPhotos(Recipe recipe, SyncReport report) async {
    for (final name in recipe.allPhotos) {
      await (_mediaUploads[name] ??= _pushPhoto(name, report));
    }
  }

  Future<void> _pushPhoto(String name, SyncReport report) async {
    if (await _entry(SyncKind.media, name) != null) return;
    final file = _photos.file(name);
    if (!file.existsSync()) return;
    final path = SyncKind.media.path(name);
    _own[path] = await _remote.write(path, await file.readAsBytes());
    await _markSynced(SyncKind.media, name, null);
    report.uploaded++;
  }

  // ------------------------------------------------------------------- détails

  _Adapter _adapter(SyncKind kind) =>
      _adapters.firstWhere((a) => a.kind == kind);

  static bool _same(DateTime a, DateTime b) => a.isAtSameMomentAs(b);

  String _historyPath(SyncKind kind, String id, DateTime stamp) {
    final moment = stamp.toUtc().toIso8601String().replaceAll(
      RegExp(r'[-:.]'),
      '',
    );
    return 'history/${kind.folder}-$id-$moment.json';
  }

  Future<Map<String, DateTime>> _stamps(
    TableInfo<Table, dynamic> table,
    GeneratedColumn<String> id,
    GeneratedColumn<DateTime> updatedAt,
  ) async {
    final rows = await (_db.selectOnly(
      table,
    )..addColumns([id, updatedAt])).get();
    return {for (final row in rows) row.read(id)!: row.read(updatedAt)!};
  }

  Future<SyncEntryRow?> _entry(SyncKind kind, String id) =>
      (_db.select(_db.syncEntries)
            ..where((e) => e.kind.equals(kind.name) & e.id.equals(id)))
          .getSingleOrNull();

  Future<Map<String, SyncEntryRow>> _entries(SyncKind kind) async => {
    for (final row in await (_db.select(
      _db.syncEntries,
    )..where((e) => e.kind.equals(kind.name))).get())
      row.id: row,
  };

  Future<void> _markSynced(SyncKind kind, String id, DateTime? stamp) => _db
      .into(_db.syncEntries)
      .insertOnConflictUpdate(
        SyncEntriesCompanion.insert(
          kind: kind.name,
          id: id,
          syncedUpdatedAt: Value(stamp),
        ),
      );

  Future<void> _forget(SyncKind kind, String id) => (_db.delete(
    _db.syncEntries,
  )..where((e) => e.kind.equals(kind.name) & e.id.equals(id))).go();

  Future<String?> _setting(String key) async => (await (_db.select(
    _db.syncSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setSetting(String key, String value) => _db
      .into(_db.syncSettings)
      .insertOnConflictUpdate(
        SyncSettingsCompanion.insert(key: key, value: value),
      );
}

/// Ce qui change d'un genre d'élément à l'autre. Les fonctions travaillent sur
/// des `Object` : [_Adapter.of] y range celles, typées, de chaque genre.
class _Adapter {
  _Adapter({
    required this.kind,
    required this.stamps,
    required this.load,
    required this.loadAll,
    required this.idOf,
    required this.updatedAt,
    required this.encode,
    required this.decode,
    required this.put,
    required this.titleOf,
  });

  static _Adapter of<T extends Object>({
    required SyncKind kind,
    required Future<Map<String, DateTime>> Function() stamps,
    required Future<T?> Function(String id) load,
    required Future<Map<String, T>> Function()? loadAll,
    required String Function(T) idOf,
    required DateTime Function(T) updatedAt,
    required Uint8List Function(T) encode,
    required T Function(Uint8List) decode,
    required Future<void> Function(T) put,
    required String Function(T) titleOf,
  }) => _Adapter(
    kind: kind,
    stamps: stamps,
    load: load,
    loadAll: loadAll,
    idOf: (o) => idOf(o as T),
    updatedAt: (o) => updatedAt(o as T),
    encode: (o) => encode(o as T),
    decode: decode,
    put: (o) => put(o as T),
    titleOf: (o) => titleOf(o as T),
  );

  final SyncKind kind;
  final Future<Map<String, DateTime>> Function() stamps;
  final Future<Object?> Function(String id) load;

  /// Tout le genre d'un coup (petites listes) ; `null` pour les recettes,
  /// lues une à une.
  final Future<Map<String, Object>> Function()? loadAll;
  final String Function(Object) idOf;
  final DateTime Function(Object) updatedAt;
  final Uint8List Function(Object) encode;
  final Object Function(Uint8List) decode;
  final Future<void> Function(Object) put;
  final String Function(Object) titleOf;
}
