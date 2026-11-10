import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/shopping.dart';

ShoppingItem item(
  String name, {
  double? quantity,
  String unit = '',
  bool checked = false,
  List<ShoppingSource> sources = const [],
}) => ShoppingItem(
  id: name,
  name: name,
  quantity: quantity,
  unit: unit,
  checked: checked,
  sources: sources,
);

void main() {
  test('même produit au singulier et au pluriel, avec ou sans article', () {
    String key(String s) => ShoppingProducts.keyOf(s);
    expect(key('Jambons'), key('jambon'));
    expect(key('Pommes de terre'), key('pomme de terre'));
    expect(key('Tomates cerises'), key('tomate cerise'));
    expect(key('Œufs'), key('oeuf'));
    expect(key('Choux'), key('chou'));
    expect(key('Poireaux'), key('poireau'));
    expect(key('du beurre'), key('Beurre'));
    expect(key('Noix'), 'noix');
    expect(key('Riz'), 'riz');
    expect(key('Petits pois'), key('petit pois'));
    expect(key('Ananas'), 'ananas');
  });

  test('une ligne saisie', () {
    final a = ShoppingProducts.parse('2 kg de pommes de terre');
    expect((a.name, a.quantity, a.unit), ('Pommes de terre', 2, 'kg'));
    final b = ShoppingProducts.parse('beurre');
    expect((b.name, b.quantity, b.unit), ('Beurre', null, ''));
    final d = ShoppingProducts.parse('Beurre 50 g');
    expect((d.name, d.quantity, d.unit), ('Beurre', 50, 'g'));
    final e = ShoppingProducts.parse('Jambon x 4');
    expect((e.name, e.quantity), ('Jambon', 4));
    expect(ShoppingProducts.parse('du beurre').name, 'Beurre');
    expect(ShoppingProducts.parse('Vitamine B12').name, 'Vitamine B12');
    final c = ShoppingProducts.parse('6 œufs (bio)');
    expect((c.name, c.quantity, c.note), ('Œufs', 6, 'bio'));
  });

  test('une phrase dictée', () {
    expect(
      ShoppingProducts.splitDictation(
        'deux kilos de pommes de terre, du beurre et trois yaourts',
      ),
      ['2 kilos de pommes de terre', 'du beurre', '3 yaourts'],
    );
    expect(
      ShoppingProducts.splitDictation('un demi-litre de lait puis une salade'),
      ['0,5 litre de lait', '1 salade'],
    );
    expect(ShoppingProducts.splitDictation('un peu de persil'), [
      'un peu de persil',
    ]);
    expect(ShoppingProducts.splitDictation('deux cents grammes de farine'), [
      '200 grammes de farine',
    ]);
    final parsed = ShoppingProducts.parse('2 kilos de pommes de terre');
    expect((parsed.quantity, parsed.unit), (2, 'kg'));
  });

  test('additionne les quantités compatibles', () {
    expect(ShoppingProducts.add((200, 'g'), (50, 'g')), (250, 'g'));
    expect(ShoppingProducts.add((1, 'kg'), (500, 'g')), (1.5, 'kg'));
    expect(ShoppingProducts.add((20, 'cl'), (50, 'cl')), (70, 'cl'));
    expect(ShoppingProducts.add((50, 'cl'), (0.75, 'L')), (1.25, 'L'));
    expect(ShoppingProducts.add((2, ''), (3, '')), (5, ''));
    expect(ShoppingProducts.add((2, ''), (1, 'c. à s.')), isNull);
  });

  test('fusionne le même produit, garde les recettes', () {
    const quiche = ShoppingSource(recipeId: 'q', recipeTitle: 'Quiche');
    const crepes = ShoppingSource(recipeId: 'c', recipeTitle: 'Crêpes');
    var items = [
      item('Beurre', quantity: 200, unit: 'g', sources: [quiche]),
    ];
    items = ShoppingProducts.merge(
      items,
      item('beurre', quantity: 50, unit: 'g', sources: [crepes]),
    );
    expect(items, hasLength(1));
    expect((items.single.quantity, items.single.unit), (250, 'g'));
    expect(items.single.amount, '250 g');
    expect(items.single.sources, [quiche, crepes]);

    // Jambon / jambons : un seul produit.
    items = ShoppingProducts.merge([
      item('Jambon', quantity: 4),
    ], item('Jambons', quantity: 2));
    expect(items.single.quantity, 6);

    // Des unités qui ne s'additionnent pas : deux lignes.
    items = ShoppingProducts.merge([
      item('Œufs', quantity: 2),
    ], item('œufs', quantity: 1, unit: 'c. à s.'));
    expect(items, hasLength(2));

    // Déjà dans le panier : on en redemande.
    items = ShoppingProducts.merge([
      item('Lait', quantity: 1, unit: 'L', checked: true),
    ], item('Lait', quantity: 1, unit: 'L'));
    expect(items, hasLength(2));

    // Une quantité d'un côté seulement.
    items = ShoppingProducts.merge([item('Sel')], item('sel', quantity: 1));
    expect(items.single.quantity, 1);
  });

  test('transférer des produits vers une autre liste', () {
    final from = [
      ShoppingProducts.parse('2 tranches de jambon', id: 'j1').copyWith(
        sources: const [
          ShoppingSource(
            recipeId: 'q',
            recipeTitle: 'Quiche',
            quantity: 2,
            unit: 'tranches',
          ),
        ],
      ),
      ShoppingProducts.parse('pain', id: 'p'),
      ShoppingProducts.parse('beurre', id: 'b').copyWith(checked: true),
    ];
    final to = [ShoppingProducts.parse('4 tranches de jambon', id: 'j2')];
    final moved = ShoppingProducts.transfer(from, to, {'j1', 'b'});
    expect([for (final i in moved.from) i.id], ['p']);
    // Le jambon rejoint celui de l'autre liste ; le beurre revient à acheter.
    final ham = moved.to.firstWhere((i) => i.name == 'Jambon');
    expect(ham.amount, '6 tranches');
    expect(ham.sources.single.recipeTitle, 'Quiche');
    final butter = moved.to.firstWhere((i) => i.name == 'Beurre');
    expect(butter.checked, isFalse);
    expect(moved.to, hasLength(2));
  });
}
