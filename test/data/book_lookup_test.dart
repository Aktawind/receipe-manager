import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recettes/data/import/book_lookup.dart';

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _xml(String body) => http.Response.bytes(
  utf8.encode(body),
  200,
  headers: {'content-type': 'text/xml; charset=utf-8'},
);

/// Google Books sans clé : la réponse qu'il donne le plus souvent.
final _quota = http.Response(
  '{"error": {"code": 429, "message": "Quota exceeded for quota metric '
  "'Queries' and limit 'Queries per day'\"}}",
  429,
);

/// Une notice du catalogue de la BnF (SRU, Dublin Core), comme il la renvoie.
const _bnfRecord = '''<?xml version="1.0" encoding="UTF-8"?>
<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/">
  <srw:version>1.2</srw:version>
  <srw:numberOfRecords>1</srw:numberOfRecords>
  <srw:records><srw:record>
    <srw:recordSchema>dc</srw:recordSchema>
    <srw:recordData>
      <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:identifier>https://catalogue.bnf.fr/ark:/12148/cb44470036x</dc:identifier>
        <dc:title>Simplissime : le livre de cuisine le + facile du monde / Jean-François Mallet</dc:title>
        <dc:creator>Mallet, Jean-François (1961-....). Auteur du texte</dc:creator>
        <dc:creator>Durand, Marie. Photographe</dc:creator>
        <dc:publisher>Hachette pratique (Vanves)</dc:publisher>
        <dc:date>2015</dc:date>
        <dc:format>1 vol. (319 p.) : ill. en coul., couv. ill. en coul. ; 24 cm</dc:format>
        <dc:identifier>ISBN 9782012384583</dc:identifier>
        <dc:language>fre</dc:language>
        <dc:type xml:lang="fre">texte imprimé</dc:type>
      </oai_dc:dc>
    </srw:recordData>
  </srw:record></srw:records>
</srw:searchRetrieveResponse>''';

const _bnfNone = '''<?xml version="1.0" encoding="UTF-8"?>
<srw:searchRetrieveResponse xmlns:srw="http://www.loc.gov/zing/srw/">
  <srw:version>1.2</srw:version>
  <srw:numberOfRecords>0</srw:numberOfRecords>
  <srw:records/>
</srw:searchRetrieveResponse>''';

BookLookup _lookup({
  required http.Response Function(Uri) google,
  required http.Response Function(Uri) bnf,
  required http.Response Function(Uri) openLibrary,
}) => BookLookup(
  client: MockClient(
    (request) async => switch (request.url.host) {
      'www.googleapis.com' => google(request.url),
      'catalogue.bnf.fr' => bnf(request.url),
      _ => openLibrary(request.url),
    },
  ),
);

void main() {
  const isbn = '9782012384583';

  test('Google Books, BnF et Open Library se complètent', () async {
    final lookup = _lookup(
      google: (url) {
        expect(url.queryParameters['q'], 'isbn:$isbn');
        return _json({
          'items': [
            {
              'volumeInfo': {
                'title': 'Simplissime',
                'authors': ['Jean-François Mallet'],
                'publishedDate': '2015-10-01',
                'imageLinks': {
                  'thumbnail':
                      'http://books.google.com/books/content?id=x&edge=curl',
                },
              },
            },
          ],
        });
      },
      bnf: (url) {
        expect(url.queryParameters['query'], 'bib.isbn adj "$isbn"');
        return _xml(_bnfRecord);
      },
      openLibrary: (_) => _json({
        'ISBN:$isbn': {
          'title': 'Simplissime',
          'cover': {'large': 'https://covers.openlibrary.org/b/id/1-L.jpg'},
        },
      }),
    );
    final info = (await lookup.find(isbn))!;
    expect(info.title, 'Simplissime');
    expect(info.authors, 'Jean-François Mallet');
    // Ce que Google n'a pas : à la BnF.
    expect(info.publisher, 'Hachette pratique');
    expect(info.year, 2015);
    expect(info.coverUrl, 'https://covers.openlibrary.org/b/id/1-L.jpg');
  });

  test(
    'Google refuse (quota) : la BnF suffit, couverture par l’ISBN',
    () async {
      final lookup = _lookup(
        google: (_) => _quota,
        bnf: (_) => _xml(_bnfRecord),
        openLibrary: (_) => _json(<String, Object>{}),
      );
      final info = (await lookup.find(isbn))!;
      expect(
        info.title,
        'Simplissime : le livre de cuisine le + facile du monde',
      );
      expect(info.authors, 'Jean-François Mallet, Marie Durand');
      expect(info.publisher, 'Hachette pratique');
      expect(info.year, 2015);
      expect(
        info.coverUrl,
        'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg?default=false',
      );
    },
  );

  test('une base injoignable n’empêche pas les autres', () async {
    final lookup = _lookup(
      google: (_) => throw const SocketException('Failed host lookup'),
      bnf: (_) => _xml(_bnfRecord),
      openLibrary: (_) => throw const SocketException('Connection reset'),
    );
    expect((await lookup.find(isbn))!.publisher, 'Hachette pratique');
  });

  test('un livre inconnu des trois bases', () async {
    final lookup = _lookup(
      google: (_) => _json({'totalItems': 0}),
      bnf: (_) => _xml(_bnfNone),
      openLibrary: (_) => _json(<String, Object>{}),
    );
    expect(await lookup.find(isbn), isNull);
  });

  test('aucune base joignable : pas de réseau', () async {
    Never offline(Uri _) =>
        throw const SocketException('Network is unreachable');
    final lookup = _lookup(google: offline, bnf: offline, openLibrary: offline);
    await expectLater(lookup.find(isbn), throwsA(isA<SocketException>()));
  });

  test(
    'seulement chez Google : couverture en https, sans effet de page',
    () async {
      final lookup = _lookup(
        google: (_) => _json({
          'items': [
            {
              'volumeInfo': {
                'title': 'Simplissime',
                'subtitle': 'Le livre de cuisine le + facile du monde',
                'publisher': 'Hachette',
                'publishedDate': '2015',
                'imageLinks': {
                  'thumbnail':
                      'http://books.google.com/c?id=y&zoom=1&edge=curl',
                },
              },
            },
          ],
        }),
        bnf: (_) => http.Response('erreur', 500),
        openLibrary: (_) => http.Response('erreur', 500),
      );
      final info = (await lookup.find(isbn))!;
      expect(
        info.title,
        'Simplissime : Le livre de cuisine le + facile du monde',
      );
      expect(info.authors, '');
      expect(info.coverUrl, 'https://books.google.com/c?id=y&zoom=1');
    },
  );

  test('la couverture : seulement une vraie image', () async {
    final image = List.filled(2000, 7);
    final lookup = BookLookup(
      client: MockClient(
        (request) async => switch (request.url.path) {
          '/ok.jpg' => http.Response.bytes(
            image,
            200,
            headers: {'content-type': 'image/jpeg'},
          ),
          '/tiny.gif' => http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/gif'},
          ),
          _ => http.Response('', 404),
        },
      ),
    );
    expect(await lookup.download('https://x.org/ok.jpg'), image);
    expect(await lookup.download('https://x.org/tiny.gif'), isNull);
    expect(await lookup.download('https://x.org/absente.jpg'), isNull);
  });
}
