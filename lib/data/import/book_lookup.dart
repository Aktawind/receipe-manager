import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Ce qu'une base de livres sait d'un ISBN.
typedef BookInfo = ({
  String title,
  String authors,
  String publisher,
  int? year,
  String isbn,

  /// L'adresse de la couverture, si la base en a une.
  String? coverUrl,
});

/// Retrouve un livre d'après son ISBN dans des bases publiques : Google Books
/// d'abord (bien fourni en livres français), puis Open Library pour ce qui
/// manque (et une couverture plus grande). Rien d'autre que l'ISBN n'est
/// envoyé.
class BookLookup {
  BookLookup({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// Le livre, ou `null` si aucune base ne le connaît. Une erreur de réseau
  /// est levée telle quelle (pas de réseau, délai dépassé).
  Future<BookInfo?> find(String isbn) async {
    final google = await _google(isbn);
    final open = await _openLibrary(isbn);
    if (google == null && open == null) return null;
    String pick(String? a, String? b) =>
        (a != null && a.isNotEmpty) ? a : (b ?? '');
    return (
      title: pick(google?.title, open?.title),
      authors: pick(google?.authors, open?.authors),
      publisher: pick(google?.publisher, open?.publisher),
      year: google?.year ?? open?.year,
      isbn: isbn,
      coverUrl: open?.coverUrl ?? google?.coverUrl,
    );
  }

  /// Télécharge la couverture ; `null` si elle n'est pas une image.
  Future<List<int>?> download(String url) async {
    final response = await _client.get(Uri.parse(url)).timeout(_timeout);
    final type = response.headers['content-type'] ?? '';
    if (response.statusCode != 200 || !type.startsWith('image/')) return null;
    // Une image de quelques octets : pas de vraie couverture.
    if (response.bodyBytes.length < 1000) return null;
    return response.bodyBytes;
  }

  Future<BookInfo?> _google(String isbn) async {
    final response = await _client
        .get(
          Uri.https('www.googleapis.com', '/books/v1/volumes', {
            'q': 'isbn:$isbn',
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final items = json is Map ? json['items'] : null;
    if (items is! List || items.isEmpty) return null;
    final info = (items.first as Map)['volumeInfo'];
    if (info is! Map) return null;
    final title = [
      if (info['title'] is String) info['title'] as String,
      if (info['subtitle'] is String) info['subtitle'] as String,
    ].join(' : ');
    final links = info['imageLinks'];
    final thumbnail = links is Map ? links['thumbnail'] : null;
    return (
      title: title,
      authors: [
        for (final a
            in (info['authors'] is List ? info['authors'] as List : []))
          if (a is String) a,
      ].join(', '),
      publisher: info['publisher'] is String ? info['publisher'] as String : '',
      year: _year(info['publishedDate']),
      isbn: isbn,
      coverUrl: thumbnail is String
          ? thumbnail
                .replaceFirst('http://', 'https://')
                .replaceAll('&edge=curl', '')
          : null,
    );
  }

  Future<BookInfo?> _openLibrary(String isbn) async {
    final key = 'ISBN:$isbn';
    final response = await _client
        .get(
          Uri.https('openlibrary.org', '/api/books', {
            'bibkeys': key,
            'format': 'json',
            'jscmd': 'data',
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    final book = json is Map ? json[key] : null;
    if (book is! Map) return null;
    String names(Object? list) => [
      for (final a in (list is List ? list : const []))
        if (a is Map && a['name'] is String) a['name'] as String,
    ].join(', ');
    final title = [
      if (book['title'] is String) book['title'] as String,
      if (book['subtitle'] is String) book['subtitle'] as String,
    ].join(' : ');
    final cover = book['cover'];
    return (
      title: title,
      authors: names(book['authors']),
      publisher: names(book['publishers']),
      year: _year(book['publish_date']),
      isbn: isbn,
      coverUrl: cover is Map
          ? (cover['large'] ?? cover['medium']) as String?
          : null,
    );
  }

  /// « 2014-10-01 », « 2014 », « oct. 2014 » → 2014.
  static int? _year(Object? date) {
    if (date is! String) return null;
    final match = RegExp(r'\b(1[5-9]\d\d|20\d\d)\b').firstMatch(date);
    return match == null ? null : int.parse(match.group(1)!);
  }
}

final bookLookupProvider = Provider<BookLookup>((ref) => BookLookup());
