import 'package:uuid/uuid.dart';

import 'shopping.dart';

/// Les rayons fournis au départ, dans l'ordre d'un parcours habituel. Les
/// identifiants sont déterministes : les mêmes sur tous les appareils.
abstract final class DefaultAisles {
  static const names = [
    'Fruits et légumes',
    'Boulangerie',
    'Boucherie',
    'Charcuterie',
    'Poissonnerie',
    'Traiteur',
    'Produits frais',
    'Épicerie salée',
    'Épicerie sucrée',
    'Boissons',
    'Surgelés',
    'Entretien',
    'Hygiène',
    'Autres',
  ];

  static String idFor(String name) =>
      const Uuid().v5(Namespace.url.value, 'recettes:aisle:$name');

  static List<Aisle> build(DateTime now) => [
    for (final (position, name) in names.indexed)
      Aisle(
        id: idFor(name),
        name: name,
        position: position,
        createdAt: now,
        updatedAt: now,
      ),
  ];
}
