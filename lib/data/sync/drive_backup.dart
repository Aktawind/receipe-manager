import 'dart:typed_data';

import '../../domain/shopping.dart';
import '../backup/backup_service.dart';
import '../photo_store.dart';
import 'hybrid_clock.dart';
import 'sync_remote.dart';

/// À quelle fréquence la sauvegarde Drive est faite toute seule.
enum BackupFrequency {
  off(null),
  daily(Duration(days: 1)),
  weekly(Duration(days: 7)),
  monthly(Duration(days: 30));

  const BackupFrequency(this.every);

  /// `null` : jamais.
  final Duration? every;

  static BackupFrequency fromName(String? name) =>
      BackupFrequency.values.asNameMap()[name] ?? BackupFrequency.daily;

  /// La sauvegarde est-elle due ? [last] : la dernière, `null` si jamais.
  bool isDue(DateTime? last, DateTime now) {
    final every = this.every;
    if (every == null) return false;
    return last == null || now.difference(last) >= every;
  }
}

/// Ce qu'une restauration a fait.
class RestoreResult {
  const RestoreResult({required this.recipes, required this.missingPhotos});

  final int recipes;

  /// Photos de la sauvegarde introuvables dans `media/` (rares : une photo
  /// n'y est jamais supprimée).
  final int missingPhotos;
}

/// Les sauvegardes dans le dossier Drive : une sauvegarde est un fichier de
/// données (sans photos) ; les photos restent dans `media/`.
///
/// Elle protège d'une erreur que la synchro propagerait sur tous les
/// appareils (recettes supprimées par mégarde, par exemple).
class DriveBackupService {
  DriveBackupService({
    required this.remote,
    required this.sync,
    required this.backups,
    required this.photos,
    required this.clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final BackupRemote remote;

  /// Pour lire les photos de `media/` à la restauration.
  final SyncRemote sync;
  final BackupService backups;
  final PhotoStore photos;
  final HybridClock clock;
  final DateTime Function() _now;

  /// Nombre de sauvegardes gardées dans Drive (les plus anciennes partent à la
  /// corbeille de Drive).
  static const keep = 10;

  static String fileName(DateTime moment) {
    String two(int v) => v.toString().padLeft(2, '0');
    final m = moment.toLocal();
    return 'sauvegarde-${m.year}-${two(m.month)}-${two(m.day)}'
        '-${two(m.hour)}${two(m.minute)}.json';
  }

  /// Sauvegarde maintenant, puis fait le tri des plus anciennes.
  Future<void> backupNow() async {
    final data = Uint8List.fromList(await backups.exportJson());
    await remote.uploadBackup(fileName(_now()), data);
    final all = await remote.listBackups();
    for (final old in all.skip(keep)) {
      await remote.deleteBackup(old.id);
    }
  }

  Future<List<RemoteBackup>> list() => remote.listBackups();

  /// Remplace les données de cet appareil par celles de la sauvegarde.
  ///
  /// Une copie de sécurité locale est faite avant. Les données restaurées sont
  /// datées de maintenant : à la synchro suivante elles l'emportent sur ce que
  /// Drive contient (sans cela, la version plus récente de Drive reviendrait).
  Future<RestoreResult> restore(RemoteBackup backup) async {
    final contents = backups.readJson(await remote.downloadBackup(backup.id));

    var missing = 0;
    final names = contents.recipes.expand((r) => r.allPhotos).toSet();
    for (final name in names) {
      if (photos.file(name).existsSync()) continue;
      try {
        await photos.write(name, await sync.read('media/$name'));
      } on Object {
        missing++;
      }
    }

    final stamp = clock.now();
    await backups.import(
      BackupContents(
        [for (final r in contents.recipes) r.copyWith(updatedAt: stamp)],
        const {},
        equipment: [
          for (final e in contents.equipment) e.copyWith(updatedAt: stamp),
        ],
        labels: [for (final l in contents.labels) l.copyWith(updatedAt: stamp)],
        shoppingLists: [
          for (final l in contents.shoppingLists) l.copyWith(updatedAt: stamp),
        ],
        aisles: [for (final a in contents.aisles) a.copyWith(updatedAt: stamp)],
        productAisles: [
          for (final p in contents.productAisles)
            ProductAisle(key: p.key, aisleId: p.aisleId, updatedAt: stamp),
        ],
        mealSlots: [
          for (final s in contents.mealSlots) s.copyWith(updatedAt: stamp),
        ],
        plannedMeals: [
          for (final m in contents.plannedMeals) m.copyWith(updatedAt: stamp),
        ],
        sideDishes: [
          for (final d in contents.sideDishes) d.copyWith(updatedAt: stamp),
        ],
        plannerSetups: [
          for (final p in contents.plannerSetups) p.copyWith(updatedAt: stamp),
        ],
        savedSearches: [
          for (final s in contents.savedSearches) s.copyWith(updatedAt: stamp),
        ],
      ),
      ImportMode.replace,
    );
    return RestoreResult(
      recipes: contents.recipes.length,
      missingPhotos: missing,
    );
  }
}
