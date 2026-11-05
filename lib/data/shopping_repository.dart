import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import '../domain/shopping.dart';
import 'database.dart';

/// Les listes de courses, les rayons et le rayon retenu pour chaque produit.
class ShoppingRepository {
  ShoppingRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  // --- Listes ---

  /// Les listes actives, la plus récemment modifiée d'abord.
  Stream<List<ShoppingList>> watchLists() {
    final lists = _db.select(_db.shoppingLists)
      ..where((l) => l.deletedAt.isNull())
      ..orderBy([(l) => OrderingTerm.desc(l.updatedAt)]);
    return lists.watch().asyncMap(_withItems);
  }

  Stream<ShoppingList?> watchList(String id) {
    final query = _db.select(_db.shoppingLists)..where((l) => l.id.equals(id));
    return query.watchSingleOrNull().asyncMap(
      (row) async => row == null ? null : (await _withItems([row])).single,
    );
  }

  Future<ShoppingList?> getList(String id) async {
    final row = await (_db.select(
      _db.shoppingLists,
    )..where((l) => l.id.equals(id))).getSingleOrNull();
    return row == null ? null : (await _withItems([row])).single;
  }

  /// Toutes les listes, supprimées comprises (sauvegarde, synchro).
  Future<List<ShoppingList>> getAllLists() async =>
      _withItems(await _db.select(_db.shoppingLists).get());

  Future<ShoppingList> createList(String name) async {
    final now = _clock();
    final list = ShoppingList(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await putList(list);
    return list;
  }

  /// Une nouvelle liste avec les produits de [source], tous à acheter.
  Future<ShoppingList> duplicateList(ShoppingList source, String name) async {
    final now = _clock();
    final list = ShoppingList(
      id: _uuid.v4(),
      name: name.trim(),
      items: [
        for (final item in source.items)
          ShoppingItem(
            id: _uuid.v4(),
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            toBuy: item.toBuy,
            format: item.format,
            note: item.note,
            aisleId: item.aisleId,
            sources: item.sources,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    await putList(list);
    return list;
  }

  /// Change la liste : ses produits sont remplacés par [list.items], et sa
  /// date de modification avance (synchro).
  Future<void> save(ShoppingList list) =>
      putList(list.copyWith(updatedAt: _clock()));

  Future<void> rename(ShoppingList list, String name) =>
      save(list.copyWith(name: name.trim()));

  Future<void> delete(ShoppingList list) {
    final now = _clock();
    return putList(list.copyWith(updatedAt: now, deletedAt: () => now));
  }

  /// Remet une liste supprimée (annulation).
  Future<void> restore(ShoppingList list) =>
      putList(list.copyWith(updatedAt: _clock(), deletedAt: () => null));

  /// Écrit une liste et ses produits tels quels (import, synchro).
  Future<void> putList(ShoppingList list) {
    return _db.transaction(() async {
      await _db
          .into(_db.shoppingLists)
          .insertOnConflictUpdate(
            ShoppingListsCompanion.insert(
              id: list.id,
              name: list.name,
              createdAt: list.createdAt,
              updatedAt: list.updatedAt,
              deletedAt: Value(list.deletedAt),
            ),
          );
      await (_db.delete(
        _db.shoppingItems,
      )..where((i) => i.listId.equals(list.id))).go();
      await _db.batch((batch) {
        batch.insertAll(_db.shoppingItems, [
          for (final (position, item) in list.items.indexed)
            ShoppingItemsCompanion.insert(
              id: item.id,
              listId: list.id,
              position: position,
              name: item.name,
              quantity: Value(item.quantity),
              unit: Value(item.unit),
              toBuy: Value(item.toBuy),
              format: Value(item.format),
              note: Value(item.note),
              aisleId: Value(item.aisleId),
              checked: Value(item.checked),
              sources: Value(encodeSources(item.sources)),
            ),
        ]);
      });
    });
  }

  /// Les noms déjà utilisés dans les listes, du plus fréquent au moins
  /// fréquent (suggestions à la saisie).
  Future<List<String>> knownProducts() async {
    final rows = await _db.select(_db.shoppingItems).get();
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final row in rows) {
      final key = ShoppingProducts.keyOf(row.name);
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () => row.name);
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0
            ? byCount
            : normalizeForSearch(names[a]!)
                  .compareTo(normalizeForSearch(names[b]!));
      });
    return [for (final k in keys) names[k]!];
  }

  Future<void> deleteAllLists() => _db.delete(_db.shoppingLists).go();

  Future<List<ShoppingList>> _withItems(List<ShoppingListRow> rows) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r.id];
    final itemRows =
        await (_db.select(_db.shoppingItems)
              ..where((i) => i.listId.isIn(ids))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final byList = <String, List<ShoppingItem>>{};
    for (final row in itemRows) {
      (byList[row.listId] ??= []).add(
        ShoppingItem(
          id: row.id,
          name: row.name,
          quantity: row.quantity,
          unit: row.unit,
          toBuy: row.toBuy,
          format: row.format,
          note: row.note,
          aisleId: row.aisleId,
          checked: row.checked,
          sources: decodeSources(row.sources),
        ),
      );
    }
    return [
      for (final row in rows)
        ShoppingList(
          id: row.id,
          name: row.name,
          items: byList[row.id] ?? const [],
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
        ),
    ];
  }

  static String encodeSources(List<ShoppingSource> sources) => jsonEncode([
    for (final s in sources)
      {
        'recipeId': s.recipeId,
        'recipeTitle': s.recipeTitle,
        'quantity': s.quantity,
        'unit': s.unit,
      },
  ]);

  static List<ShoppingSource> decodeSources(String json) {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    if (data is! List) return const [];
    return [
      for (final s in data)
        if (s is Map && s['recipeId'] is String)
          ShoppingSource(
            recipeId: s['recipeId'] as String,
            recipeTitle: s['recipeTitle'] as String? ?? '',
            quantity: (s['quantity'] as num?)?.toDouble(),
            unit: s['unit'] as String? ?? '',
          ),
    ];
  }

  // --- Rayons ---

  /// Les rayons actifs, dans l'ordre choisi.
  Stream<List<Aisle>> watchAisles() {
    final query = _db.select(_db.aisles)
      ..where((a) => a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.asc(a.position)]);
    return query.watch().map((rows) => [for (final r in rows) _aisle(r)]);
  }

  /// Tous les rayons, supprimés compris (sauvegarde, synchro).
  Future<List<Aisle>> getAllAisles() async => [
    for (final r in await _db.select(_db.aisles).get()) _aisle(r),
  ];

  Future<void> putAisle(Aisle aisle) => _db
      .into(_db.aisles)
      .insertOnConflictUpdate(
        AislesCompanion.insert(
          id: aisle.id,
          name: aisle.name,
          position: Value(aisle.position),
          createdAt: aisle.createdAt,
          updatedAt: aisle.updatedAt,
          deletedAt: Value(aisle.deletedAt),
        ),
      );

  static Aisle _aisle(AisleRow r) => Aisle(
    id: r.id,
    name: r.name,
    position: r.position,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deletedAt: r.deletedAt,
  );

  // --- Rayon retenu pour chaque produit ---

  /// Le rayon retenu pour chaque produit : clé du produit → rayon.
  Stream<Map<String, String>> watchProductAisles() => _db
      .select(_db.productAisles)
      .watch()
      .map((rows) => {for (final r in rows) r.key: r.aisleId});

  /// Retient [aisleId] pour le produit [name] (et ses variantes au pluriel).
  Future<void> rememberAisle(String name, String aisleId) => putProductAisle(
    ProductAisle(
      key: ShoppingProducts.keyOf(name),
      aisleId: aisleId,
      updatedAt: _clock(),
    ),
  );

  Future<Aisle> createAisle(String name) async {
    final now = _clock();
    final existing = await getAllAisles();
    final position = existing.isEmpty
        ? 0
        : existing.map((a) => a.position).reduce((a, b) => a > b ? a : b) + 1;
    final aisle = Aisle(
      id: _uuid.v4(),
      name: name.trim(),
      position: position,
      createdAt: now,
      updatedAt: now,
    );
    await putAisle(aisle);
    return aisle;
  }

  Future<void> renameAisle(Aisle aisle, String name) =>
      putAisle(aisle.copyWith(name: name.trim(), updatedAt: _clock()));

  Future<void> deleteAisle(Aisle aisle) {
    final now = _clock();
    return putAisle(aisle.copyWith(updatedAt: now, deletedAt: () => now));
  }

  /// Range les rayons dans l'ordre de [ordered].
  Future<void> reorderAisles(List<Aisle> ordered) => _db.transaction(() async {
    final now = _clock();
    for (final (position, aisle) in ordered.indexed) {
      if (aisle.position != position) {
        await putAisle(aisle.copyWith(position: position, updatedAt: now));
      }
    }
  });

  Future<List<ProductAisle>> getAllProductAisles() async => [
    for (final r in await _db.select(_db.productAisles).get())
      ProductAisle(key: r.key, aisleId: r.aisleId, updatedAt: r.updatedAt),
  ];

  Future<void> putProductAisle(ProductAisle product) => _db
      .into(_db.productAisles)
      .insertOnConflictUpdate(
        ProductAislesCompanion.insert(
          key: product.key,
          aisleId: product.aisleId,
          updatedAt: product.updatedAt,
        ),
      );
}
