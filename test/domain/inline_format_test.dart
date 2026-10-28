import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/inline_format.dart';

void main() {
  const f = FormattedSpan.new;

  test('texte simple', () {
    expect(InlineFormat.parse('Mélanger.'), [f('Mélanger.')]);
    expect(InlineFormat.parse(''), isEmpty);
  });

  test('gras et italique', () {
    expect(InlineFormat.parse('Cuire **10 minutes** à feu *doux*.'), [
      f('Cuire '),
      f('10 minutes', bold: true),
      f(' à feu '),
      f('doux', italic: true),
      f('.'),
    ]);
  });

  test('italique dans du gras', () {
    expect(InlineFormat.parse('**très *fin***'), [
      f('très ', bold: true),
      f('fin', bold: true, italic: true),
    ]);
  });

  test('un marqueur sans fermeture ou collé à des espaces reste du texte', () {
    for (final text in ['**oubli', '2 * 3 * 4', 'a * b', '*', '**']) {
      expect(InlineFormat.plain(text), text, reason: text);
    }
  });

  test('plain enlève les marqueurs', () {
    expect(
      InlineFormat.plain('Ajouter **100 g** de *sucre*'),
      'Ajouter 100 g de sucre',
    );
  });
}
