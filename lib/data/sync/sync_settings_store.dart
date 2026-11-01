import '../database.dart';
import 'drive_remote.dart';

/// Les réglages de synchronisation propres à l'appareil, dans la base.
class SyncSettingsStore implements DriveCache {
  SyncSettingsStore(this._db);

  final AppDatabase _db;

  @override
  Future<String?> read(String key) async => (await (_db.select(
    _db.syncSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  @override
  Future<void> write(String key, String value) => _db
      .into(_db.syncSettings)
      .insertOnConflictUpdate(
        SyncSettingsCompanion.insert(key: key, value: value),
      );
}
