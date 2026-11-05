import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import 'ingredient_scaling.dart';
import 'recipe.dart';
import 'shopping.dart';

/// Un ingrédient proposé pour la liste de courses : le produit à ajouter, et
/// s'il est coché d'office (le sel, le poivre, l'eau et les ingrédients
/// facultatifs ne le sont pas).
class ShoppingCandidate {
  const ShoppingCandidate({
    required this.item,
    required this.selected,
    this.viaRecipe,
  });

  final ShoppingItem item;
  final bool selected;

  /// La recette liée (pâte, sauce) d'où vient l'ingrédient, s'il en vient.
  final String? viaRecipe;
}

/// Les ingrédients d'une recette, pour un nombre de personnes, à ajouter aux
/// courses.
abstract final class ShoppingFromRecipes {
  static const _uuid = Uuid();

  /// Les ingrédients de [recipe] multipliés par [factor] (personnes voulues /
  /// personnes de la recette). Une ligne liée à une recette (« 1 pâte
  /// brisée ») est remplacée par les ingrédients de cette recette, en
  /// proportion : « 2 pâtes brisées » pour une recette qui en fait une = deux
  /// fois ses ingrédients. [linked] donne une recette liée par son
  /// identifiant (`null` si elle n'existe plus : la ligne reste telle
  /// quelle). Chaque produit garde [recipe] comme recette d'origine.
  static List<ShoppingCandidate> candidates(
    Recipe recipe,
    double factor, {
    required Recipe? Function(String id) linked,
  }) => _collect(recipe, factor, linked, source: recipe, visiting: {recipe.id});

  static List<ShoppingCandidate> _collect(
    Recipe recipe,
    double factor,
    Recipe? Function(String id) linked, {
    required Recipe source,
    required Set<String> visiting,
    String? via,
  }) {
    final result = <ShoppingCandidate>[];
    for (final line in recipe.ingredients) {
      if (line.isSection || line.isBlank || line.name.trim().isEmpty) continue;
      final target = line.linkedRecipeId == null
          ? null
          : linked(line.linkedRecipeId!);
      // Une recette qui se contient elle-même (par erreur) n'est dépliée
      // qu'une fois.
      if (target != null &&
          !visiting.contains(target.id) &&
          target.ingredients.isNotEmpty) {
        result.addAll(
          _collect(
            target,
            factor * _portion(line, target),
            linked,
            source: source,
            visiting: {...visiting, target.id},
            via: target.title,
          ),
        );
        continue;
      }
      final scaled = IngredientScaling.scaleLine(line, factor);
      final name = capitalizeFirst(line.name.trim());
      result.add(
        ShoppingCandidate(
          item: ShoppingItem(
            id: _uuid.v4(),
            name: name,
            quantity: scaled.quantity,
            unit: line.unit,
            sources: [
              ShoppingSource(
                recipeId: source.id,
                recipeTitle: source.title,
                quantity: scaled.quantity,
                unit: line.unit,
              ),
            ],
          ),
          selected: !line.optional && !isBasic(name),
          viaRecipe: via,
        ),
      );
    }
    return result;
  }

  /// La part de la recette liée qu'une ligne demande : « 2 pâtes brisées »
  /// d'une recette qui en fait une → 2 ; sans quantité comparable (« 150 g de
  /// pâte », recette sans nombre de portions) → la recette entière.
  static double _portion(IngredientLine line, Recipe target) {
    final quantity = line.quantity;
    final servings = target.servings;
    if (quantity == null || servings == null || servings <= 0) return 1;
    if (line.unit.isNotEmpty) return 1;
    return quantity / servings;
  }

  /// Ce qu'on a toujours à la maison : sel, poivre, eau (pas l'eau de fleur
  /// d'oranger ni le poivron).
  static bool isBasic(String name) {
    final key = ShoppingProducts.keyOf(name);
    final first = key.split(' ').first;
    if (first == 'sel' || first == 'poivre') return true;
    if (RegExp(r'^(fleur de sel|gros sel|sel et poivre)\b').hasMatch(key)) {
      return true;
    }
    return RegExp(
      r'^eau( (froide|tiede|chaude|bouillante|du robinet|glacee))?$',
    ).hasMatch(key);
  }
}
