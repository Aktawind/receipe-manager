import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../app_services.dart';
import 'drive_auth.dart';
import 'drive_backup.dart';
import 'drive_remote.dart';
import 'sync_engine.dart';
import 'sync_gate.dart';
import 'sync_prefs.dart';
import 'sync_settings_store.dart';

/// Programme (ou annule) la synchro quand l'application est fermée.
abstract class BackgroundScheduler {
  Future<void> schedule();

  Future<void> cancel();
}

/// Pas d'arrière-plan (tests).
class NoBackgroundScheduler implements BackgroundScheduler {
  const NoBackgroundScheduler();

  @override
  Future<void> schedule() async {}

  @override
  Future<void> cancel() async {}
}

/// Android WorkManager : une tâche périodique, quand le réseau est là.
class WorkmanagerScheduler implements BackgroundScheduler {
  const WorkmanagerScheduler();

  static const _uniqueName = 'recettes-sync';

  /// Android ne descend pas sous 15 minutes ; une heure suffit pour retrouver
  /// sur un appareil ce qui a été modifié sur l'autre.
  static const every = Duration(hours: 1);

  @override
  Future<void> schedule() async {
    try {
      await Workmanager().initialize(backgroundDispatcher);
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        'sync',
        frequency: every,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
      );
    } on Object catch (error) {
      // La synchro à l'ouverture et après modification reste là.
      debugPrint('Synchro en arrière-plan indisponible : $error');
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
    } on Object catch (error) {
      debugPrint('Synchro en arrière-plan : annulation impossible : $error');
    }
  }
}

/// Point d'entrée de la tâche d'arrière-plan (appelé par Android).
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      return await runBackgroundSync();
    } on Object catch (error, stack) {
      debugPrint('Synchro en arrière-plan : $error\n$stack');
      return false; // Android réessaiera plus tard
    }
  });
}

/// Une synchro complète sans écran : ouvre la base, synchronise, sauvegarde si
/// la sauvegarde est due, referme. `true` = pas la peine de réessayer tout de
/// suite.
Future<bool> runBackgroundSync() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(SyncPrefs.enabled) != true) return true;
  // Nouvelle version installée : la migration se fera à l'ouverture de
  // l'appli (deux migrations en même temps se bloquent).
  if (AppServices.migrationPending(prefs)) return true;

  final root = await getApplicationDocumentsDirectory();
  final gate = SyncGate(File(p.join(root.path, SyncGate.fileName)));
  // L'application, ou une autre tâche, est déjà en train de synchroniser.
  if (!gate.tryAcquire()) return true;

  AppServices? services;
  try {
    final info = await PackageInfo.fromPlatform();
    services = await AppServices.open(
      root: root,
      cache: await getTemporaryDirectory(),
      prefs: prefs,
      appVersion: info.version,
    );
    final folder = DriveRemote(
      auth: GoogleDriveAuth(),
      folderName: info.packageName.endsWith('.dev')
          ? 'Recettes (test)'
          : 'Recettes',
      cache: SyncSettingsStore(services.database),
    );
    final engine = SyncEngine(
      database: services.database,
      recipes: services.recipes,
      labels: services.labels,
      equipment: services.equipment,
      shopping: services.shopping,
      planning: services.planning,
      photos: services.photos,
      clock: services.clock,
      remote: folder,
    );
    final report = await engine.sync(onProgress: (_, _) => gate.touch());
    if (!report.ok) {
      // Connexion à refaire : inutile d'insister depuis l'arrière-plan.
      return report.errors.any((e) => e.contains('DriveSignInRequired'));
    }
    await prefs.setString(
      SyncPrefs.lastSync,
      DateTime.now().toUtc().toIso8601String(),
    );

    final frequency = BackupFrequency.fromName(
      prefs.getString(SyncPrefs.backupFrequency),
    );
    final last = DateTime.tryParse(prefs.getString(SyncPrefs.lastBackup) ?? '');
    if (frequency.isDue(last, DateTime.now())) {
      await DriveBackupService(
        remote: folder,
        sync: folder,
        backups: services.backups,
        photos: services.photos,
        clock: services.clock,
      ).backupNow();
      await prefs.setString(
        SyncPrefs.lastBackup,
        DateTime.now().toUtc().toIso8601String(),
      );
    }
    return true;
  } finally {
    await services?.database.close();
    gate.release();
  }
}
