import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/book.dart';
import 'package:recettes/domain/book_sources.dart';
import 'package:recettes/domain/recipe.dart';

Recipe _recipe(String id, String source, {String? bookId}) => Recipe(
  id: id,
  title: id,
  source: source,
  bookId: bookId,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  test('le titre et la page, quelle que soit l’écriture', () {
    expect(BookSources.parse('Le grand livre de la pâtisserie p. 42'), (
      'Le grand livre de la pâtisserie',
      '42',
    ));
    expect(BookSources.parse('Simplissime, page 12'), ('Simplissime', '12'));
    expect(BookSources.parse('Ottolenghi - Plenty (pp. 120-121)'), (
      'Ottolenghi - Plenty',
      '120-121',
    ));
    expect(BookSources.parse('Je sais cuisiner p 7'), (
      'Je sais cuisiner',
      '7',
    ));
    expect(BookSources.parse('Livre de mamie'), ('Livre de mamie', ''));
  });

  test('les adresses web et les sources vides sont laissées de côté', () {
    expect(
      BookSources.parse('https://www.marmiton.org/recettes/quiche'),
      isNull,
    );
    expect(BookSources.parse('www.cuisineaz.com'), isNull);
    expect(BookSources.parse('marmiton.org'), isNull);
    expect(BookSources.parse('   '), isNull);
    expect(BookSources.parse('p. 12'), isNull);
  });

  test('regroupés malgré les majuscules, accents et articles', () {
    final found = BookSources.find(
      [
        _recipe('a', 'Le Grand Livre de la Pâtisserie p. 42'),
        _recipe('b', 'grand livre de la patisserie, page 50'),
        _recipe('c', 'Le grand livre de la pâtisserie p. 12'),
        _recipe('d', 'Simplissime'),
        _recipe('e', 'https://marmiton.org/x'),
        // Déjà reliée : on n'y touche pas.
        _recipe('f', 'Simplissime p. 3', bookId: 'b1'),
      ],
      [
        Book(
          id: 'b1',
          title: 'Simplissime',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    );
    expect(found, hasLength(2));
    final pastry = found.first;
    expect(pastry.pages, {'a': '42', 'b': '50', 'c': '12'});
    expect(pastry.existing, isNull);
    expect(found.last.title, 'Simplissime');
    expect(found.last.existing?.id, 'b1');
    expect(found.last.pages, {'d': ''});
  });
}
