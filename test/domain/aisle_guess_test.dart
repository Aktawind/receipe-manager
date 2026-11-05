import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/aisle_guess.dart';
import 'package:recettes/domain/default_aisles.dart';
import 'package:recettes/domain/shopping.dart';

String? aisleName(String product) {
  final id = AisleGuess.fromDictionary(product);
  if (id == null) return null;
  return DefaultAisles.names.firstWhere((n) => DefaultAisles.idFor(n) == id);
}

void main() {
  test('le dictionnaire range les produits courants', () {
    final expected = {
      'Pommes de terre': 'Fruits et légumes',
      'Tomates cerises': 'Fruits et légumes',
      'Oignons rouges': 'Fruits et légumes',
      'Beurre': 'Produits frais',
      'Œufs': 'Produits frais',
      'Crème fraîche épaisse': 'Produits frais',
      'Lardons fumés': 'Charcuterie',
      'Jambons': 'Charcuterie',
      'Filet de saumon': 'Poissonnerie',
      'Saumon fumé': 'Traiteur',
      'Pâte brisée': 'Traiteur',
      'Farine': 'Épicerie sucrée',
      'Sucre glace': 'Épicerie sucrée',
      'Spaghetti': 'Épicerie salée',
      'Huile d\'olive': 'Épicerie salée',
      'Jus d\'orange': 'Boissons',
      'Eau gazeuse': 'Boissons',
      'Escalopes de dinde': 'Boucherie',
      'Steak haché': 'Boucherie',
      'Liquide vaisselle': 'Entretien',
      'Dentifrice': 'Hygiène',
      'Glace vanille': 'Surgelés',
      'Baguette': 'Boulangerie',
    };
    for (final MapEntry(key: product, value: aisle) in expected.entries) {
      expect(aisleName(product), aisle, reason: product);
    }
    expect(aisleName('Sauce soja'), 'Épicerie salée');
    expect(aisleName('Kombucha'), isNull);
  });

  test('choix manuel > mémoire du produit > dictionnaire', () {
    final epicerie = DefaultAisles.idFor('Épicerie salée');
    final frais = DefaultAisles.idFor('Produits frais');
    final all = {for (final n in DefaultAisles.names) DefaultAisles.idFor(n)};
    const kombucha = ShoppingItem(id: 'k', name: 'Kombucha');
    expect(AisleGuess.of(kombucha, memory: const {}, aisles: all), isNull);
    expect(
      AisleGuess.of(
        kombucha,
        memory: {'kombucha': DefaultAisles.idFor('Boissons')},
        aisles: all,
      ),
      DefaultAisles.idFor('Boissons'),
    );
    // « Sauces soja » : la mémoire vaut pour le singulier comme le pluriel.
    expect(
      AisleGuess.of(
        const ShoppingItem(id: 's', name: 'Sauces soja'),
        memory: {'sauce soja': frais},
        aisles: all,
      ),
      frais,
    );
    expect(
      AisleGuess.of(
        const ShoppingItem(id: 'b', name: 'Beurre', aisleId: 'x'),
        memory: const {},
        aisles: {...all, 'x'},
      ),
      'x',
    );
    // Un rayon supprimé n'est plus proposé.
    expect(
      AisleGuess.of(
        const ShoppingItem(id: 'p', name: 'Pâtes'),
        memory: const {},
        aisles: all.difference({epicerie}),
      ),
      isNull,
    );
  });
}
