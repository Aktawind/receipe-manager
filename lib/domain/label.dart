import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';

/// Les familles de classement d'une recette.
enum LabelKind {
  /// Entrées, Plats, Desserts… avec des sous-catégories.
  category,

  /// Collections personnalisées (Noël, Goûters de la famille…).
  collection,

  /// Étiquettes (Rapide, Végétarien…).
  tag,

  /// Origine culinaire (Française, Italienne…).
  cuisine,

  /// Petit-déjeuner, déjeuner, goûter, dîner.
  meal,

  /// Noël, anniversaire…
  occasion,

  /// Printemps, été, automne, hiver, toute saison.
  season;

  String get code => name;

  static LabelKind? fromCode(String? code) {
    for (final kind in values) {
      if (kind.name == code) return kind;
    }
    return null;
  }
}

/// Un élément de classement (une catégorie, une étiquette, une saison…).
/// Suppression douce et identifiant stable, comme les recettes.
@immutable
class Label {
  const Label({
    required this.id,
    required this.kind,
    required this.name,
    this.parentId,
    this.icon = '',
    this.color = '',
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final LabelKind kind;
  final String name;

  /// Catégorie parente (seules les catégories ont des sous-catégories).
  final String? parentId;

  /// Clé d'icône et de couleur, résolues par l'interface (voir
  /// `label_style.dart`) : la couleur vient toujours du thème.
  final String icon;
  final String color;

  /// Rang dans la liste de sa famille.
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Label copyWith({
    String? name,
    ValueGetter<String?>? parentId,
    String? icon,
    String? color,
    int? position,
    DateTime? updatedAt,
    ValueGetter<DateTime?>? deletedAt,
  }) => Label(
    id: id,
    kind: kind,
    name: name ?? this.name,
    parentId: parentId != null ? parentId() : this.parentId,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    position: position ?? this.position,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  /// Nom propre : espaces normalisés, première lettre en majuscule.
  static String cleanName(String name) =>
      capitalizeFirst(name.replaceAll(RegExp(r'\s+'), ' '));

  /// Clé de comparaison d'un nom : sans casse, sans accents, au singulier
  /// (« Gâteaux » et « gâteau » sont le même nom).
  static String keyOf(String name) {
    final words = normalizeForSearch(name)
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);
    return words
        .map(
          (w) => w.length > 3 && (w.endsWith('s') || w.endsWith('x'))
              ? w.substring(0, w.length - 1)
              : w,
        )
        .join(' ');
  }

  /// Identifiant déterministe : la même catégorie, étiquette ou saison a le
  /// même identifiant sur tous les appareils et à chaque import.
  static String idFor(LabelKind kind, String name, {String? parentId}) =>
      const Uuid().v5(
        Namespace.url.value,
        'recettes:label:${kind.code}:${parentId ?? ''}:${keyOf(name)}',
      );
}
