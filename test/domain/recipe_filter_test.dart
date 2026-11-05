import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_filter.dart';

final _date = DateTime(2026, 1, 1);

Recipe recipe(
  String id, {
  bool favorite = false,
  int? prep,
  int? cook,
  int? rating,
  RecipeStatus? status,
  DateTime? viewed,
  DateTime? created,
}) => Recipe(
  id: id,
  title: id,
  isFavorite: favorite,
  prepMinutes: prep,
  cookMinutes: cook,
  rating: rating,
  status: status,
  lastViewedAt: viewed,
  createdAt: created ?? _date,
  updatedAt: _date,
);

Label label(String id, LabelKind kind, {String? parent}) => Label(
  id: id,
  kind: kind,
  name: id,
  parentId: parent,
  createdAt: _date,
  updatedAt: _date,
);

List<String> ids(List<Recipe> recipes) => [for (final r in recipes) r.id];

void main() {
  final recipes = [
    recipe('Crêpes', favorite: true, prep: 10, cook: 20, rating: 4),
    recipe('Gratin', prep: 20, cook: 60, status: RecipeStatus.toTest),
    recipe('Salade', prep: 10, rating: 5, viewed: DateTime(2026, 3, 1)),
    recipe('Tarte', rating: 3, viewed: DateTime(2026, 2, 1)),
  ];

  test('sans filtre : toutes, par titre', () {
    expect(ids(const RecipeFilter().apply(recipes)), [
      'Crêpes',
      'Gratin',
      'Salade',
      'Tarte',
    ]);
  });

  test('favorites, statut, durée maximale', () {
    expect(
      ids(const RecipeFilter(quick: QuickFilter.favorites).apply(recipes)),
      ['Crêpes'],
    );
    expect(
      ids(const RecipeFilter(statuses: {RecipeStatus.toTest}).apply(recipes)),
      ['Gratin'],
    );
    // Sans durée renseignée, une recette ne répond pas à une limite.
    expect(
      ids(const RecipeFilter(times: TimeLimits(total: 30)).apply(recipes)),
      ['Crêpes', 'Salade'],
    );
  });

  test('catégorie avec ses sous-catégories, collections cumulées', () {
    final labels = [
      label('dessert', LabelKind.category),
      label('tarte', LabelKind.category, parent: 'dessert'),
      label('veggie', LabelKind.collection),
      label('paques', LabelKind.collection),
    ];
    final links = {
      'Tarte': {'tarte': 0, 'veggie': 0, 'paques': 1},
      'Crêpes': {'dessert': 0, 'veggie': 1},
      'Gratin': {'veggie': 2},
    };
    expect(
      ids(
        const RecipeFilter(labelIds: {'dessert'})
            .apply(recipes, labels: labels, links: links),
      ),
      ['Crêpes', 'Tarte'],
    );
    expect(
      ids(
        const RecipeFilter(labelIds: {'veggie', 'paques'})
            .apply(recipes, labels: labels, links: links),
      ),
      ['Tarte'],
    );
    // L'ordre choisi dans la seule collection filtrée.
    expect(
      ids(
        const RecipeFilter(
          labelIds: {'veggie'},
          sort: RecipeSort.manual,
        ).apply(recipes, labels: labels, links: links, collection: labels[2]),
      ),
      ['Tarte', 'Crêpes', 'Gratin'],
    );
  });

  test('tris : sans valeur à la fin, puis par titre', () {
    expect(ids(const RecipeFilter(sort: RecipeSort.rating).apply(recipes)), [
      'Salade',
      'Crêpes',
      'Tarte',
      'Gratin',
    ]);
    expect(ids(const RecipeFilter(sort: RecipeSort.duration).apply(recipes)), [
      'Salade',
      'Crêpes',
      'Gratin',
      'Tarte',
    ]);
    expect(ids(const RecipeFilter(sort: RecipeSort.viewed).apply(recipes)), [
      'Salade',
      'Tarte',
      'Crêpes',
      'Gratin',
    ]);
    expect(ids(const RecipeFilter(sort: RecipeSort.status).apply(recipes)), [
      'Gratin',
      'Crêpes',
      'Salade',
      'Tarte',
    ]);
  });

  test('une recherche classe par pertinence et écarte le reste', () {
    expect(
      ids(
        const RecipeFilter(sort: RecipeSort.rating)
            .apply(recipes, relevance: {'Tarte': 0, 'Gratin': 1}),
      ),
      ['Tarte', 'Gratin'],
    );
  });
}
