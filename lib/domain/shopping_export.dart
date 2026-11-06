import 'aisle_guess.dart';
import 'default_aisles.dart';
import 'shopping.dart';

/// Un rayon de la liste et ses produits à acheter.
typedef ShoppingSection = ({
  String? aisleId,
  String name,
  List<ShoppingItem> items,
});

/// La liste rangée par rayon (écran, partage, PDF) et son texte à partager.
abstract final class ShoppingExport {
  /// Les produits à acheter de [list], par rayon dans l'ordre de [aisles] ;
  /// un produit inconnu va dans « Autres » s'il existe, sinon dans une
  /// dernière partie nommée [noAisle].
  static List<ShoppingSection> sections(
    ShoppingList list, {
    required List<Aisle> aisles,
    required Map<String, String> memory,
    required String noAisle,
  }) {
    final ids = {for (final a in aisles) a.id};
    final other = DefaultAisles.idFor('Autres');
    final groups = <String?, List<ShoppingItem>>{};
    for (final item in list.toBuy) {
      final aisle =
          AisleGuess.of(item, memory: memory, aisles: ids) ??
          (ids.contains(other) ? other : null);
      (groups[aisle] ??= []).add(item);
    }
    return [
      for (final aisle in aisles)
        if (groups[aisle.id] case final items?)
          (aisleId: aisle.id, name: aisle.name, items: items),
      if (groups[null] case final items?)
        (aisleId: null, name: noAisle, items: items),
    ];
  }

  /// « 250 g Beurre (doux) » : une ligne de la liste.
  static String line(ShoppingItem item) => [
    if (item.amount.isNotEmpty) item.amount,
    item.name,
    if (item.note.isNotEmpty) '(${item.note})',
  ].join(' ');

  /// Le texte à partager (messagerie, mail) : le nom de la liste, puis
  /// chaque rayon et ses produits.
  static String text(String title, List<ShoppingSection> sections) {
    final out = StringBuffer(title);
    for (final section in sections) {
      out
        ..write('\n\n')
        ..write(section.name.toUpperCase());
      for (final item in section.items) {
        out
          ..write('\n')
          ..write('- ${line(item)}');
      }
    }
    return out.toString();
  }
}
