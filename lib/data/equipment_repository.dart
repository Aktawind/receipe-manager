import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/equipment.dart';
import 'database.dart';

/// La liste commune du matériel. Un matériel n'a qu'un nom ; deux noms qui ne
/// diffèrent que par la casse ou les accents désignent le même matériel.
class EquipmentRepository {
  EquipmentRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  /// Le matériel actif, trié par nom.
  Stream<List<EquipmentItem>> watchAll() {
    final query = _db.select(_db.equipmentItems)
      ..where((e) => e.deletedAt.isNull());
    return query.watch().map(
      (rows) => _sorted([for (final row in rows) _fromRow(row)]),
    );
  }

  /// Tout le matériel, supprimé compris (sauvegarde).
  Future<List<EquipmentItem>> getAll() async {
    final rows = await _db.select(_db.equipmentItems).get();
    return [for (final row in rows) _fromRow(row)];
  }

  /// Nombre de recettes (hors corbeille) qui utilisent chaque matériel.
  Stream<Map<String, int>> watchUsage() {
    final query = _db.customSelect(
      'SELECT e.equipment_id AS id, COUNT(*) AS uses FROM recipe_equipment e '
      'JOIN recipes r ON r.id = e.recipe_id WHERE r.deleted_at IS NULL '
      'GROUP BY e.equipment_id',
      readsFrom: {_db.recipeEquipment, _db.recipes},
    );
    return query.watch().map(
      (rows) => {
        for (final r in rows) r.read<String>('id'): r.read<int>('uses'),
      },
    );
  }

  /// Le matériel de ce nom, créé s'il n'existe pas encore (un matériel supprimé
  /// qu'on retape est ressuscité).
  Future<EquipmentItem> findOrCreate(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final key = EquipmentItem.keyOf(clean);
    final existing = (await getAll()).where(
      (e) => EquipmentItem.keyOf(e.name) == key,
    );
    final now = _clock();
    if (existing.isNotEmpty) {
      final item = existing.first;
      if (!item.isDeleted) return item;
      final revived = item.copyWith(
        name: clean,
        updatedAt: now,
        deletedAt: () => null,
      );
      await put(revived);
      return revived;
    }
    final item = EquipmentItem(
      id: _uuid.v4(),
      name: clean,
      createdAt: now,
      updatedAt: now,
    );
    await put(item);
    return item;
  }

  /// Renomme. Renvoie `false` si un autre matériel porte déjà ce nom.
  Future<bool> rename(String id, String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return false;
    final key = EquipmentItem.keyOf(clean);
    final all = await getAll();
    if (all.any(
      (e) => e.id != id && !e.isDeleted && EquipmentItem.keyOf(e.name) == key,
    )) {
      return false;
    }
    final current = all.where((e) => e.id == id).firstOrNull;
    if (current == null) return false;
    await put(current.copyWith(name: clean, updatedAt: _clock()));
    return true;
  }

  /// Supprime le matériel et le retire des recettes qui l'utilisaient (leur
  /// date de modification est mise à jour).
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final now = _clock();
      final current = (await getAll()).where((e) => e.id == id).firstOrNull;
      if (current == null) return;
      await put(current.copyWith(updatedAt: now, deletedAt: () => now));
      final users = await (_db.select(
        _db.recipeEquipment,
      )..where((e) => e.equipmentId.equals(id))).get();
      for (final recipeId in {for (final u in users) u.recipeId}) {
        await (_db.delete(_db.recipeEquipment)..where(
              (e) => e.recipeId.equals(recipeId) & e.equipmentId.equals(id),
            ))
            .go();
        // Ferme le trou laissé dans l'ordre.
        final rest =
            await (_db.select(_db.recipeEquipment)
                  ..where((e) => e.recipeId.equals(recipeId))
                  ..orderBy([(e) => OrderingTerm.asc(e.position)]))
                .get();
        await (_db.delete(
          _db.recipeEquipment,
        )..where((e) => e.recipeId.equals(recipeId))).go();
        await _db.batch((batch) {
          batch.insertAll(_db.recipeEquipment, [
            for (final (index, row) in rest.indexed)
              RecipeEquipmentCompanion.insert(
                recipeId: recipeId,
                position: index,
                equipmentId: row.equipmentId,
              ),
          ]);
        });
        await (_db.update(_db.recipes)..where((r) => r.id.equals(recipeId)))
            .write(RecipesCompanion(updatedAt: Value(now)));
      }
    });
  }

  /// Écrit un matériel tel quel (import, restauration).
  Future<void> put(EquipmentItem item) {
    return _db
        .into(_db.equipmentItems)
        .insertOnConflictUpdate(
          EquipmentItemsCompanion.insert(
            id: item.id,
            name: item.name,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            deletedAt: Value(item.deletedAt),
          ),
        );
  }

  Future<void> deleteAll() => _db.delete(_db.equipmentItems).go();

  static List<EquipmentItem> _sorted(List<EquipmentItem> items) => items
    ..sort(
      (a, b) =>
          EquipmentItem.keyOf(a.name).compareTo(EquipmentItem.keyOf(b.name)),
    );

  static EquipmentItem _fromRow(EquipmentRow row) => EquipmentItem(
    id: row.id,
    name: row.name,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
