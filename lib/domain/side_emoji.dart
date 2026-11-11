import '../core/format/text_search.dart';
import 'meal_planner.dart';

/// Un emoji pour un accompagnement (🥔 pommes de terre, 🥕 carottes…), d'après
/// les mots de son nom ; à défaut, celui de sa sorte (🌾 féculent, 🍖 protéine,
/// 🥬 légume).
abstract final class SideEmoji {
  /// Mots (normalisés, au début d'un mot du nom) → emoji ; le premier qui
  /// convient l'emporte : les plus précis d'abord.
  static const _words = [
    ('patate douce', '🍠'),
    ('pomme de terre', '🥔'),
    ('pommes de terre', '🥔'),
    ('frite', '🍟'),
    ('puree', '🥔'),
    ('riz', '🍚'),
    ('pate', '🍝'),
    ('spaghetti', '🍝'),
    ('nouille', '🍜'),
    ('pain', '🥖'),
    ('baguette', '🥖'),
    ('polenta', '🌽'),
    ('mais', '🌽'),
    ('lentille', '🫘'),
    ('pois chiche', '🫘'),
    ('haricot rouge', '🫘'),
    ('haricot blanc', '🫘'),
    ('poulet', '🍗'),
    ('dinde', '🍗'),
    ('canard', '🍗'),
    ('boeuf', '🥩'),
    ('steak', '🥩'),
    ('veau', '🥩'),
    ('agneau', '🥩'),
    ('jambon', '🥓'),
    ('lardon', '🥓'),
    ('bacon', '🥓'),
    ('saucisse', '🌭'),
    ('porc', '🍖'),
    ('crevette', '🦐'),
    ('poisson', '🐟'),
    ('saumon', '🐟'),
    ('thon', '🐟'),
    ('cabillaud', '🐟'),
    ('oeuf', '🥚'),
    ('fromage', '🧀'),
    ('chou-fleur', '🥦'),
    ('brocoli', '🥦'),
    ('carotte', '🥕'),
    ('tomate', '🍅'),
    ('aubergine', '🍆'),
    ('courgette', '🥒'),
    ('concombre', '🥒'),
    ('cornichon', '🥒'),
    ('poivron', '🫑'),
    ('piment', '🌶️'),
    ('champignon', '🍄'),
    ('potiron', '🎃'),
    ('citrouille', '🎃'),
    ('courge', '🎃'),
    ('butternut', '🎃'),
    ('salade', '🥗'),
    ('oignon', '🧅'),
    ('ail', '🧄'),
    ('avocat', '🥑'),
  ];

  static String of(SideDish side) => forName(side.name, side.kind);

  static String forName(String name, SideKind kind) {
    final key = ' ${normalizeForSearch(name).replaceAll(RegExp(r'\s+'), ' ')}';
    for (final (word, emoji) in _words) {
      if (key.contains(' $word')) return emoji;
    }
    return switch (kind) {
      SideKind.starch => '🌾',
      SideKind.protein => '🍖',
      SideKind.vegetable => '🥬',
    };
  }
}
