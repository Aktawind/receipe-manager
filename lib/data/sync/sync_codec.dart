import 'dart:convert';
import 'dart:typed_data';

import '../../domain/equipment.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../backup/backup_format.dart';

/// Les genres d'éléments synchronisés, avec leur dossier distant.
enum SyncKind {
  recipe('recipes'),
  label('labels'),
  equipment('equipment'),
  media('media');

  const SyncKind(this.folder);

  final String folder;

  /// Chemin distant d'un élément. Les photos gardent leur nom (jamais
  /// modifiées : un nouveau fichier a toujours un nouveau nom).
  String path(String id) => this == media ? 'media/$id' : '$folder/$id.json';

  /// Le genre et l'identifiant d'un chemin distant, `null` s'il ne désigne
  /// pas un élément connu (historique, fichiers d'une version plus récente…).
  static (SyncKind, String)? parse(String path) {
    final slash = path.indexOf('/');
    if (slash < 0) return null;
    final folder = path.substring(0, slash);
    final name = path.substring(slash + 1);
    if (name.isEmpty || name.contains('/')) return null;
    for (final kind in values) {
      if (kind.folder != folder) continue;
      if (kind == media) return (kind, name);
      if (!name.endsWith('.json')) return null;
      final id = name.substring(0, name.length - '.json'.length);
      return id.isEmpty ? null : (kind, id);
    }
    return null;
  }
}

/// Un fichier de synchro est un document du même format que les sauvegardes
/// (`docs/FORMAT_EXPORT.md`), avec un seul élément : lisible par un humain et
/// toujours compatible avec les anciennes versions du format.
abstract final class SyncCodec {
  static Uint8List recipe(Recipe recipe) => _bytes(
    BackupFormat.encode(
      [recipe],
      exportedAt: recipe.updatedAt,
      appVersion: 'sync',
    ),
  );

  static Uint8List label(Label label) => _bytes(
    BackupFormat.encode(
      const [],
      labels: [label],
      exportedAt: label.updatedAt,
      appVersion: 'sync',
    ),
  );

  static Uint8List equipment(EquipmentItem item) => _bytes(
    BackupFormat.encode(
      const [],
      equipment: [item],
      exportedAt: item.updatedAt,
      appVersion: 'sync',
    ),
  );

  static Recipe decodeRecipe(Uint8List bytes) {
    final data = _decode(bytes);
    if (data.recipes.length != 1) {
      throw const BackupFormatException(BackupError.invalid, 'recipes');
    }
    return data.recipes.single;
  }

  static Label decodeLabel(Uint8List bytes) {
    final data = _decode(bytes);
    if (data.labels.length != 1) {
      throw const BackupFormatException(BackupError.invalid, 'labels');
    }
    return data.labels.single;
  }

  static EquipmentItem decodeEquipment(Uint8List bytes) {
    final data = _decode(bytes);
    if (data.equipment.length != 1) {
      throw const BackupFormatException(BackupError.invalid, 'equipment');
    }
    return data.equipment.single;
  }

  /// Deux fichiers disent-ils la même chose ? Les dates de création et de
  /// modification et celle de l'export ne comptent pas.
  static bool sameContent(Uint8List a, Uint8List b) =>
      _canonical(a) == _canonical(b);

  static String _canonical(Uint8List bytes) {
    final root = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    root.remove('exportedAt');
    for (final key in const ['recipes', 'labels', 'equipment']) {
      for (final item in (root[key] as List? ?? const [])) {
        (item as Map<String, Object?>)
          ..remove('createdAt')
          ..remove('updatedAt');
      }
    }
    return jsonEncode(root);
  }

  static BackupData _decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const BackupFormatException(BackupError.invalid, 'json');
    }
    return BackupFormat.decode(json);
  }

  static Uint8List _bytes(Map<String, Object?> document) => Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
  );
}
