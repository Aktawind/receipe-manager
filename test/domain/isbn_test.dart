import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/isbn.dart';

void main() {
  test('un ISBN-13 lu au dos du livre', () {
    expect(Isbn.normalize('9782012386716'), '9782012386716');
    expect(Isbn.normalize('978-2-01-238671-6'), '9782012386716');
    expect(Isbn.normalize(' 978 2 01 238671 6 '), '9782012386716');
  });

  test('un ISBN-10 est converti en ISBN-13', () {
    expect(Isbn.normalize('2-01-238671-7'), '9782012386716');
    // La clé « X ».
    expect(Isbn.normalize('080442957X'), '9780804429573');
  });

  test('ce qui n’est pas un livre est refusé', () {
    // Mauvaise clé de contrôle.
    expect(Isbn.normalize('9782012386713'), isNull);
    // Un code-barres de produit (EAN-13 valide, mais pas 978/979).
    expect(Isbn.normalize('3017620422003'), isNull);
    expect(Isbn.normalize(''), isNull);
    expect(Isbn.normalize('12345'), isNull);
  });
}
