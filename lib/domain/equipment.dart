import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';

/// Un matériel de la liste commune (moule à cake, robot, fouet…). Les recettes
/// y font référence par identifiant : un matériel n'a qu'un nom, ce qui permet
/// de filtrer et de trier dessus.
@immutable
class EquipmentItem {
  const EquipmentItem({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  EquipmentItem copyWith({
    String? name,
    DateTime? updatedAt,
    ValueGetter<DateTime?>? deletedAt,
  }) => EquipmentItem(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  /// Clé de comparaison : « Moule à Cake » et « moule à cake » sont le même.
  static String keyOf(String name) =>
      normalizeForSearch(name.trim().replaceAll(RegExp(r'\s+'), ' '));

  /// Identifiant déterministe pour un nom : les anciennes données (matériel
  /// saisi en texte) donnent le même identifiant sur tous les appareils.
  static String idForName(String name) =>
      const Uuid().v5(Namespace.url.value, 'recettes:equipment:${keyOf(name)}');
}
