import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/label.dart';
import 'database.dart';

/// Le classement commun : catégories, collections, étiquettes, saisons… Un nom
/// n'existe qu'une fois dans sa famille (et sous son parent), à la casse, aux
/// accents et au pluriel près.
class LabelRepository {
  LabelRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  /// Les éléments actifs, dans l'ordre de leur famille.
  Stream<List<Label>> watchAll() {
    final query = _db.select(_db.labels)..where((l) => l.deletedAt.isNull());
    return query.watch().map(
      (rows) => _sorted([for (final row in rows) _fromRow(row)]),
    );
  }

  /// Tout, supprimé compris (sauvegarde).
  Future<List<Label>> getAll() async {
    final rows = await _db.select(_db.labels).get();
    return [for (final row in rows) _fromRow(row)];
  }

  /// Nombre de recettes (hors corbeille) rattachées à chaque élément.
  Stream<Map<String, int>> watchUsage() {
    final query = _db.customSelect(
      'SELECT rl.label_id AS id, COUNT(*) AS uses FROM recipe_labels rl '
      'JOIN recipes r ON r.id = rl.recipe_id WHERE r.deleted_at IS NULL '
      'GROUP BY rl.label_id',
      readsFrom: {_db.recipeLabels, _db.recipes},
    );
    return query.watch().map(
      (rows) => {
        for (final r in rows) r.read<String>('id'): r.read<int>('uses'),
      },
    );
  }

  /// L'élément de ce nom (sous ce parent), créé s'il n'existe pas ; un élément
  /// supprimé qu'on retape est ressuscité.
  Future<Label> findOrCreate(
    LabelKind kind,
    String name, {
    String? parentId,
    String icon = '',
    String color = '',
  }) async {
    final clean = Label.cleanName(name);
    final key = Label.keyOf(clean);
    final all = await getAll();
    final existing = all
        .where(
          (l) =>
              l.kind == kind &&
              l.parentId == parentId &&
              Label.keyOf(l.name) == key,
        )
        .firstOrNull;
    final now = _clock();
    if (existing != null) {
      if (!existing.isDeleted) return existing;
      final revived = existing.copyWith(
        name: clean,
        updatedAt: now,
        deletedAt: () => null,
      );
      await put(revived);
      return revived;
    }
    final position = all
        .where((l) => l.kind == kind && l.parentId == parentId && !l.isDeleted)
        .length;
    final label = Label(
      id: Label.idFor(kind, clean, parentId: parentId),
      kind: kind,
      name: clean,
      parentId: parentId,
      icon: icon,
      color: color,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
    await put(label);
    return label;
  }

  /// Renomme. Renvoie `false` si le nom est vide ou déjà pris au même endroit.
  Future<bool> rename(String id, String name) async {
    final clean = Label.cleanName(name);
    if (clean.isEmpty) return false;
    final all = await getAll();
    final current = all.where((l) => l.id == id).firstOrNull;
    if (current == null) return false;
    final key = Label.keyOf(clean);
    if (all.any(
      (l) =>
          l.id != id &&
          !l.isDeleted &&
          l.kind == current.kind &&
          l.parentId == current.parentId &&
          Label.keyOf(l.name) == key,
    )) {
      return false;
    }
    await put(current.copyWith(name: clean, updatedAt: _clock()));
    return true;
  }

  Future<void> setStyle(String id, {String? icon, String? color}) async {
    final current = (await getAll()).where((l) => l.id == id).firstOrNull;
    if (current == null) return;
    await put(current.copyWith(icon: icon, color: color, updatedAt: _clock()));
  }

  /// Supprime l'élément et ses sous-catégories, et les retire des recettes
  /// (dont la date de modification est mise à jour).
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final all = await getAll();
      final doomed = _subtree(all, id);
      final now = _clock();
      for (final label in all.where((l) => doomed.contains(l.id))) {
        await put(label.copyWith(updatedAt: now, deletedAt: () => now));
      }
      await _unlink(doomed, now);
    });
  }

  /// Fusionne [sourceId] dans [targetId] (même famille) : les recettes de
  /// l'un passent à l'autre, les sous-catégories suivent (et se fusionnent si
  /// elles portent le même nom).
  Future<void> merge(String sourceId, String targetId) {
    return _db.transaction(() async {
      if (sourceId == targetId) return;
      final all = await getAll();
      final source = all.where((l) => l.id == sourceId).firstOrNull;
      final target = all.where((l) => l.id == targetId).firstOrNull;
      if (source == null || target == null || source.kind != target.kind) {
        return;
      }
      await _mergeInto(all, source, target, _clock());
    });
  }

  Future<void> _mergeInto(
    List<Label> all,
    Label source,
    Label target,
    DateTime now,
  ) async {
    // Les sous-catégories : fusionnées avec celle du même nom, sinon déplacées.
    final targetChildren = all.where(
      (l) => l.parentId == target.id && !l.isDeleted,
    );
    for (final child in all.where(
      (l) => l.parentId == source.id && !l.isDeleted,
    )) {
      final twin = targetChildren
          .where((t) => Label.keyOf(t.name) == Label.keyOf(child.name))
          .firstOrNull;
      if (twin != null) {
        await _mergeInto(all, child, twin, now);
      } else {
        await put(child.copyWith(parentId: () => target.id, updatedAt: now));
      }
    }
    final rows = await (_db.select(
      _db.recipeLabels,
    )..where((l) => l.labelId.equals(source.id))).get();
    for (final row in rows) {
      final already =
          await (_db.select(_db.recipeLabels)..where(
                (l) =>
                    l.recipeId.equals(row.recipeId) &
                    l.labelId.equals(target.id),
              ))
              .getSingleOrNull();
      await (_db.delete(_db.recipeLabels)..where(
            (l) =>
                l.recipeId.equals(row.recipeId) & l.labelId.equals(source.id),
          ))
          .go();
      if (already == null) {
        await _db
            .into(_db.recipeLabels)
            .insert(
              RecipeLabelsCompanion.insert(
                recipeId: row.recipeId,
                labelId: target.id,
                sortIndex: Value(row.sortIndex),
              ),
            );
      }
      await _touchRecipe(row.recipeId, now);
    }
    await put(source.copyWith(updatedAt: now, deletedAt: () => now));
  }

  Future<void> _unlink(Set<String> labelIds, DateTime now) async {
    final rows = await (_db.select(
      _db.recipeLabels,
    )..where((l) => l.labelId.isIn(labelIds))).get();
    await (_db.delete(
      _db.recipeLabels,
    )..where((l) => l.labelId.isIn(labelIds))).go();
    for (final recipeId in {for (final r in rows) r.recipeId}) {
      await _touchRecipe(recipeId, now);
    }
  }

  /// Fixe l'ordre des recettes d'une collection : la première de la liste
  /// passe en tête. Les recettes qui n'y sont pas ne bougent pas.
  Future<void> setOrder(String labelId, List<String> recipeIds) {
    return _db.transaction(() async {
      for (final (index, recipeId) in recipeIds.indexed) {
        await (_db.update(_db.recipeLabels)..where(
              (l) => l.recipeId.equals(recipeId) & l.labelId.equals(labelId),
            ))
            .write(RecipeLabelsCompanion(sortIndex: Value(index)));
      }
    });
  }

  Future<void> _touchRecipe(String recipeId, DateTime now) {
    return (_db.update(_db.recipes)..where((r) => r.id.equals(recipeId))).write(
      RecipesCompanion(updatedAt: Value(now)),
    );
  }

  static Set<String> _subtree(List<Label> all, String rootId) {
    final ids = {rootId};
    var grew = true;
    while (grew) {
      grew = false;
      for (final label in all) {
        if (label.parentId != null &&
            ids.contains(label.parentId) &&
            ids.add(label.id)) {
          grew = true;
        }
      }
    }
    return ids;
  }

  /// Écrit un élément tel quel (import, restauration).
  Future<void> put(Label label) {
    return _db
        .into(_db.labels)
        .insertOnConflictUpdate(
          LabelsCompanion.insert(
            id: label.id,
            kind: label.kind.code,
            name: label.name,
            parentId: Value(label.parentId),
            icon: Value(label.icon),
            color: Value(label.color),
            position: Value(label.position),
            createdAt: label.createdAt,
            updatedAt: label.updatedAt,
            deletedAt: Value(label.deletedAt),
          ),
        );
  }

  Future<void> deleteAll() => _db.delete(_db.labels).go();

  static String newId() => _uuid.v4();

  static List<Label> _sorted(List<Label> labels) => labels
    ..sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      final byPosition = a.position.compareTo(b.position);
      return byPosition != 0
          ? byPosition
          : Label.keyOf(a.name).compareTo(Label.keyOf(b.name));
    });

  static Label _fromRow(LabelRow row) => Label(
    id: row.id,
    kind: LabelKind.fromCode(row.kind) ?? LabelKind.collection,
    name: row.name,
    parentId: row.parentId,
    icon: row.icon,
    color: row.color,
    position: row.position,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
