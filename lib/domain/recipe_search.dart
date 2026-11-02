import '../core/format/text_search.dart';
import 'recipe.dart';

/// Où un mot de la recherche a été trouvé dans une recette.
enum SearchField {
  title(10),
  ingredients(4),
  about(2),
  steps(1),
  notes(1);

  const SearchField(this.weight);

  /// Importance du champ dans le classement.
  final int weight;
}

/// Une recette trouvée, avec son score (plus haut = plus pertinente).
class SearchHit {
  const SearchHit(this.recipeId, this.score, this.fields);

  final String recipeId;
  final int score;

  /// Les champs où au moins un mot a été trouvé.
  final Set<SearchField> fields;
}

/// Recherche dans le texte des recettes : titre, ingrédients, préparation,
/// notes, description et source.
///
/// - insensible aux accents, à la casse et au pluriel (« tomate » trouve
///   « tomates ») ;
/// - le début d'un mot suffit (« choc » trouve « chocolat ») : on peut chercher
///   en tapant ;
/// - tolère une faute de frappe (« chocolta », « bicarbonnate ») à partir de
///   quatre lettres ;
/// - tous les mots de la recherche doivent se retrouver (dans n'importe quel
///   ordre) ;
/// - un mot du titre pèse plus qu'un mot des ingrédients, qui pèse plus qu'un
///   mot de la préparation.
class RecipeSearchIndex {
  RecipeSearchIndex(Iterable<Recipe> recipes)
    : _docs = [
        for (final recipe in recipes)
          if (!recipe.isDeleted) _Doc.of(recipe),
      ];

  final List<_Doc> _docs;

  int get length => _docs.length;

  /// Les recettes qui répondent à [query], les plus pertinentes d'abord (à
  /// égalité, par titre). Une recherche vide ne renvoie rien.
  List<SearchHit> search(String query) {
    final words = queryWords(query);
    if (words.isEmpty) return const [];
    final hits = <SearchHit>[];
    for (final doc in _docs) {
      var total = 0;
      final fields = <SearchField>{};
      var all = true;
      for (final word in words) {
        final found = doc.best(word);
        if (found == null) {
          all = false;
          break;
        }
        total += found.score;
        fields.add(found.field);
      }
      if (all) hits.add(SearchHit(doc.id, total, fields));
    }
    final titles = {for (final d in _docs) d.id: d.sortTitle};
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : titles[a.recipeId]!.compareTo(titles[b.recipeId]!);
    });
    return hits;
  }

  /// Les mots utiles d'une recherche : sans accents, sans les petits mots
  /// (« de », « aux »…) quand il reste autre chose.
  static List<String> queryWords(String query) {
    final all = _tokens(query);
    final useful = [
      for (final w in all)
        if (!_stopWords.contains(w)) w,
    ];
    return useful.isEmpty ? all : useful;
  }

  static const _stopWords = {
    'a',
    'au',
    'aux',
    'de',
    'des',
    'du',
    'en',
    'et',
    'la',
    'le',
    'les',
    'un',
    'une',
    'd',
    'l',
  };

  static List<String> _tokens(String text) => [
    for (final t in normalizeForSearch(text).split(RegExp('[^a-z0-9]+')))
      if (t.isNotEmpty) t,
  ];
}

/// Les briques de la recherche, partagées avec la recherche par ingrédients :
/// mots sans accents, retrait du pluriel, qualité d'une correspondance.
abstract final class SearchText {
  /// Les mots d'un texte, sans accents ni ponctuation.
  static List<String> tokens(String text) => RecipeSearchIndex._tokens(text);

  /// Retire le pluriel (« tomates » → « tomate », « gâteaux » → « gateau »).
  static String stem(String word) => _Doc._stem(word);

  /// Les mots d'un texte, au singulier : de quoi comparer deux textes.
  static Set<String> stems(String text) => {
    for (final t in tokens(text)) stem(t),
  };

  /// 3 = mot entier, 2 = début de mot, 1 = faute de frappe, 0 = absent.
  ///
  /// [minFuzzy] : longueur minimale d'un mot pour tolérer une faute (une
  /// recherche d'ingrédient est plus stricte : « oeuf » n'est pas « boeuf »).
  ///
  /// [sameInitial] : une faute de frappe ne change pas la première lettre
  /// (évite de confondre deux mots proches).
  static int quality(
    String stem,
    Set<String> tokens, {
    int minFuzzy = 4,
    bool sameInitial = false,
  }) =>
      _Doc._quality(stem, tokens, minFuzzy: minFuzzy, sameInitial: sameInitial);
}

class _Match {
  const _Match(this.score, this.field);

  final int score;
  final SearchField field;
}

class _Doc {
  _Doc({required this.id, required this.sortTitle, required this.tokens});

  factory _Doc.of(Recipe recipe) {
    final tokens = <SearchField, Set<String>>{
      for (final field in SearchField.values) field: <String>{},
    };
    void add(SearchField field, String text) {
      for (final t in RecipeSearchIndex._tokens(text)) {
        tokens[field]!.add(_stem(t));
      }
    }

    add(SearchField.title, recipe.title);
    add(SearchField.about, '${recipe.description} ${recipe.source}');
    add(SearchField.notes, recipe.notes);
    for (final line in recipe.ingredients) {
      add(SearchField.ingredients, '${line.name} ${line.substitutes}');
    }
    for (final step in recipe.steps) {
      add(SearchField.steps, '${step.title} ${step.text}');
    }
    return _Doc(
      id: recipe.id,
      sortTitle: normalizeForSearch(recipe.title),
      tokens: tokens,
    );
  }

  final String id;
  final String sortTitle;
  final Map<SearchField, Set<String>> tokens;

  /// La meilleure façon dont [word] se retrouve dans la recette, ou `null`.
  _Match? best(String word) {
    final stem = _stem(word);
    _Match? best;
    for (final field in SearchField.values) {
      final quality = _quality(stem, tokens[field]!);
      if (quality == 0) continue;
      final score = quality * field.weight;
      if (best == null || score > best.score) best = _Match(score, field);
    }
    return best;
  }

  /// 3 = mot entier, 2 = début de mot, 1 = faute de frappe, 0 = absent.
  static int _quality(
    String stem,
    Set<String> tokens, {
    int minFuzzy = 4,
    bool sameInitial = false,
  }) {
    if (tokens.contains(stem)) return 3;
    var prefix = false;
    for (final t in tokens) {
      if (stem.length >= 2 && t.startsWith(stem)) {
        prefix = true;
        break;
      }
    }
    if (prefix) return 2;
    if (stem.length < minFuzzy) return 0;
    final allowed = stem.length >= 8 ? 2 : 1;
    for (final t in tokens) {
      if ((t.length - stem.length).abs() > allowed) continue;
      if (sameInitial && t.isNotEmpty && t[0] != stem[0]) continue;
      if (_distance(stem, t, allowed) <= allowed) return 1;
    }
    return 0;
  }

  /// Retire le pluriel (« tomates » → « tomate », « gâteaux » → « gateau »).
  static String _stem(String word) {
    if (word.length > 3 && (word.endsWith('s') || word.endsWith('x'))) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Distance de Damerau-Levenshtein (insertion, suppression, remplacement,
  /// échange de deux lettres), abandonnée au-delà de [limit].
  static int _distance(String a, String b, int limit) {
    final n = a.length, m = b.length;
    var previous2 = List<int>.filled(m + 1, 0);
    var previous = List<int>.generate(m + 1, (j) => j);
    for (var i = 1; i <= n; i++) {
      final current = List<int>.filled(m + 1, 0)..[0] = i;
      var rowMin = i;
      for (var j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var value = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          final swap = previous2[j - 2] + 1;
          if (swap < value) value = swap;
        }
        current[j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > limit) return limit + 1;
      previous2 = previous;
      previous = current;
    }
    return previous[m];
  }
}
