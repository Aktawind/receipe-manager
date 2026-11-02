import 'recipe.dart';
import 'recipe_search.dart';

/// Reconnaît un ingrédient dans les lignes d'une recette, pour chercher par
/// ingrédient.
///
/// Un ingrédient cherché (« farine », « chocolat noir ») est présent dans une
/// ligne (« 200 g de farine de blé ») quand chacun de ses mots s'y retrouve :
/// mot entier, début de mot (« choc ») ou avec une faute de frappe.
abstract final class IngredientMatch {
  static bool _covers(Set<String> lineWords, String term) {
    final words = SearchText.tokens(term).map(SearchText.stem).toList();
    if (words.isEmpty) return false;
    return words.every(
      (w) =>
          SearchText.quality(w, lineWords, minFuzzy: 6, sameInitial: true) > 0,
    );
  }

  static Iterable<IngredientLine> _lines(Recipe recipe) =>
      recipe.ingredients.where((l) => !l.isSection && l.name.trim().isNotEmpty);

  /// La recette contient-elle cet ingrédient ?
  static bool has(Recipe recipe, String term) =>
      _lines(recipe).any((l) => _covers(SearchText.stems(l.name), term));
}
