import 'recipe.dart';
import 'recipe_search.dart';

/// Reconnaît un ingrédient dans les lignes d'une recette : pour chercher par
/// ingrédient, et pour savoir ce qu'il manque à une recette quand on a certains
/// ingrédients sous la main.
///
/// Un ingrédient cherché (« farine », « chocolat noir ») est présent dans une
/// ligne (« 200 g de farine de blé ») quand chacun de ses mots s'y retrouve :
/// mot entier, début de mot (« choc ») ou avec une faute de frappe.
abstract final class IngredientMatch {
  /// Ce qu'on ne demande jamais d'avoir : eau, sel, poivre.
  static const _basics = {'eau', 'sel', 'poivre', 'et', 'fin', 'gros', 'moulu'};

  static bool _covers(Set<String> lineWords, String term) {
    final words = SearchText.tokens(term).map(SearchText.stem).toList();
    if (words.isEmpty) return false;
    return words.every(
      (w) => SearchText.quality(w, lineWords, minFuzzy: 6) > 0,
    );
  }

  static Iterable<IngredientLine> _lines(Recipe recipe) =>
      recipe.ingredients.where((l) => !l.isSection && l.name.trim().isNotEmpty);

  /// La recette contient-elle cet ingrédient ?
  static bool has(Recipe recipe, String term) =>
      _lines(recipe).any((l) => _covers(SearchText.stems(l.name), term));

  /// Les ingrédients de la recette que [available] ne couvre pas, tels qu'ils
  /// sont écrits dans la recette. Un ingrédient facultatif, l'eau, le sel et le
  /// poivre ne comptent pas ; un remplaçant possible (« huile de coco,
  /// margarine ») suffit.
  static List<String> missing(Recipe recipe, Iterable<String> available) {
    final result = <String>[];
    for (final line in _lines(recipe)) {
      if (line.optional) continue;
      final words = SearchText.stems(line.name);
      if (words.every(_basics.contains)) continue;
      final options = [
        line.name,
        for (final s in line.substitutes.split(RegExp('[,;]|\\bou\\b')))
          if (s.trim().isNotEmpty) s,
      ];
      final covered = options.any(
        (option) =>
            available.any((item) => _covers(SearchText.stems(option), item)),
      );
      if (!covered) result.add(line.name.trim());
    }
    return result;
  }
}
