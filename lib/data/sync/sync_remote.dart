import 'dart:typed_data';

/// Un changement vu sur le dossier distant : un fichier écrit ou supprimé.
class RemoteChange {
  const RemoteChange(this.path, {this.version = '', this.deleted = false});

  /// Chemin relatif au dossier de synchro (`recipes/<id>.json`…).
  final String path;

  /// Identifie l'état du fichier (empreinte, révision…) : celui que renvoie
  /// [SyncRemote.write] pour nos propres envois, afin de ne pas les relire.
  final String version;
  final bool deleted;
}

/// Ce qui a changé depuis un jeton, et le jeton suivant.
class RemoteChanges {
  const RemoteChanges(this.items, this.token);

  final List<RemoteChange> items;
  final String token;
}

/// Le dossier distant (Google Drive en 0.4). Les chemins sont ceux décrits
/// dans `docs/decisions/0002-…` ; tout est atomique fichier par fichier.
abstract class SyncRemote {
  /// Les changements depuis [token] ; `null` = tout le dossier (première
  /// synchro). Sans rien de nouveau : une liste vide et le même jeton.
  Future<RemoteChanges> changes(String? token);

  Future<Uint8List> read(String path);

  /// Écrit (ou remplace) un fichier et renvoie sa nouvelle version.
  Future<String> write(String path, Uint8List bytes);

  Future<void> delete(String path);
}
