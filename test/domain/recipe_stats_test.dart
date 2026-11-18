import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/planning.dart';
import 'package:recettes/domain/recipe.dart';
import 'package:recettes/domain/recipe_stats.dart';

final _date = DateTime(2026, 11, 2);

Label label(String id, LabelKind kind, {String? parent, int position = 0}) =>
    Label(
      id: id,
      kind: kind,
      name: id,
      parentId: parent,
      position: position,
      createdAt: _date,
      updatedAt: _date,
    );

Recipe recipe(
  String id, {
  String ingredients = '',
  int? prep,
  double? rating,
  RecipeStatus? status,
  bool favorite = false,
}) => Recipe(
  id: id,
  title: id,
  prepMinutes: prep,
  rating: rating,
  status: status,
  isFavorite: favorite,
  ingredients: IngredientText.parseList(ingredients),
  createdAt: _date,
  updatedAt: _date,
);

PlannedMeal meal(String recipeId, DateTime day, {String? leftoverOf}) =>
    PlannedMeal(
      id: '$recipeId-${day.day}-${leftoverOf ?? ''}',
      day: day,
      slotId: 'diner',
      recipeId: recipeId,
      recipeTitle: recipeId,
      leftoverOf: leftoverOf,
      createdAt: _date,
      updatedAt: _date,
    );

void main() {
  test(
    'chiffres, catégories (sous-catégories comprises), saisons, planning',
    () {
      final now = DateTime(2026, 11, 15, 12);
      final stats = RecipeStats.compute(
        recipes: [
          recipe(
            'quiche',
            ingredients: '3 œufs\nsel\n200 g de lardons',
            prep: 20,
          ),
          recipe(
            'crêpes',
            ingredients: '4 oeufs\n250 g de farine',
            prep: 40,
            rating: 5,
            favorite: true,
          ),
          recipe('cake', ingredients: '2 œufs\n200 g de farine', rating: 3),
          recipe('soupe', status: RecipeStatus.toTest),
        ],
        labels: [
          label('Plats', LabelKind.category),
          label('Desserts', LabelKind.category, position: 1),
          label('Gâteaux', LabelKind.category, parent: 'Desserts'),
          label('Hiver', LabelKind.season),
        ],
        links: {
          'quiche': ['Plats', 'Hiver'],
          'crêpes': ['Desserts'],
          'cake': ['Gâteaux'],
        },
        meals: [
          meal('quiche', DateTime(2026, 11, 10)),
          meal('quiche', DateTime(2026, 11, 12)),
          meal('quiche', DateTime(2026, 11, 13), leftoverOf: 'x'),
          meal('crêpes', DateTime(2026, 9, 2)),
        ],
        now: now,
      );
      expect(stats.total, 4);
      expect(stats.favorites, 1);
      expect(stats.averageMinutes, 30);
      // Les restes ne comptent pas ; les crêpes (septembre) sont hors des 30 j.
      expect(stats.plannedLast30, 2);
      expect(
        [for (final e in stats.mostPlanned) (e.recipe.id, e.count)],
        [('quiche', 2), ('crêpes', 1)],
      );
      expect(stats.neverPlanned, 2);
      // Le cake (Gâteaux) compte dans Desserts.
      expect(stats.categories, [
        (name: 'Desserts', count: 2),
        (name: 'Plats', count: 1),
        (name: null, count: 1),
      ]);
      expect(stats.seasons, [
        (name: 'Hiver', count: 1),
        (name: null, count: 3),
      ]);
      expect([for (final r in stats.bestRated) r.id], ['crêpes', 'cake']);
      // Œufs (œ ou oe, singulier ou pluriel) dans 3 recettes, farine dans 2 ;
      // le sel et un ingrédient d'une seule recette ne sont pas listés.
      expect(stats.ingredients.first.count, 3);
      expect(stats.ingredients[1], (name: 'Farine', count: 2));
      expect(stats.ingredients, hasLength(2));
      expect(
        [for (final s in stats.statuses) (s.status, s.count)],
        [(RecipeStatus.toTest, 1), (null, 3)],
      );
    },
  );
}
