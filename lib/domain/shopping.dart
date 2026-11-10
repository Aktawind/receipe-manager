import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import 'ingredient_text.dart';
import 'recipe.dart';

/// Une recette qui a demandé un produit de la liste, et combien.
@immutable
class ShoppingSource {
  const ShoppingSource({
    required this.recipeId,
    required this.recipeTitle,
    this.quantity,
    this.unit = '',
  });

  final String recipeId;
  final String recipeTitle;
  final double? quantity;
  final String unit;

  @override
  bool operator ==(Object other) =>
      other is ShoppingSource &&
      other.recipeId == recipeId &&
      other.recipeTitle == recipeTitle &&
      other.quantity == quantity &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(recipeId, recipeTitle, quantity, unit);
}

/// Un produit d'une liste de courses.
@immutable
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.unit = '',
    this.toBuy = '',
    this.format = '',
    this.note = '',
    this.aisleId,
    this.checked = false,
    this.sources = const [],
  });

  final String id;
  final String name;

  /// La quantité nécessaire (somme des recettes, ou saisie).
  final double? quantity;
  final String unit;

  /// Ce qu'on achète vraiment, quand c'est autre chose (« 1 plaquette »).
  final String toBuy;

  /// Le conditionnement voulu (« bouteille de 1 L », « bio »).
  final String format;
  final String note;

  /// Le rayon ; `null` = pas encore rangé.
  final String? aisleId;

  /// Dans le panier.
  final bool checked;

  /// Les recettes qui l'ont demandé.
  final List<ShoppingSource> sources;

  /// « 250 g », « 2 », « » : la quantité nécessaire, telle qu'affichée.
  String get amount => IngredientText.formatAmount(
    IngredientLine(id: id, name: name, quantity: quantity, unit: unit),
  );

  ShoppingItem copyWith({
    String? name,
    double? Function()? quantity,
    String? unit,
    String? toBuy,
    String? format,
    String? note,
    String? Function()? aisleId,
    bool? checked,
    List<ShoppingSource>? sources,
  }) => ShoppingItem(
    id: id,
    name: name ?? this.name,
    quantity: quantity != null ? quantity() : this.quantity,
    unit: unit ?? this.unit,
    toBuy: toBuy ?? this.toBuy,
    format: format ?? this.format,
    note: note ?? this.note,
    aisleId: aisleId != null ? aisleId() : this.aisleId,
    checked: checked ?? this.checked,
    sources: sources ?? this.sources,
  );

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.id == id &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.toBuy == toBuy &&
      other.format == format &&
      other.note == note &&
      other.aisleId == aisleId &&
      other.checked == checked &&
      _sameList(other.sources, sources);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    quantity,
    unit,
    toBuy,
    format,
    note,
    aisleId,
    checked,
    Object.hashAll(sources),
  );
}

/// Une liste de courses (semaine, événement…). Ses produits sont dans l'ordre
/// choisi ; suppression douce, comme les recettes.
@immutable
class ShoppingList {
  const ShoppingList({
    required this.id,
    required this.name,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final List<ShoppingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  /// Les produits encore à acheter, puis ceux du panier.
  List<ShoppingItem> get toBuy => [
    for (final i in items)
      if (!i.checked) i,
  ];
  List<ShoppingItem> get inCart => [
    for (final i in items)
      if (i.checked) i,
  ];

  ShoppingList copyWith({
    String? name,
    List<ShoppingItem>? items,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => ShoppingList(
    id: id,
    name: name ?? this.name,
    items: items ?? this.items,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ShoppingList &&
      other.id == id &&
      other.name == name &&
      _sameList(other.items, items) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(items),
    createdAt,
    updatedAt,
    deletedAt,
  );
}

/// Un rayon du magasin (Fruits et légumes, Surgelés…), dans l'ordre choisi
/// dans les réglages.
@immutable
class Aisle {
  const Aisle({
    required this.id,
    required this.name,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  Aisle copyWith({
    String? name,
    int? position,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => Aisle(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Aisle &&
      other.id == id &&
      other.name == name &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, position, createdAt, updatedAt, deletedAt);
}

/// Le rayon choisi pour un produit : il y retourne la prochaine fois.
@immutable
class ProductAisle {
  const ProductAisle({
    required this.key,
    required this.aisleId,
    required this.updatedAt,
  });

  /// [ShoppingProducts.keyOf] du nom du produit.
  final String key;
  final String aisleId;
  final DateTime updatedAt;

  /// Identifiant stable, le même sur tous les appareils (synchro).
  String get id =>
      const Uuid().v5(Namespace.url.value, 'recettes:product:$key');

  @override
  bool operator ==(Object other) =>
      other is ProductAisle &&
      other.key == key &&
      other.aisleId == aisleId &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(key, aisleId, updatedAt);
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Les noms de produits : comparaison (« Jambons » et « jambon » sont le même
/// produit), lecture d'une ligne saisie ou dictée, et fusion des quantités.
abstract final class ShoppingProducts {
  static const _uuid = Uuid();

  /// Mots qui finissent par « s » ou « x » au singulier.
  static const _invariable = {
    'anis',
    'ananas',
    'brebis',
    'cassis',
    'cresson',
    'frais',
    'gras',
    'jus',
    'mais',
    'noix',
    'pois',
    'radis',
    'riz',
    'os',
    'bras',
    'tapas',
    'chips',
    'couscous',
    'surimi',
    'colis',
  };

  /// Clé de comparaison d'un produit : sans accents ni majuscules, sans
  /// article (« du beurre »), au singulier (« pommes de terre » → « pomme de
  /// terre », « choux » → « chou », « poireaux » → « poireau »).
  static String keyOf(String name) {
    var text = normalizeForSearch(name).replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceFirst(
      RegExp(r"^(du|de la|de l'|des|de|d'|le|la|les|l'|un|une)\s*"),
      '',
    );
    return [for (final word in text.split(' ')) _singular(word)]
        .join(' ')
        .trim();
  }

  static String _singular(String word) {
    if (word.length <= 3 || _invariable.contains(word)) return word;
    if (word.endsWith('eaux')) return word.substring(0, word.length - 1);
    if (word.endsWith('aux') && word.length > 4) {
      // « bocaux » → « bocal ».
      return '${word.substring(0, word.length - 3)}al';
    }
    if (word.endsWith('oux')) return word.substring(0, word.length - 1);
    if (word.endsWith('s') && !word.endsWith('ss')) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  /// Un produit saisi en une ligne : « 2 kg de pommes de terre », « beurre »,
  /// « 6 œufs (bio) ».
  static ShoppingItem parse(String line, {String? id}) {
    var text = line.trim().replaceAll(RegExp(r'\s+'), ' ');
    // « Beurre 50 g », « Jambon x 4 » : la quantité après le nom.
    final trailing = RegExp(
      r'^(\D*?\p{L}\D*?)\s+[x×]?\s*(\d+(?:[.,]\d+)?)\s*([\p{L}.]*)$',
      unicode: true,
    ).firstMatch(text);
    if (trailing != null) {
      final unit = trailing.group(3)!;
      final known =
          unit.isEmpty ||
          IngredientText.units.values.any(
            (variants) => variants.contains(unit.toLowerCase()),
          );
      if (known) {
        text = '${trailing.group(2)} $unit ${trailing.group(1)}'.replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
      }
    }
    final parsed = IngredientText.parse(text, id: '');
    // « du beurre », « des yaourts » (dictée) : le produit, sans article.
    final name = parsed.name.trim().replaceFirst(
      RegExp(r"^(du|de la|de l'|de l’|des|d'|d’)\s*", caseSensitive: false),
      '',
    );
    return ShoppingItem(
      id: id ?? _uuid.v4(),
      name: capitalizeFirst(name),
      quantity: parsed.quantity,
      unit: parsed.unit,
      note: parsed.note,
    );
  }

  static const _numbers = {
    'un': 1,
    'une': 1,
    'deux': 2,
    'trois': 3,
    'quatre': 4,
    'cinq': 5,
    'six': 6,
    'sept': 7,
    'huit': 8,
    'neuf': 9,
    'dix': 10,
    'onze': 11,
    'douze': 12,
    'treize': 13,
    'quatorze': 14,
    'quinze': 15,
    'seize': 16,
    'vingt': 20,
    'trente': 30,
    'quarante': 40,
    'cinquante': 50,
    'cent': 100,
    'deux cents': 200,
    'trois cents': 300,
    'quatre cents': 400,
    'cinq cents': 500,
    'mille': 1000,
  };

  /// Les produits d'une phrase dictée : « deux kilos de pommes de terre, du
  /// beurre et trois yaourts » → trois lignes. Les nombres écrits en lettres
  /// deviennent des chiffres ; « et », « puis » et les virgules séparent.
  static List<String> splitDictation(String text) {
    final parts = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(
          RegExp(r'\s*[,;.]\s*|\s+(?:et puis|puis|et aussi|et|ainsi que)\s+'),
        );
    return [
      for (final part in parts)
        if (part.trim().isNotEmpty) _digits(part.trim()),
    ];
  }

  static String _digits(String part) {
    final half = RegExp(
      r'^(un|une) demi(?:e)?[- ]',
      caseSensitive: false,
    ).firstMatch(part);
    if (half != null) return '0,5 ${part.substring(half.end)}';
    // Les nombres composés d'abord (« deux cents »), puis les simples.
    final words = _numbers.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final word in words) {
      final match = RegExp('^$word\\b', caseSensitive: false).firstMatch(part);
      if (match == null) continue;
      final rest = part.substring(match.end).trim();
      // « un peu de sel » : pas une quantité.
      if (RegExp(r'^peu\b').hasMatch(rest)) return part;
      return '${_numbers[word]} $rest';
    }
    return part;
  }

  /// Unités qui s'additionnent entre elles, avec leur valeur dans l'unité de
  /// base (g ou ml).
  static const _mass = {'mg': 0.001, 'g': 1.0, 'kg': 1000.0};
  static const _volume = {'ml': 1.0, 'cl': 10.0, 'dl': 100.0, 'L': 1000.0};

  /// La somme de deux quantités, si leurs unités s'additionnent : « 200 g » +
  /// « 0,5 kg » = « 700 g » ; « 2 » + « 3 » = « 5 » ; `null` sinon (« 2
  /// œufs » et « 1 c. à soupe »).
  static (double, String)? add((double, String) a, (double, String) b) {
    final (qa, ua) = a;
    final (qb, ub) = b;
    if (ua == ub) return (qa + qb, ua);
    for (final table in [_mass, _volume]) {
      if (table.containsKey(ua) && table.containsKey(ub)) {
        final base = qa * table[ua]! + qb * table[ub]!;
        return _bestUnit(base, table);
      }
    }
    return null;
  }

  static (double, String) _bestUnit(double base, Map<String, double> table) {
    if (identical(table, _mass)) {
      return base >= 1000 ? (base / 1000, 'kg') : (base, 'g');
    }
    if (base >= 1000) return (base / 1000, 'L');
    if (base >= 100 && base % 10 == 0) return (base / 10, 'cl');
    return (base, 'ml');
  }

  /// Ajoute [item] à [items] : fusionné avec le même produit à acheter
  /// (quantités additionnées, recettes réunies) quand c'est possible, sinon
  /// à la fin. Un produit déjà dans le panier n'est pas touché : l'ajout en
  /// redemande.
  /// Déplace les produits [ids] de [from] vers [to] : ils y reviennent à
  /// acheter et s'ajoutent à un produit identique déjà là (quantités et
  /// recettes réunies). Renvoie les produits des deux listes.
  static ({List<ShoppingItem> from, List<ShoppingItem> to}) transfer(
    List<ShoppingItem> from,
    List<ShoppingItem> to,
    Set<String> ids,
  ) {
    var target = to;
    for (final item in from) {
      if (ids.contains(item.id)) {
        target = merge(target, item.copyWith(checked: false));
      }
    }
    return (
      from: [
        for (final item in from)
          if (!ids.contains(item.id)) item,
      ],
      to: target,
    );
  }

  static List<ShoppingItem> merge(List<ShoppingItem> items, ShoppingItem item) {
    final key = keyOf(item.name);
    for (final (index, existing) in items.indexed) {
      if (existing.checked || keyOf(existing.name) != key) continue;
      final ShoppingItem? merged = switch ((existing.quantity, item.quantity)) {
        (null, null) => existing,
        (final a?, final b?) => switch (add(
          (a, existing.unit),
          (b, item.unit),
        )) {
          (final q, final u)? => existing.copyWith(quantity: () => q, unit: u),
          null => null,
        },
        // Une quantité d'un côté seulement : la quantité l'emporte.
        (null, final b?) => existing.copyWith(
          quantity: () => b,
          unit: item.unit,
        ),
        (_?, null) => existing,
      };
      if (merged == null) continue;
      return [
        ...items.sublist(0, index),
        merged.copyWith(
          note: _joinText(existing.note, item.note),
          format: existing.format.isEmpty ? item.format : existing.format,
          aisleId: () => existing.aisleId ?? item.aisleId,
          sources: [...existing.sources, ...item.sources],
        ),
        ...items.sublist(index + 1),
      ];
    }
    return [...items, item];
  }

  static String _joinText(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty || normalizeForSearch(a) == normalizeForSearch(b)) return a;
    return '$a, $b';
  }
}
