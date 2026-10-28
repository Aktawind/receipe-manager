import 'package:uuid/uuid.dart';

import 'recipe.dart';

/// Conversion entre une ligne de texte (« 200 g de farine, tamisée ») et un
/// [IngredientLine] structuré. Sert à la saisie, et servira aux imports.
abstract final class IngredientText {
  /// Unités reconnues en début de ligne, dans leur forme affichée.
  /// Chaque entrée : forme canonique → variantes acceptées à la saisie.
  static const units = <String, List<String>>{
    'g': ['g', 'gr', 'gramme', 'grammes'],
    'kg': ['kg', 'kilo', 'kilos', 'kilogramme', 'kilogrammes'],
    'mg': ['mg'],
    'ml': ['ml', 'millilitre', 'millilitres'],
    'cl': ['cl', 'centilitre', 'centilitres'],
    'dl': ['dl', 'décilitre', 'décilitres'],
    'L': ['l', 'litre', 'litres'],
    'c. à s.': [
      'c. à soupe',
      'c à soupe',
      'c.à soupe',
      'c. à s.',
      'c.à.s.',
      'c.à.s',
      'c.s.',
      'c.s',
      'c/s',
      'c. à s',
      'cas',
      'càs',
      'cs',
      'cuillère à soupe',
      'cuillères à soupe',
      'cuillerée à soupe',
      'cuillerées à soupe',
      'cuil. à soupe',
    ],
    'c. à c.': [
      'c. à café',
      'c à café',
      'c.à café',
      'c. à c.',
      'c.à.c.',
      'c.à.c',
      'c.c.',
      'c.c',
      'c/c',
      'c. à c',
      'cac',
      'càc',
      'cc',
      'cuillère à café',
      'cuillères à café',
      'cuillerée à café',
      'cuillerées à café',
      'cuil. à café',
    ],
    'tasse': ['tasse', 'tasses', 'cup', 'cups'],
    'verre': ['verre', 'verres'],
    'pincée': ['pincée', 'pincées'],
    'poignée': ['poignée', 'poignées'],
    'pièce': ['pièce', 'pièces', 'pc', 'pcs'],
    'tranche': ['tranche', 'tranches'],
    'gousse': ['gousse', 'gousses'],
    'botte': ['botte', 'bottes'],
    'brin': ['brin', 'brins'],
    'branche': ['branche', 'branches'],
    'feuille': ['feuille', 'feuilles'],
    'sachet': ['sachet', 'sachets'],
    'boîte': ['boîte', 'boîtes', 'boite', 'boites'],
    'pot': ['pot', 'pots'],
    'noix': ['noix'],
    'noisette': ['noisette', 'noisettes'],
    'filet': ['filet', 'filets'],
    'trait': ['trait', 'traits'],
    'rouleau': ['rouleau', 'rouleaux'],
    'bouquet': ['bouquet', 'bouquets'],
    'tige': ['tige', 'tiges'],
    'cube': ['cube', 'cubes'],
    'morceau': ['morceau', 'morceaux'],
    'barquette': ['barquette', 'barquettes'],
    'bocal': ['bocal', 'bocaux'],
  };

  /// Forme affichée d'une unité, quand elle diffère de la forme enregistrée
  /// (les données déjà saisies gardent « c. à s. »).
  static const _displayForm = {'c. à s.': 'c. à soupe', 'c. à c.': 'c. à café'};

  static const _irregularPlural = {'rouleau': 'rouleaux', 'bocal': 'bocaux'};

  /// Unités qui s'accordent au pluriel à l'affichage (« 2 pincées »).
  static const _pluralizable = {
    'tasse',
    'verre',
    'pincée',
    'poignée',
    'pièce',
    'tranche',
    'gousse',
    'botte',
    'brin',
    'branche',
    'feuille',
    'sachet',
    'boîte',
    'pot',
    'noisette',
    'filet',
    'trait',
    'rouleau',
    'bouquet',
    'tige',
    'cube',
    'morceau',
    'barquette',
    'bocal',
  };

  static const _unicodeFractions = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1 / 3,
    '⅔': 2 / 3,
    '⅛': 0.125,
  };

  static final _optionalPattern = RegExp(
    r'\s*\(?\bfacultatif\b\)?\s*',
    caseSensitive: false,
  );
  static final _toTastePattern = RegExp(
    r'\s*\b(selon (le|votre) goût|au goût|à volonté)\b\s*',
    caseSensitive: false,
  );

  static final _bulletPattern = RegExp(
    r'^(?:[-*•–—·▪◦►▶]+|\[[ xX✓]?\]|\d{1,2}\s*[.)](?=\s))\s*',
  );
  static final _forPattern = RegExp(
    r"^pour (?:le|la|les|l['’]|un|une|des|du|de la)\b",
    caseSensitive: false,
  );
  static final _nameColonAmount = RegExp(r'^([^:\d]{2,40}?)\s*:\s*(\d.*)$');
  static final _trailingParens = RegExp(r'\s*\(([^()]*)\)\s*$');
  static final _rangeAfterQuantity = RegExp(
    r'^(?:(?:à|a|ou)\s+|[-–—]\s*)\d',
    caseSensitive: false,
  );

  /// Retire puces, numéros et marques de mise en forme d'une ligne collée.
  /// Renvoie le texte nettoyé et `true` si la ligne était un titre (« ## Pâte »,
  /// « **Pâte** »).
  static (String, bool) _clean(String input) {
    var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    for (var i = 0; i < 2; i++) {
      text = text.replaceFirst(_bulletPattern, '');
    }
    var heading = false;
    final hashes = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(text);
    if (hashes != null) {
      heading = true;
      text = hashes.group(1)!;
    }
    final bold = RegExp(r'^(?:\*\*|__)(.+?)(?:\*\*|__)\s*:?$').firstMatch(text);
    if (bold != null && !RegExp(r'^\d').hasMatch(bold.group(1)!)) {
      heading = true;
      text = bold.group(1)!;
    }
    text = text.replaceAll('**', '').replaceAll('__', '').trim();
    return (text, heading);
  }

  /// Analyse une ligne saisie ou collée. Une ligne terminée par « : », un
  /// titre en gras ou « ## », ou « Pour la pâte » devient un titre de groupe.
  static IngredientLine parse(String input, {required String id}) {
    var (text, heading) = _clean(input);
    // « beurre | huile de coco, margarine » : ce qui suit « | » peut le remplacer.
    var substitutes = '';
    final pipe = text.indexOf('|');
    if (pipe >= 0) {
      substitutes = text.substring(pipe + 1).trim();
      text = text.substring(0, pipe).trim();
    }
    final words = text.split(' ').length;
    final looksLikeFor =
        _forPattern.hasMatch(text) &&
        !RegExp(r'[\d,]').hasMatch(text) &&
        words <= 6;
    // « 🍐 INSERT POIRE » : quelques mots en majuscules, sans chiffre.
    final isCapitals =
        words >= 2 &&
        words <= 5 &&
        text.length <= 40 &&
        text == text.toUpperCase() &&
        RegExp(r'\p{L}', unicode: true).hasMatch(text) &&
        !RegExp(r'\d|[.!?]$').hasMatch(text);
    if (text.endsWith(':') || heading || looksLikeFor || isCapitals) {
      return IngredientLine(
        id: id,
        isSection: true,
        name: text.replaceFirst(RegExp(r'\s*:$'), '').trim(),
      );
    }

    // « Farine : 200 g » (liste générée) -> « 200 g Farine ».
    final reordered = _nameColonAmount.firstMatch(text);
    if (reordered != null) {
      text = '${reordered.group(2)} ${reordered.group(1)}';
    }

    var optional = false;
    if (_optionalPattern.hasMatch(text)) {
      optional = true;
      text = text.replaceAll(_optionalPattern, ' ').trim();
    }

    final notes = <String>[];
    final toTaste = _toTastePattern.firstMatch(text);
    if (toTaste != null) {
      notes.add(toTaste.group(1)!.toLowerCase());
      text = text.replaceFirst(_toTastePattern, ' ').trim();
    }

    final parens = _trailingParens.firstMatch(text);
    if (parens != null && parens.start > 0) {
      notes.insert(0, parens.group(1)!.trim());
      text = text.substring(0, parens.start).trim();
    }

    // A comma between two digits is a decimal separator, not a note.
    final comma = text.indexOf(RegExp(r'(?<!\d),|,(?!\d)'));
    if (comma >= 0) {
      notes.insert(0, text.substring(comma + 1).trim());
      text = text.substring(0, comma).trim();
    }

    double? quantity;
    final quantityMatch = _matchQuantity(text);
    if (quantityMatch != null) {
      final rest = text.substring(quantityMatch.$2).trim();
      // « 2 à 3 œufs », « 1-2 c. à café » : on garde la ligne telle quelle
      // plutôt que de perdre la fourchette.
      if (!_rangeAfterQuantity.hasMatch(rest)) {
        quantity = quantityMatch.$1;
        text = rest;
      }
    }

    var unit = '';
    if (quantity != null) {
      final unitMatch = _matchUnit(text);
      if (unitMatch != null) {
        unit = unitMatch.$1;
        text = text.substring(unitMatch.$2).trim();
        text = text.replaceFirst(
          RegExp(r"^(de |d'|d’)", caseSensitive: false),
          '',
        );
      }
    }

    return IngredientLine(
      id: id,
      name: text.trim(),
      quantity: quantity,
      unit: unit,
      note: notes.where((n) => n.isNotEmpty).join(', '),
      optional: optional,
      substitutes: substitutes,
    );
  }

  /// Texte affiché et réédité : l'inverse de [parse].
  static String format(IngredientLine line) {
    if (line.isSection) return '${line.name}:';
    final buffer = StringBuffer();
    if (line.quantity != null) {
      buffer.write(formatQuantity(line.quantity!));
      buffer.write(' ');
      if (line.unit.isNotEmpty) {
        buffer.write(_unitFor(line.unit, line.quantity!));
        buffer.write(' ');
        if (line.name.isNotEmpty) buffer.write(partitive(line.name));
      }
    }
    buffer.write(line.name);
    if (line.note.isNotEmpty) buffer.write(', ${line.note}');
    if (line.optional) buffer.write(' (facultatif)');
    if (line.substitutes.isNotEmpty) buffer.write(' | ${line.substitutes}');
    return buffer.toString().trim();
  }

  /// Analyse une liste d'ingrédients collée en une fois : une ligne par
  /// ingrédient. Les lignes vides et les séparateurs (« --- ») sont ignorés.
  /// [previousIds] permet de garder l'identifiant des lignes déjà enregistrées.
  static List<IngredientLine> parseList(
    String text, {
    List<String> previousIds = const [],
  }) {
    final lines = <IngredientLine>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(raw)) continue;
      final id = lines.length < previousIds.length
          ? previousIds[lines.length]
          : const Uuid().v4();
      lines.add(parse(raw, id: id));
    }
    return lines;
  }

  /// Texte d'édition d'une liste d'ingrédients : l'inverse de [parseList].
  static String formatList(List<IngredientLine> lines) =>
      lines.map(format).join('\n');

  /// Quantité et unité telles qu'affichées à droite du nom : « 250 g »,
  /// « 2 gousses », « 3 ». Vide si l'ingrédient n'a pas de quantité.
  static String formatAmount(IngredientLine line) {
    final quantity = line.quantity;
    if (quantity == null) return '';
    final amount = formatQuantity(quantity);
    return line.unit.isEmpty
        ? amount
        : '$amount ${_unitFor(line.unit, quantity)}';
  }

  /// « 1,5 » → « 1 ½ », « 0,333 » → « ⅓ », « 2 » → « 2 ».
  static String formatQuantity(double value) {
    final whole = value.truncate();
    final fraction = value - whole;
    for (final entry in _unicodeFractions.entries) {
      if ((fraction - entry.value).abs() < 0.01) {
        return whole == 0 ? entry.key : '$whole ${entry.key}';
      }
    }
    if (fraction.abs() < 0.001) return '$whole';
    var text = value.toStringAsFixed(2);
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return text.replaceAll('.', ',');
  }

  /// Lit une quantité seule (champ « portions », import…).
  static double? parseQuantity(String input) {
    final match = _matchQuantity(input.trim());
    if (match == null || match.$2 != input.trim().length) return null;
    return match.$1;
  }

  // Quantité en tête de texte : « 2 », « 1,5 », « 1/2 », « 1 1/2 », « ½ »,
  // « 1½ », « un », « une ». Renvoie (valeur, longueur consommée).
  static (double, int)? _matchQuantity(String text) {
    final pattern = RegExp(
      r'^(?:(\d+)\s*([½¼¾⅓⅔⅛])|(\d+)\s+(\d+)\s*/\s*(\d+)|(\d+)\s*/\s*(\d+)|(\d+(?:[.,]\d+)?)|([½¼¾⅓⅔⅛])|(une?)(?=\s))',
      caseSensitive: false,
    );
    final m = pattern.firstMatch(text);
    if (m == null) return null;
    double value;
    if (m.group(1) != null) {
      value = int.parse(m.group(1)!) + _unicodeFractions[m.group(2)!]!;
    } else if (m.group(3) != null) {
      final denominator = int.parse(m.group(5)!);
      if (denominator == 0) return null;
      value = int.parse(m.group(3)!) + int.parse(m.group(4)!) / denominator;
    } else if (m.group(6) != null) {
      final denominator = int.parse(m.group(7)!);
      if (denominator == 0) return null;
      value = int.parse(m.group(6)!) / denominator;
    } else if (m.group(8) != null) {
      value = double.parse(m.group(8)!.replaceAll(',', '.'));
    } else if (m.group(9) != null) {
      value = _unicodeFractions[m.group(9)!]!;
    } else {
      value = 1;
    }
    // A number directly followed by a letter ("2x", "3e") is not a quantity.
    final end = m.end;
    if (m.group(10) == null &&
        end < text.length &&
        RegExp(r'[a-zA-Zéèàù]').hasMatch(text[end]) &&
        _matchUnit(text.substring(end)) == null) {
      return null;
    }
    return (value, end);
  }

  // Unité en tête de texte, suivie d'une fin de mot. Renvoie (forme
  // canonique, longueur consommée). Les variantes longues sont testées d'abord.
  static (String, int)? _matchUnit(String text) {
    final lower = text.toLowerCase();
    (String, int)? best;
    for (final entry in units.entries) {
      for (final variant in entry.value) {
        if (!lower.startsWith(variant)) continue;
        final end = variant.length;
        final atBoundary =
            end == lower.length ||
            !RegExp(r'[a-zàâäéèêëîïôöùûüç]').hasMatch(lower[end]);
        if (atBoundary && (best == null || end > best.$2)) {
          best = (entry.key, end);
        }
      }
    }
    return best;
  }

  static String _unitFor(String unit, double quantity) {
    if (quantity >= 2 && _pluralizable.contains(unit)) {
      return _irregularPlural[unit] ?? '${unit}s';
    }
    return _displayForm[unit] ?? unit;
  }

  /// « de » ou « d' » devant un nom, pour « 200 g de farine », « 1 pot d'huile ».
  static String partitive(String name) {
    final first = name[0].toLowerCase();
    return 'aeiouyhéèêàâîôû'.contains(first) ? "d'" : 'de ';
  }
}
