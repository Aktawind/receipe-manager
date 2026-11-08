import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup/backup_service.dart';
import 'database.dart';
import 'equipment_repository.dart';
import 'label_repository.dart';
import 'photo_store.dart';
import 'planning_repository.dart';
import 'recipe_repository.dart';
import 'shopping_repository.dart';
import 'sync/hybrid_clock.dart';
import 'sync/sync_engine.dart';

/// Les services de données de l'app, ouverts une fois au démarrage.
class AppServices {
  AppServices({
    required this.database,
    required this.recipes,
    required this.equipment,
    required this.labels,
    required this.shopping,
    required this.planning,
    required this.photos,
    required this.backups,
    required this.clock,
    required this.root,
  });

  final AppDatabase database;
  final RecipeRepository recipes;
  final EquipmentRepository equipment;
  final LabelRepository labels;
  final ShoppingRepository shopping;
  final PlanningRepository planning;
  final PhotoStore photos;
  final BackupService backups;

  /// Le dossier de l'application (base, photos, verrou de synchro).
  final Directory root;

  /// L'horloge qui date les modifications (voir [HybridClock]).
  final HybridClock clock;

  /// Durée de conservation dans la corbeille.
  static const trashRetention = Duration(days: 30);

  static const _schemaVersionKey = 'db_schema_version';

  /// La base attend une migration (nouvelle version de l'appli pas encore
  /// ouverte) : c'est à l'appli de la faire, pas à la synchro en arrière-plan.
  static bool migrationPending(SharedPreferences prefs) =>
      (prefs.getInt(_schemaVersionKey) ?? 0) < AppDatabase.latestSchemaVersion;

  /// Ouvre la base dans [root] (dossier de documents de l'app) ; [cache] sert
  /// aux fichiers temporaires de SQLite.
  ///
  /// Si le schéma de la base va changer, une copie du fichier est faite avant
  /// l'ouverture : en cas de migration ratée, rien n'est perdu.
  static Future<AppServices> open({
    required Directory root,
    required Directory cache,
    required SharedPreferences prefs,
    required String appVersion,
    QueryExecutor? executor,
  }) async {
    final dbFile = File(p.join(root.path, 'recettes.sqlite'));
    final backupsDir = Directory(p.join(root.path, 'sauvegardes'));

    final previous = prefs.getInt(_schemaVersionKey);
    if (executor == null &&
        await dbFile.exists() &&
        (previous ?? 1) < AppDatabase.latestSchemaVersion) {
      await backupsDir.create(recursive: true);
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      await dbFile.copy(
        p.join(
          backupsDir.path,
          'avant-migration-v${previous ?? 1}-$stamp.sqlite',
        ),
      );
    }

    final database = AppDatabase(
      executor ??
          driftDatabase(
            name: 'recettes',
            native: DriftNativeOptions(
              databasePath: () async => dbFile.path,
              tempDirectoryPath: () async => cache.path,
              // L'appli et la synchro en arrière-plan peuvent ouvrir la base en
              // même temps : attendre le verrou plutôt qu'échouer aussitôt.
              setup: (db) => db.execute('PRAGMA busy_timeout = 15000'),
            ),
          ),
    );
    // Les modifications sont datées par l'horloge corrigée de la synchro.
    final clock = await SyncEngine.loadClock(database);
    final recipes = RecipeRepository(database, clock: clock.now);
    final equipment = EquipmentRepository(database, clock: clock.now);
    final labels = LabelRepository(database, clock: clock.now);
    final shopping = ShoppingRepository(database, clock: clock.now);
    final planning = PlanningRepository(database, clock: clock.now);
    final photos = PhotoStore(Directory(p.join(root.path, 'photos')));
    final services = AppServices(
      database: database,
      recipes: recipes,
      equipment: equipment,
      labels: labels,
      shopping: shopping,
      planning: planning,
      photos: photos,
      clock: clock,
      root: root,
      backups: BackupService(
        repository: recipes,
        equipment: equipment,
        labels: labels,
        shopping: shopping,
        planning: planning,
        photos: photos,
        backupsDirectory: backupsDir,
        appVersion: appVersion,
      ),
    );

    // Forces the database to open (and migrate) now, inside main()'s error
    // handling, rather than on the first screen.
    await database.customSelect('SELECT 1').get();
    await equipment.capitalizeNames();
    await prefs.setInt(_schemaVersionKey, AppDatabase.latestSchemaVersion);
    return services;
  }

  /// Vide la corbeille des recettes supprimées depuis plus de 30 jours.
  Future<void> purgeOldTrash() async {
    final unused = await recipes.purgeTrash(
      before: DateTime.now().subtract(trashRetention),
    );
    await photos.deleteAll(unused);
  }
}

final appServicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('Surchargé dans main()'),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => ref.watch(appServicesProvider).recipes,
);

final equipmentRepositoryProvider = Provider<EquipmentRepository>(
  (ref) => ref.watch(appServicesProvider).equipment,
);

final labelRepositoryProvider = Provider<LabelRepository>(
  (ref) => ref.watch(appServicesProvider).labels,
);

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ref.watch(appServicesProvider).shopping,
);

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => ref.watch(appServicesProvider).planning,
);

final photoStoreProvider = Provider<PhotoStore>(
  (ref) => ref.watch(appServicesProvider).photos,
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => ref.watch(appServicesProvider).backups,
);
