import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recettes/data/import/book_lookup.dart';

http.Response _json(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  const isbn = '9782012386716';

  test('Google Books et Open Library se complètent', () async {
    final asked = <String>[];
    final lookup = BookLookup(
      client: MockClient((request) async {
        asked.add(request.url.host);
        if (request.url.host == 'www.googleapis.com') {
          expect(request.url.queryParameters['q'], 'isbn:$isbn');
          return _json({
            'items': [
              {
                'volumeInfo': {
                  'title': 'Le grand livre de la pâtisserie',
                  'authors': ['Christophe Felder', 'Camille Lesecq'],
                  'publishedDate': '2014-10-01',
                  'imageLinks': {
                    'thumbnail':
                        'http://books.google.com/books/content?id=x&edge=curl',
                  },
                },
              },
            ],
          });
        }
        return _json({
          'ISBN:$isbn': {
            'title': 'Grand livre de la pâtisserie',
            'publishers': [
              {'name': 'Hachette Pratique'},
            ],
            'publish_date': 'oct. 2014',
            'cover': {'large': 'https://covers.openlibrary.org/b/id/1-L.jpg'},
          },
        });
      }),
    );
    final info = (await lookup.find(isbn))!;
    expect(asked, ['www.googleapis.com', 'openlibrary.org']);
    expect(info.title, 'Le grand livre de la pâtisserie');
    expect(info.authors, 'Christophe Felder, Camille Lesecq');
    // Ce que Google n'a pas : chez Open Library.
    expect(info.publisher, 'Hachette Pratique');
    expect(info.year, 2014);
    // La grande couverture d'Open Library d'abord.
    expect(info.coverUrl, 'https://covers.openlibrary.org/b/id/1-L.jpg');
  });

  test('un livre inconnu des deux bases', () async {
    final lookup = BookLookup(
      client: MockClient(
        (request) async => request.url.host == 'openlibrary.org'
            ? _json(<String, Object>{})
            : _json({'totalItems': 0}),
      ),
    );
    expect(await lookup.find(isbn), isNull);
  });

  test(
    'seulement chez Google : couverture en https, sans effet de page',
    () async {
      final lookup = BookLookup(
        client: MockClient(
          (request) async => request.url.host == 'openlibrary.org'
              ? http.Response('erreur', 500)
              : _json({
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
        ),
      );
      final info = (await lookup.find(isbn))!;
      expect(
        info.title,
        'Simplissime : Le livre de cuisine le + facile du monde',
      );
      expect(info.authors, '');
      expect(info.year, 2015);
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
          _ => http.Response(
            '<html>',
            200,
            headers: {'content-type': 'text/html'},
          ),
        },
      ),
    );
    expect(await lookup.download('https://x.org/ok.jpg'), image);
    expect(await lookup.download('https://x.org/tiny.gif'), isNull);
    expect(await lookup.download('https://x.org/page'), isNull);
  });
}
