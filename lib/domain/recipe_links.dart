import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import 'recipe.dart';

/// Rattache à une recette les recettes qu'elle utilise (pâte, sauce) comme
/// des lignes de sa liste d'ingrédients.
///
/// Une ligne d'ingrédient qui porte déjà le nom de la recette liée devient le
/// lien (elle garde sa quantité) ; sinon une ligne est ajoutée à la fin.
/// Sert à lire les anciennes données, où les liens étaient à part, et
/// l'export Recipe Keeper.
abstract final class RecipeLinks {
  static Recipe attach(
    Recipe recipe,
    Iterable<String> linkedIds,
    String? Function(String id) titleOf,
  ) {
    final lines = [...recipe.ingredients];
    for (final id in linkedIds) {
      if (lines.any((l) => l.linkedRecipeId == id)) continue;
      final title = titleOf(id);
      if (title == null || title.trim().isEmpty) continue;
      final key = normalizeForSearch(title.trim());
      final index = lines.indexWhere(
        (l) =>
            !l.isSection &&
            l.linkedRecipeId == null &&
            normalizeForSearch(l.name.trim()) == key,
      );
      if (index >= 0) {
        final line = lines[index];
        lines[index] = IngredientLine(
          id: line.id,
          name: title.trim(),
          quantity: line.quantity,
          unit: line.unit,
          note: line.note,
          optional: line.optional,
          substitutes: line.substitutes,
          linkedRecipeId: id,
        );
      } else {
        lines.add(
          IngredientLine(
            id: const Uuid().v4(),
            name: title.trim(),
            linkedRecipeId: id,
          ),
        );
      }
    }
    return recipe.copyWith(ingredients: lines);
  }
}
