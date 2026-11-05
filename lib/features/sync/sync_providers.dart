import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart'
    show Table, TableInfo, TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path/path.dart' as p;

import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../data/sync/background_sync.dart';
import '../../data/sync/drive_auth.dart';
import '../../data/sync/drive_backup.dart';
import '../../data/sync/drive_remote.dart';
import '../../data/sync/sync_engine.dart';
import '../../data/sync/sync_gate.dart';
import '../../data/sync/sync_prefs.dart';
import '../../data/sync/sync_remote.dart';
import '../../data/sync/sync_settings_store.dart';

/// Nom du dossier Drive : celui des versions de test est à part, pour ne
/// jamais mélanger les essais avec les vraies recettes.
final syncFolderNameProvider = Provider<String>((ref) => 'Recettes');

final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth());

/// La synchro quand l'application est fermée (remplacée dans les tests).
final backgroundSchedulerProvider = Provider<BackgroundScheduler>(
  (ref) => const WorkmanagerScheduler(),
);

typedef SyncRemoteFactory = DriveFolder Function(
  DriveAuth auth,
  String folderName,
  DriveCache cache,
);

/// Fabrique du dossier distant (remplacée dans les tests).
final syncRemoteFactoryProvider = Provider<SyncRemoteFactory>(
  (ref) =>
      (auth, folderName, cache) =>
          DriveRemote(auth: auth, folderName: folderName, cache: cache),
);

enum SyncPhase { off, idle, syncing, error, signInRequired }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.off,
    this.email,
    this.name = '',
    this.photoUrl,
    this.lastSync,
    this.error,
    this.lastConflicts = 0,
    this.connectFailed = false,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.lastUploaded = 0,
    this.lastDownloaded = 0,
    this.backupFrequency = BackupFrequency.daily,
    this.lastBackup,
    this.backupBusy = false,
    this.backupError,
  });

  final SyncPhase phase;
  final String? email;
  final String name;
  final String? photoUrl;
  final DateTime? lastSync;

  /// Détail technique de la dernière erreur (affiché en petit).
  final String? error;

  /// Conflits résolus à la dernière synchro (la version écartée est gardée).
  final int lastConflicts;

  /// La dernière tentative de connexion n'a pas abouti.
  final bool connectFailed;

  /// Avancement de la synchro en cours : fichiers traités / connus.
  final int progressDone;
  final int progressTotal;

  /// Ce que la dernière synchro réussie a envoyé et reçu.
  final int lastUploaded;
  final int lastDownloaded;

  /// Sauvegarde automatique dans Drive : fréquence, dernière faite, état.
  final BackupFrequency backupFrequency;
  final DateTime? lastBackup;
  final bool backupBusy;
  final String? backupError;

  bool get enabled => phase != SyncPhase.off;

  SyncState copyWith({
    SyncPhase? phase,
    String? email,
    String? name,
    String? photoUrl,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    int? lastConflicts,
    bool? connectFailed,
    int? progressDone,
    int? progressTotal,
    int? lastUploaded,
    int? lastDownloaded,
    BackupFrequency? backupFrequency,
    DateTime? lastBackup,
    bool? backupBusy,
    String? backupError,
    bool clearBackupError = false,
  }) => SyncState(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    name: name ?? this.name,
    photoUrl: photoUrl ?? this.photoUrl,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : error ?? this.error,
    lastConflicts: lastConflicts ?? this.lastConflicts,
    connectFailed: connectFailed ?? this.connectFailed,
    progressDone: progressDone ?? this.progressDone,
    progressTotal: progressTotal ?? this.progressTotal,
    lastUploaded: lastUploaded ?? this.lastUploaded,
    lastDownloaded: lastDownloaded ?? this.lastDownloaded,
    backupFrequency: backupFrequency ?? this.backupFrequency,
    lastBackup: lastBackup ?? this.lastBackup,
    backupBusy: backupBusy ?? this.backupBusy,
    backupError: clearBackupError ? null : backupError ?? this.backupError,
  );
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Pilote la synchronisation : à l'ouverture, après chaque modification (avec
/// un petit délai pour regrouper les changements), au retour dans l'app, et à
/// la demande.
class SyncController extends Notifier<SyncState> {
  static const _afterChange = Duration(seconds: 5);
  static const _atStartup = Duration(seconds: 2);
  static const _minBetweenResumes = Duration(seconds: 30);

  StreamSubscription<Set<TableUpdate>>? _watch;
  Timer? _timer;
  SyncEngine? _engine;
  DriveFolder? _folder;
  bool _running = false;
  bool _again = false;
  int _runId = 0;
  DateTime _lastProgress = DateTime.now();

  @override
  SyncState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _watch?.cancel();
    });
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(SyncPrefs.enabled) != true) return const SyncState();
    // Appareil déjà connecté avant que le compte soit mémorisé.
    final connected = prefs.getString(SyncPrefs.email);
    if (connected != null && prefs.getString(SyncPrefs.account) == null) {
      unawaited(prefs.setString(SyncPrefs.account, connected));
    }
    _listen();
    _schedule(_atStartup);
    unawaited(ref.read(backgroundSchedulerProvider).schedule());
    return SyncState(
      phase: SyncPhase.idle,
      email: prefs.getString(SyncPrefs.email),
      name: prefs.getString(SyncPrefs.name) ?? '',
      photoUrl: prefs.getString(SyncPrefs.photo),
      backupFrequency: BackupFrequency.fromName(
        prefs.getString(SyncPrefs.backupFrequency),
      ),
      lastBackup: DateTime.tryParse(
        prefs.getString(SyncPrefs.lastBackup) ?? '',
      ),
    );
  }

  /// Connexion à Google, puis première synchro.
  Future<void> connect() async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final account = await ref.read(driveAuthProvider).signIn();
      // Nouvelle synchro, sans rien garder d'une requête bloquée.
      _abandonRun();
      // Même compte qu'avant : on reprend où on en était (seul le changé
      // circule). Un autre compte a un autre dossier : on relit tout.
      if (prefs.getString(SyncPrefs.account) != account.email) {
        await _engineFor().reset();
        await prefs.setString(SyncPrefs.account, account.email);
      }
      await prefs.setBool(SyncPrefs.enabled, true);
      await prefs.setString(SyncPrefs.email, account.email);
      await prefs.setString(SyncPrefs.name, account.name);
      final photo = account.photoUrl;
      if (photo == null) {
        await prefs.remove(SyncPrefs.photo);
      } else {
        await prefs.setString(SyncPrefs.photo, photo);
      }
      state = SyncState(
        phase: SyncPhase.idle,
        email: account.email,
        name: account.name,
        photoUrl: photo,
      );
      _listen();
      unawaited(ref.read(backgroundSchedulerProvider).schedule());
      unawaited(syncNow());
    } on GoogleSignInException catch (error) {
      // Annuler n'est pas une erreur, mais Android renvoie aussi « annulé »
      // quand Google bloque l'accès : on affiche donc toujours le détail.
      debugPrint('Connexion Google : ${error.code.name} ${error.description}');
      state = state.copyWith(
        phase: state.enabled ? state.phase : SyncPhase.off,
        error: '${error.code.name} ${error.description ?? ''}'.trim(),
        connectFailed: true,
      );
    } on Object catch (error) {
      state = state.copyWith(error: '$error', connectFailed: true);
    }
  }

  /// Oublie la synchro en cours et le moteur : ils repartiront à neuf.
  void _abandonRun() {
    _runId++;
    _running = false;
    _again = false;
    _engine = null;
    _folder = null;
  }

  /// Se déconnecte de Google. Les recettes de l'appareil ne sont pas touchées,
  /// ni le dossier Drive.
  Future<void> disconnect() async {
    final prefs = ref.read(sharedPreferencesProvider);
    _timer?.cancel();
    _abandonRun();
    unawaited(ref.read(backgroundSchedulerProvider).cancel());
    await _watch?.cancel();
    _watch = null;
    await prefs.setBool(SyncPrefs.enabled, false);
    await prefs.remove(SyncPrefs.email);
    await prefs.remove(SyncPrefs.name);
    await prefs.remove(SyncPrefs.photo);
    try {
      await ref.read(driveAuthProvider).signOut();
    } on Object {
      // Déjà déconnecté : sans importance.
    }
    state = const SyncState();
  }

  /// Une synchro sans nouvelles depuis aussi longtemps est considérée comme
  /// bloquée (réseau coupé en plein transfert…) : on repart de zéro.
  static const _stuckAfter = Duration(minutes: 3);

  /// Synchronise maintenant (bouton, ou déclenchement automatique).
  Future<void> syncNow() async {
    if (!state.enabled) return;
    if (_running) {
      if (DateTime.now().difference(_lastProgress) < _stuckAfter) {
        _again = true;
        return;
      }
      debugPrint('Synchro : la précédente ne répond plus, on repart.');
    }
    // La tâche d'arrière-plan travaille peut-être déjà : on repasse après.
    final gate = SyncGate(
      File(p.join(ref.read(appServicesProvider).root.path, SyncGate.fileName)),
    );
    if (!gate.tryAcquire()) {
      _schedule(const Duration(seconds: 30));
      return;
    }
    final run = ++_runId;
    _running = true;
    _lastProgress = DateTime.now();
    _timer?.cancel();
    state = state.copyWith(
      phase: SyncPhase.syncing,
      clearError: true,
      progressDone: 0,
      progressTotal: 0,
    );
    try {
      final report = await _engineFor().sync(
        onProgress: (done, total) {
          if (run != _runId) return;
          _lastProgress = DateTime.now();
          gate.touch();
          // Pas à chaque fichier : l'écran n'a pas besoin d'être plus vif.
          if (done == total || done % 5 == 0 || total - done < 5) {
            state = state.copyWith(progressDone: done, progressTotal: total);
          }
        },
      );
      if (run != _runId) return;
      if (report.ok) {
        state = state.copyWith(
          phase: SyncPhase.idle,
          lastSync: DateTime.now(),
          lastConflicts: report.conflicts.length,
          lastUploaded: report.uploaded + report.deletedRemote,
          lastDownloaded: report.downloaded + report.deletedLocal,
          clearError: true,
        );
        unawaited(_afterSuccess());
      } else {
        final signIn = report.errors.any(
          (e) => e.contains('DriveSignInRequired'),
        );
        state = state.copyWith(
          phase: signIn ? SyncPhase.signInRequired : SyncPhase.error,
          error: report.errors.first,
        );
      }
    } on Object catch (error) {
      if (run == _runId) {
        state = state.copyWith(phase: SyncPhase.error, error: '$error');
      }
    } finally {
      gate.release();
      if (run == _runId) {
        _running = false;
        if (_again) {
          _again = false;
          _schedule(_afterChange);
        }
      }
    }
  }

  /// Au retour dans l'application.
  void onResumed() {
    if (!state.enabled) return;
    // Les synchros faites en arrière-plan ont écrit dans la base : on relit.
    ref.read(appServicesProvider).database.markTablesUpdated(_watched());
    final last = state.lastSync;
    final stuck =
        _running && DateTime.now().difference(_lastProgress) > _stuckAfter;
    if (stuck ||
        (!_running &&
            (last == null ||
                DateTime.now().difference(last) > _minBetweenResumes))) {
      _schedule(const Duration(seconds: 1));
    }
  }

  /// Après une synchro réussie : sauvegarde Drive si elle est due.
  Future<void> _afterSuccess() async {
    final due = state.backupFrequency.isDue(state.lastBackup, DateTime.now());
    if (due) await backupNow();
  }

  List<TableInfo<Table, dynamic>> _watched() {
    final db = ref.read(appServicesProvider).database;
    return [
      db.recipes,
      db.ingredients,
      db.recipeSteps,
      db.recipePhotos,
      db.recipeEquipment,
      db.recipeLabels,
      db.labels,
      db.equipmentItems,
    ];
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  void _listen() {
    _watch?.cancel();
    final db = ref.read(appServicesProvider).database;
    _watch = db.tableUpdates(TableUpdateQuery.onAllTables(_watched())).listen((
      _,
    ) {
      if (state.enabled) _schedule(_afterChange);
    });
  }

  DriveFolder _folderFor() {
    final existing = _folder;
    if (existing != null) return existing;
    final services = ref.read(appServicesProvider);
    return _folder = ref.read(syncRemoteFactoryProvider)(
      ref.read(driveAuthProvider),
      ref.read(syncFolderNameProvider),
      SyncSettingsStore(services.database),
    );
  }

  SyncEngine _engineFor() {
    final existing = _engine;
    if (existing != null) return existing;
    final services = ref.read(appServicesProvider);
    return _engine = SyncEngine(
      database: services.database,
      recipes: services.recipes,
      labels: services.labels,
      equipment: services.equipment,
      shopping: services.shopping,
      photos: services.photos,
      clock: services.clock,
      remote: _folderFor(),
    );
  }

  DriveBackupService _backupService() {
    final services = ref.read(appServicesProvider);
    return DriveBackupService(
      remote: _folderFor(),
      sync: _folderFor(),
      backups: services.backups,
      photos: services.photos,
      clock: services.clock,
    );
  }

  // ------------------------------------------------------------ sauvegardes

  Future<void> setBackupFrequency(BackupFrequency frequency) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(SyncPrefs.backupFrequency, frequency.name);
    state = state.copyWith(backupFrequency: frequency);
  }

  /// Sauvegarde maintenant dans Drive.
  Future<bool> backupNow() async {
    if (!state.enabled || state.backupBusy) return false;
    state = state.copyWith(backupBusy: true, clearBackupError: true);
    try {
      await _backupService().backupNow();
      final now = DateTime.now();
      await ref
          .read(sharedPreferencesProvider)
          .setString(SyncPrefs.lastBackup, now.toUtc().toIso8601String());
      state = state.copyWith(backupBusy: false, lastBackup: now);
      return true;
    } on Object catch (error) {
      state = state.copyWith(backupBusy: false, backupError: '$error');
      return false;
    }
  }

  /// Met le dossier Drive à la corbeille, puis arrête la synchronisation.
  Future<void> deleteDriveData() async {
    await _folderFor().deleteAll();
    // Le dossier n'existe plus : une reconnexion repartira de zéro.
    await _engineFor().reset();
    await ref.read(sharedPreferencesProvider).remove(SyncPrefs.account);
    await disconnect();
  }

  Future<List<RemoteBackup>> listBackups() => _backupService().list();

  /// Restaure une sauvegarde (voir [DriveBackupService.restore]), puis
  /// synchronise pour que les autres appareils suivent.
  Future<RestoreResult> restoreBackup(RemoteBackup backup) async {
    final result = await _backupService().restore(backup);
    ref.read(appServicesProvider).database.markTablesUpdated(_watched());
    unawaited(syncNow());
    return result;
  }
}
