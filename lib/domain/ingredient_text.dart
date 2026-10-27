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
      'c. à s.',
      'c.à.s.',
      'c.à.s',
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
      'c. à c.',
      'c.à.c.',
      'c.à.c',
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
  };

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

  /// Analyse une ligne saisie. Une ligne terminée par « : » devient un titre
  /// de groupe.
  static IngredientLine parse(String input, {required String id}) {
    var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.endsWith(':')) {
      return IngredientLine(
        id: id,
        isSection: true,
        name: text.substring(0, text.length - 1).trim(),
      );
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

    // A comma between two digits is a decimal separator, not a note.
    final comma = text.indexOf(RegExp(r'(?<!\d),|,(?!\d)'));
    if (comma >= 0) {
      notes.insert(0, text.substring(comma + 1).trim());
      text = text.substring(0, comma).trim();
    }

    double? quantity;
    final quantityMatch = _matchQuantity(text);
    if (quantityMatch != null) {
      quantity = quantityMatch.$1;
      text = text.substring(quantityMatch.$2).trim();
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
        if (line.name.isNotEmpty) buffer.write(_partitive(line.name));
      }
    }
    buffer.write(line.name);
    if (line.note.isNotEmpty) buffer.write(', ${line.note}');
    if (line.optional) buffer.write(' (facultatif)');
    return buffer.toString().trim();
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
    if (quantity >= 2 && _pluralizable.contains(unit)) return '${unit}s';
    return unit;
  }

  static String _partitive(String name) {
    final first = name[0].toLowerCase();
    return 'aeiouyhéèêàâîôû'.contains(first) ? "d'" : 'de ';
  }
}
