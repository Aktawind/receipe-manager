import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/logging/error_log.dart';

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

/// Retrouve un livre d'après son ISBN dans des bases publiques, interrogées en
/// même temps : Google Books, le catalogue de la BnF (tous les livres publiés
/// en France, sans clé ni quota) et Open Library (couvertures). Une base qui ne
/// répond pas n'empêche pas les autres : Google Books sans clé refuse souvent
/// (« quota dépassé »). Rien d'autre que l'ISBN n'est envoyé.
class BookLookup {
  BookLookup({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 12);

  /// Le livre, ou `null` si aucune base ne le connaît. Si aucune base n'a pu
  /// répondre (pas de réseau, délai dépassé), la première erreur est levée.
  Future<BookInfo?> find(String isbn) async {
    final sources = <(String, Future<BookInfo?> Function(String))>[
      ('Google Books', _google),
      ('BnF', _bnf),
      ('Open Library', _openLibrary),
    ];
    final errors = <Object>[];
    final found = await Future.wait([
      for (final (name, source) in sources)
        source(isbn).then<BookInfo?>(
          (info) => info,
          onError: (Object error, StackTrace stack) {
            errors.add(error);
            ErrorLog.current.add('Recherche du livre ($name)', error, stack);
            return null;
          },
        ),
    ]);
    final known = [
      for (final info in found)
        if (info != null && info.title.isNotEmpty) info,
    ];
    if (known.isEmpty) {
      if (errors.length == sources.length) throw errors.first;
      return null;
    }
    String pick(String Function(BookInfo) field) => known
        .map(field)
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final [google, bnf, open] = found;
    return (
      title: pick((b) => b.title),
      authors: pick((b) => b.authors),
      publisher: pick((b) => b.publisher),
      year: known.map((b) => b.year).nonNulls.firstOrNull,
      isbn: isbn,
      // La grande couverture d'Open Library d'abord ; sinon celle de Google,
      // sinon Open Library par l'ISBN (absente : le téléchargement échoue).
      coverUrl:
          open?.coverUrl ??
          google?.coverUrl ??
          bnf?.coverUrl ??
          'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg?default=false',
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

  /// Le catalogue général de la BnF (SRU, notice en Dublin Core) :
  /// « Titre : sous-titre / Auteur », « Nom, Prénom (1961-....). Auteur du
  /// texte », « Éditeur (Ville) ».
  Future<BookInfo?> _bnf(String isbn) async {
    final response = await _client
        .get(
          Uri.https('catalogue.bnf.fr', '/api/SRU', {
            'version': '1.2',
            'operation': 'searchRetrieve',
            'query': 'bib.isbn adj "$isbn"',
            'recordSchema': 'dublincore',
            'maximumRecords': '1',
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final record = RegExp(r'<oai_dc:dc[\s\S]*?</oai_dc:dc>')
        .firstMatch(utf8.decode(response.bodyBytes))
        ?.group(0);
    if (record == null) return null;
    List<String> all(String tag) => [
      for (final m in RegExp(
        '<dc:$tag(?:\\s[^>]*)?>([\\s\\S]*?)</dc:$tag>',
      ).allMatches(record))
        _xmlText(m.group(1)!),
    ];
    final title = (all('title').firstOrNull ?? '')
        .split(' / ')
        .first
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .trim();
    return (
      title: title,
      authors: [
        for (final creator in all('creator'))
          if (_person(creator) case final name when name.isNotEmpty) name,
      ].join(', '),
      publisher: (all('publisher').firstOrNull ?? '')
          .replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '')
          .trim(),
      year: _year(all('date').firstOrNull),
      isbn: isbn,
      coverUrl: null,
    );
  }

  /// « Mallet, Jean-François (1961-....). Auteur du texte » → « Jean-François
  /// Mallet ».
  static String _person(String text) {
    final name = text.split(RegExp(r'\s*\(|\.\s')).first.trim();
    final parts = name.split(', ');
    return parts.length == 2 ? '${parts[1]} ${parts[0]}' : name;
  }

  static String _xmlText(String text) => text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// « 2014-10-01 », « 2014 », « oct. 2014 » → 2014.
  static int? _year(Object? date) {
    if (date is! String) return null;
    final match = RegExp(r'\b(1[5-9]\d\d|20\d\d)\b').firstMatch(date);
    return match == null ? null : int.parse(match.group(1)!);
  }
}

final bookLookupProvider = Provider<BookLookup>((ref) => BookLookup());
