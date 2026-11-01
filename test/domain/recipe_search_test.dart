import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_search.dart';

Recipe recipe(
  String id,
  String title, {
  List<String> ingredients = const [],
  List<String> steps = const [],
  String notes = '',
  String description = '',
  DateTime? deletedAt,
}) => Recipe(
  id: id,
  title: title,
  notes: notes,
  description: description,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deletedAt: deletedAt,
  ingredients: [
    for (final (i, name) in ingredients.indexed)
      IngredientLine(id: '$id-i$i', name: name),
  ],
  steps: [
    for (final (i, text) in steps.indexed)
      RecipeStep(id: '$id-s$i', text: text),
  ],
);

void main() {
  final index = RecipeSearchIndex([
    recipe(
      'tarte',
      'Tarte aux pommes',
      ingredients: ['pommes', 'pâte brisée', 'sucre', 'beurre'],
      steps: [
        'Étaler la pâte et la piquer à la fourchette.',
        'Disposer les pommes en rosace.',
      ],
    ),
    recipe(
      'brownie',
      'Brownie au chocolat',
      ingredients: ['chocolat noir', 'beurre', 'œufs', 'farine', 'sucre'],
      steps: ['Faire fondre le chocolat avec le beurre au bain-marie.'],
      notes: 'Se congèle très bien.',
    ),
    recipe(
      'blinis',
      'Blinis',
      ingredients: ['yaourt nature', 'farine', 'bicarbonate', 'œufs'],
      steps: ['Mélanger le yaourt et les œufs, ajouter la farine.'],
    ),
    recipe(
      'gateau',
      'Gâteau au yaourt',
      ingredients: ['yaourt nature', 'farine', 'sucre', 'huile', 'œufs'],
      description: 'Le gâteau des enfants',
    ),
    recipe(
      'gratin',
      'Gratin dauphinois',
      ingredients: ['pommes de terre', 'crème'],
    ),
    recipe('ancienne', 'Pommes rôties', deletedAt: DateTime.utc(2026, 2)),
  ]);

  List<String> ids(String query) => [
    for (final hit in index.search(query)) hit.recipeId,
  ];

  test('sans accents ni casse, au pluriel près', () {
    expect(ids('gateau'), contains('gateau'));
    expect(ids('GÂTEAUX'), contains('gateau'));
    expect(ids('oeuf'), containsAll(['brownie', 'blinis', 'gateau']));
    expect(ids('pomme'), containsAll(['tarte', 'gratin']));
  });

  test('le début d’un mot suffit : on cherche en tapant', () {
    expect(ids('choc'), ['brownie']);
    expect(ids('bicar'), ['blinis']);
  });

  test('tolère une faute de frappe, pas deux lettres de moins', () {
    expect(ids('chocolta'), ['brownie'], reason: 'lettres échangées');
    expect(ids('bicarbonnate'), ['blinis'], reason: 'lettre en trop');
    expect(ids('yahourt'), containsAll(['blinis', 'gateau']));
    expect(ids('bru'), isEmpty, reason: 'trop court pour une faute');
    expect(ids('xyzzy'), isEmpty);
  });

  test('tous les mots doivent se retrouver, dans n’importe quel ordre', () {
    expect(ids('farine yaourt'), containsAll(['blinis', 'gateau']));
    expect(ids('yaourt chocolat'), isEmpty);
    expect(ids('beurre pommes'), ['tarte']);
  });

  test('les petits mots ne comptent pas : « tarte aux pommes »', () {
    expect(ids('tarte aux pommes').first, 'tarte');
    expect(ids('gâteau au yaourt').first, 'gateau');
    // Une recherche faite seulement de petits mots ne plante pas.
    expect(index.search('de la'), isA<List<SearchHit>>());
  });

  test('le titre l’emporte sur les ingrédients, qui l’emportent sur la préparation', () {
    // « pommes » : titre de la tarte, ingrédient du gratin (« pommes de terre »).
    expect(ids('pommes').take(2), ['tarte', 'gratin']);
    // « chocolat » : titre du brownie.
    final hits = index.search('chocolat');
    expect(hits.single.fields, contains(SearchField.title));
    // « fourchette » n'est que dans la préparation de la tarte.
    expect(index.search('fourchette').single.fields, {SearchField.steps});
  });

  test('cherche dans les notes, la description et la préparation', () {
    expect(ids('congèle'), ['brownie']);
    expect(ids('enfants'), ['gateau']);
    expect(ids('bain-marie'), ['brownie']);
    expect(ids('rosace'), ['tarte']);
  });

  test('les recettes à la corbeille sont ignorées, une recherche vide ne renvoie rien', () {
    expect(ids('rôties'), isEmpty);
    expect(index.length, 5);
    expect(index.search(''), isEmpty);
    expect(index.search('   '), isEmpty);
    expect(index.search('---'), isEmpty);
  });

  test('assez rapide sur une grosse bibliothèque', () {
    final big = RecipeSearchIndex([
      for (var i = 0; i < 1000; i++)
        recipe(
          'r$i',
          'Recette numéro $i',
          ingredients: ['farine', 'sucre', 'ingrédient$i', 'beurre salé'],
          steps: ['Mélanger tout ce qu’il faut, puis cuire ${i % 60} minutes.'],
        ),
    ]);
    final watch = Stopwatch()..start();
    big.search('beurre sale cuire');
    big.search('fraine');
    expect(watch.elapsedMilliseconds, lessThan(1500));
  });
}
