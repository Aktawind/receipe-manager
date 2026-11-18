import 'dart:io';

/// Un verrou très simple (un fichier daté) pour qu'une seule synchro travaille
/// à la fois : l'application et la tâche d'arrière-plan sont deux « processus
/// légers » qui partagent la même base et le même dossier Drive.
///
/// Le verrou est rafraîchi à chaque fichier lu ou envoyé ; un verrou qui n'a
/// pas bougé depuis [staleAfter] (tâche d'arrière-plan arrêtée par Android,
/// application fermée de force…) est ignoré. Celui qui l'a posé ([owner]) peut
/// toujours le reprendre : une synchro bloquée ne bloque pas la suivante.
class SyncGate {
  SyncGate(
    this.file, {
    this.owner = '',
    DateTime Function()? now,
    this.staleAfter = const Duration(minutes: 3),
  }) : _now = now ?? DateTime.now;

  static const fileName = 'sync.lock';

  final File file;
  final String owner;
  final Duration staleAfter;
  final DateTime Function() _now;

  /// `false` si une autre synchro travaille.
  bool tryAcquire() {
    try {
      if (file.existsSync()) {
        final [stampText, ...rest] = '${file.readAsStringSync()} '.split(' ');
        final stamp = int.tryParse(stampText);
        final heldBy = rest.join(' ').trim();
        if (stamp != null && (owner.isEmpty || heldBy != owner)) {
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
      file.writeAsStringSync(
        '${_now().millisecondsSinceEpoch} $owner',
        flush: true,
      );
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
