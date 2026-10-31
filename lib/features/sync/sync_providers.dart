import 'dart:async';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/settings/theme_mode_controller.dart';
import '../../data/app_services.dart';
import '../../data/sync/drive_auth.dart';
import '../../data/sync/drive_remote.dart';
import '../../data/sync/sync_engine.dart';
import '../../data/sync/sync_remote.dart';
import '../../data/sync/sync_settings_store.dart';

/// Nom du dossier Drive : celui des versions de test est à part, pour ne
/// jamais mélanger les essais avec les vraies recettes.
final syncFolderNameProvider = Provider<String>((ref) => 'Recettes');

final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth());

typedef SyncRemoteFactory = SyncRemote Function(
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
    this.lastSync,
    this.error,
    this.lastConflicts = 0,
    this.connectFailed = false,
  });

  final SyncPhase phase;
  final String? email;
  final DateTime? lastSync;

  /// Détail technique de la dernière erreur (affiché en petit).
  final String? error;

  /// Conflits résolus à la dernière synchro (la version écartée est gardée).
  final int lastConflicts;

  /// La dernière tentative de connexion n'a pas abouti.
  final bool connectFailed;

  bool get enabled => phase != SyncPhase.off;

  SyncState copyWith({
    SyncPhase? phase,
    String? email,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
    int? lastConflicts,
    bool? connectFailed,
  }) => SyncState(
    phase: phase ?? this.phase,
    email: email ?? this.email,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : error ?? this.error,
    lastConflicts: lastConflicts ?? this.lastConflicts,
    connectFailed: connectFailed ?? this.connectFailed,
  );
}

final syncControllerProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

/// Pilote la synchronisation : à l'ouverture, après chaque modification (avec
/// un petit délai pour regrouper les changements), au retour dans l'app, et à
/// la demande.
class SyncController extends Notifier<SyncState> {
  static const _enabledKey = 'sync_enabled';
  static const _emailKey = 'sync_email';
  static const _afterChange = Duration(seconds: 5);
  static const _atStartup = Duration(seconds: 2);
  static const _minBetweenResumes = Duration(seconds: 30);

  StreamSubscription<Set<TableUpdate>>? _watch;
  Timer? _timer;
  SyncEngine? _engine;
  bool _running = false;
  bool _again = false;

  @override
  SyncState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _watch?.cancel();
    });
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_enabledKey) != true) return const SyncState();
    _listen();
    _schedule(_atStartup);
    return SyncState(phase: SyncPhase.idle, email: prefs.getString(_emailKey));
  }

  /// Connexion à Google, puis première synchro.
  Future<void> connect() async {
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      final email = await ref.read(driveAuthProvider).signIn();
      // Un autre compte ou une reconnexion : on repart d'une lecture complète.
      await _engineFor().reset();
      await prefs.setBool(_enabledKey, true);
      await prefs.setString(_emailKey, email);
      state = SyncState(phase: SyncPhase.idle, email: email);
      _listen();
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

  /// Se déconnecte de Google. Les recettes de l'appareil ne sont pas touchées,
  /// ni le dossier Drive.
  Future<void> disconnect() async {
    final prefs = ref.read(sharedPreferencesProvider);
    _timer?.cancel();
    await _watch?.cancel();
    _watch = null;
    await prefs.setBool(_enabledKey, false);
    await prefs.remove(_emailKey);
    try {
      await ref.read(driveAuthProvider).signOut();
    } on Object {
      // Déjà déconnecté : sans importance.
    }
    await _engineFor().reset();
    state = const SyncState();
  }

  /// Synchronise maintenant (bouton, ou déclenchement automatique).
  Future<void> syncNow() async {
    if (!state.enabled) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    _timer?.cancel();
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);
    try {
      final report = await _engineFor().sync();
      if (report.ok) {
        state = state.copyWith(
          phase: SyncPhase.idle,
          lastSync: DateTime.now(),
          lastConflicts: report.conflicts.length,
          clearError: true,
        );
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
      state = state.copyWith(phase: SyncPhase.error, error: '$error');
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        _schedule(_afterChange);
      }
    }
  }

  /// Au retour dans l'application.
  void onResumed() {
    if (!state.enabled || _running) return;
    final last = state.lastSync;
    if (last == null || DateTime.now().difference(last) > _minBetweenResumes) {
      _schedule(const Duration(seconds: 1));
    }
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  void _listen() {
    _watch?.cancel();
    final db = ref.read(appServicesProvider).database;
    _watch = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.recipes,
            db.ingredients,
            db.recipeSteps,
            db.recipePhotos,
            db.recipeEquipment,
            db.recipeLabels,
            db.labels,
            db.equipmentItems,
          ]),
        )
        .listen((_) {
          if (state.enabled) _schedule(_afterChange);
        });
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
      photos: services.photos,
      clock: services.clock,
      remote: ref.read(syncRemoteFactoryProvider)(
        ref.read(driveAuthProvider),
        ref.read(syncFolderNameProvider),
        SyncSettingsStore(services.database),
      ),
    );
  }
}
