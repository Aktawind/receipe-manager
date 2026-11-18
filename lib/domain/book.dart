import 'package:meta/meta.dart';

import '../core/format/text_search.dart';

/// Un livre de cuisine de la bibliothèque : ses recettes y renvoient (avec
/// la page).
@immutable
class Book {
  const Book({
    required this.id,
    required this.title,
    this.authors = '',
    this.publisher = '',
    this.year,
    this.isbn = '',
    this.cover,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String title;

  /// Le ou les auteurs, tels qu'écrits (« Christophe Felder, Camille Lesecq »).
  final String authors;
  final String publisher;
  final int? year;

  /// L'ISBN, chiffres seuls (13 ou 10).
  final String isbn;

  /// La photo de la couverture (nom dans le dossier des photos).
  final String? cover;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// La clé de comparaison d'un titre (sans casse, accents ni articles).
  static String keyOf(String title) =>
      normalizeForSearch(title)
          .replaceAll(RegExp(r"^(le|la|les|l'|un|une|des)\s*"), '')
          .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
          .trim();

  Book copyWith({
    String? title,
    String? authors,
    String? publisher,
    int? Function()? year,
    String? isbn,
    String? Function()? cover,
    String? notes,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => Book(
    id: id,
    title: title ?? this.title,
    authors: authors ?? this.authors,
    publisher: publisher ?? this.publisher,
    year: year != null ? year() : this.year,
    isbn: isbn ?? this.isbn,
    cover: cover != null ? cover() : this.cover,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Book &&
      other.id == id &&
      other.title == title &&
      other.authors == authors &&
      other.publisher == publisher &&
      other.year == year &&
      other.isbn == isbn &&
      other.cover == cover &&
      other.notes == notes &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    authors,
    publisher,
    year,
    isbn,
    cover,
    notes,
    createdAt,
    updatedAt,
    deletedAt,
  );
}
