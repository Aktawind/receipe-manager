import 'book.dart';
import 'recipe.dart';

/// Un livre retrouvé dans le champ « Source » des recettes.
typedef SourceBook = ({
  /// Le titre (l'écriture la plus fréquente).
  String title,

  /// Le livre de la bibliothèque qui porte déjà ce titre, s'il existe.
  Book? existing,

  /// Les recettes qui le citent, avec leur page (vide si aucune).
  Map<String, String> pages,
});

/// Retrouve les livres cités dans « Source » (« Le grand livre de la
/// pâtisserie p. 42 ») : le titre sans la page, regroupé sans tenir compte
/// des majuscules, accents et articles ; les adresses web sont laissées de
/// côté, comme les recettes déjà rattachées à un livre.
abstract final class BookSources {
  static final _page = RegExp(
    r'[\s,;:(\-–—]*\b(?:p|pp|pg|page|pages)\b\.?\s*(\d+(?:\s*[-–à]\s*\d+)?)\s*\)?\s*$',
    caseSensitive: false,
  );
  static final _web = RegExp(r'https?://|www\.|\.(com|fr|org|net)\b');

  /// Le titre et la page d'une source (« Mon livre, p. 12 » → (« Mon
  /// livre », « 12 »)) ; `null` pour une adresse web ou une source vide.
  static (String, String)? parse(String source) {
    final text = source.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty || _web.hasMatch(text.toLowerCase())) return null;
    final match = _page.firstMatch(text);
    final page = match == null
        ? ''
        : match.group(1)!.replaceAll(RegExp(r'\s*[-–à]\s*'), '-');
    final title = (match == null ? text : text.substring(0, match.start))
        .replaceAll(RegExp(r'[\s,;:(\-–—]+$'), '')
        .trim();
    if (title.isEmpty || Book.keyOf(title).isEmpty) return null;
    return (title, page);
  }

  static List<SourceBook> find(List<Recipe> recipes, List<Book> books) {
    final byKey =
        <String, ({Map<String, int> spellings, Map<String, String> pages})>{};
    for (final r in recipes) {
      if (r.isDeleted || r.bookId != null) continue;
      final parsed = parse(r.source);
      if (parsed == null) continue;
      final (title, page) = parsed;
      final group = byKey[Book.keyOf(title)] ??= (spellings: {}, pages: {});
      group.spellings[title] = (group.spellings[title] ?? 0) + 1;
      group.pages[r.id] = page;
    }
    final existing = {
      for (final b in books)
        if (!b.isDeleted) Book.keyOf(b.title): b,
    };
    final found = [
      for (final MapEntry(:key, :value) in byKey.entries)
        (
          title:
              (value.spellings.entries.toList()
                    // À égalité : la plus complète (article, accents).
                    ..sort(
                      (a, b) => b.value != a.value
                          ? b.value.compareTo(a.value)
                          : b.key.length.compareTo(a.key.length),
                    ))
                  .first
                  .key,
          existing: existing[key],
          pages: value.pages,
        ),
    ];
    // Les plus cités d'abord.
    found.sort((a, b) => b.pages.length.compareTo(a.pages.length));
    return found;
  }
}
