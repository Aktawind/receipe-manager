import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/widgets/linked_text.dart';

void main() {
  test('trouve les liens dans un texte libre', () {
    final links = findLinks(
      'Vu sur https://www.marmiton.org/recettes/tarte, et www.youtube.com/watch?v=abc.',
    );
    expect(links.map((u) => u.toString()), [
      'https://www.marmiton.org/recettes/tarte',
      'https://www.youtube.com/watch?v=abc',
    ]);
  });

  test('un livre et une page ne sont pas des liens', () {
    expect(findLinks('Livre de mamie, p. 12'), isEmpty);
    expect(findLinks(''), isEmpty);
  });

  test('la ponctuation finale n’est pas dans le lien', () {
    expect(
      findLinks('(https://example.org/a)').single.toString(),
      'https://example.org/a',
    );
  });
}
