import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/default_aisles.dart';
import 'package:recettes/domain/shopping.dart';
import 'package:recettes/domain/shopping_export.dart';
import 'package:recettes/features/shopping/shopping_pdf.dart';

final _date = DateTime(2026, 11, 5);

ShoppingList list(List<String> lines, {Set<int> checked = const {}}) =>
    ShoppingList(
      id: 'l',
      name: 'Semaine',
      createdAt: _date,
      updatedAt: _date,
      items: [
        for (final (i, line) in lines.indexed)
          ShoppingProducts.parse(
            line,
            id: '$i',
          ).copyWith(checked: checked.contains(i)),
      ],
    );

List<ShoppingSection> sections(ShoppingList l) => ShoppingExport.sections(
  l,
  aisles: DefaultAisles.build(_date),
  memory: const {},
  noAisle: 'Sans rayon',
);

void main() {
  test('le texte partagé : par rayon, sans le panier', () {
    final l = list(
      [
        '2 kg de pommes de terre',
        '250 g de beurre',
        'Kombucha',
        'Lait',
        '6 œufs (bio)',
      ],
      checked: {3},
    );
    expect(ShoppingExport.text(l.name, sections(l)), '''
Semaine

FRUITS ET LÉGUMES
- 2 kg Pommes de terre

PRODUITS FRAIS
- 250 g Beurre
- 6 Œufs (bio)

AUTRES
- Kombucha''');
  });

  test('le PDF tient sur une page A4, même une longue liste', () async {
    final short = sections(list(['Beurre', 'Lait']));
    expect(ShoppingPdf.layoutFor(short), (columns: 2, fontSize: 12.0));

    final long = sections(
      list([
        for (var i = 0; i < 140; i++)
          [
            '$i pommes',
            '$i g de beurre',
            'Pâtes n°$i',
            'Jus d’orange $i',
            'Œufs « bio » $i',
          ][i % 5],
      ]),
    );
    final layout = ShoppingPdf.layoutFor(long);
    expect(layout.columns, 3);
    expect(layout.fontSize, lessThan(12));

    expect(
      ShoppingPdf.safe('Jus d’orange « bio » 🍊…'),
      "Jus d'orange « bio » ...",
    );
    final bytes = await ShoppingPdf.build('Semaine', long);
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text, startsWith('%PDF'));
    expect(RegExp(r'/Type\s*/Page\b').allMatches(text), hasLength(1));
  });
}
