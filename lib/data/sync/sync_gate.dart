import 'dart:io';

/// Un verrou très simple (un fichier daté) pour qu'une seule synchro travaille
/// à la fois : l'application et la tâche d'arrière-plan sont deux « processus
/// légers » qui partagent la même base et le même dossier Drive.
///
/// Le verrou est rafraîchi pendant la synchro ; un verrou qui n'a pas bougé
/// depuis [staleAfter] (application fermée de force…) est ignoré.
class SyncGate {
  SyncGate(
    this.file, {
    DateTime Function()? now,
    this.staleAfter = const Duration(minutes: 10),
  }) : _now = now ?? DateTime.now;

  static const fileName = 'sync.lock';

  final File file;
  final Duration staleAfter;
  final DateTime Function() _now;

  /// `false` si une autre synchro travaille.
  bool tryAcquire() {
    try {
      if (file.existsSync()) {
        final stamp = int.tryParse(file.readAsStringSync());
        if (stamp != null) {
          final held = _now().difference(
            DateTime.fromMillisecondsSinceEpoch(stamp),
          );
          if (held < staleAfter) return false;
        }
      }
      touch();
      return true;
    } on FileSystemException {
      // Pas de verrou possible : mieux vaut synchroniser que ne rien faire.
      return true;
    }
  }

  /// Dit « je travaille toujours ».
  void touch() {
    try {
      file.writeAsStringSync('${_now().millisecondsSinceEpoch}', flush: true);
    } on FileSystemException {
      // Sans importance.
    }
  }

  void release() {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Sans importance.
    }
  }
}
