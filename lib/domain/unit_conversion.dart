import '../core/format/text_search.dart';
import 'ingredient_text.dart';

/// Les unités dans lesquelles afficher les quantités.
enum UnitSystem {
  /// Telles qu'écrites dans la recette.
  recipe,

  /// Grammes, millilitres (les cuillères restent des cuillères).
  metric,

  /// Onces, livres, tasses.
  imperial,
}

/// L'unité des températures du four dans la préparation.
enum TemperatureUnit { recipe, celsius, fahrenheit }

/// Une quantité convertie dans une autre unité.
class ConvertedAmount {
  const ConvertedAmount(this.quantity, this.unit, {this.approximate = false});

  final double quantity;
  final String unit;

  /// Passée d'un volume à un poids (ou l'inverse) par la densité de
  /// l'ingrédient : une estimation, pas une conversion exacte.
  final bool approximate;
}

/// Conversions entre unités compatibles, et entre volume et poids quand la
/// densité de l'ingrédient est connue.
abstract final class UnitConversion {
  /// Grammes par unité de poids.
  static const _grams = {
    'mg': 0.001,
    'g': 1.0,
    'kg': 1000.0,
    'oz': 28.349523125,
    'lb': 453.59237,
  };

  /// Millilitres par unité de volume. La tasse est la « cup » américaine
  /// (les recettes en tasses viennent surtout de sites américains).
  static const _millilitres = {
    'ml': 1.0,
    'cl': 10.0,
    'dl': 100.0,
    'L': 1000.0,
    'c. à c.': 5.0,
    'c. à s.': 15.0,
    'tasse': 240.0,
    'fl oz': 29.5735,
  };

  static const _spoons = {'c. à c.', 'c. à s.'};

  /// Grammes par millilitre des ingrédients qu'on mesure souvent à la
  /// tasse. Le premier nom reconnu au début du nom de l'ingrédient l'emporte
  /// (« sucre glace » avant « sucre »).
  static const _densities = <String, double>{
    'farine': 0.53,
    'maizena': 0.53,
    'fecule': 0.53,
    'sucre glace': 0.5,
    'sucre roux': 0.9,
    'sucre de canne': 0.9,
    'cassonade': 0.9,
    'vergeoise': 0.9,
    'sucre': 0.85,
    'beurre': 0.96,
    'riz': 0.8,
    'flocons d avoine': 0.38,
    'avoine': 0.38,
    'cacao': 0.42,
    'poudre d amande': 0.4,
    'amandes en poudre': 0.4,
    'amande en poudre': 0.4,
    'noix de coco rapee': 0.35,
    'pepites de chocolat': 0.72,
    'chocolat': 0.72,
    'miel': 1.42,
    'sirop d erable': 1.32,
    'sirop': 1.32,
    'lait': 1.03,
    'creme': 1.0,
    'eau': 1.0,
    'huile': 0.92,
    'yaourt': 1.05,
    'fromage blanc': 1.05,
    'semoule': 0.7,
    'quinoa': 0.75,
    'lentilles': 0.8,
    'parmesan': 0.4,
    'sel': 1.2,
  };

  /// Liquides : on les garde en volume (ml) plutôt qu'en poids.
  static const _liquids = {
    'lait',
    'creme',
    'eau',
    'huile',
    'sirop',
    'sirop d erable',
  };

  /// [quantity] [unit] de [name] dans [system], `null` si rien n'est à
  /// changer (déjà dans le bon système, ou unité non convertible : pièces,
  /// pincées, verres…).
  static ConvertedAmount? convert(
    double quantity,
    String unit,
    String name,
    UnitSystem system,
  ) => switch (system) {
    UnitSystem.recipe => null,
    UnitSystem.metric => _toMetric(quantity, unit, name),
    UnitSystem.imperial => _toImperial(quantity, unit, name),
  };

  static ConvertedAmount? _toMetric(double quantity, String unit, String name) {
    if (unit == 'oz' || unit == 'lb') {
      return _metricMass(quantity * _grams[unit]!);
    }
    if (unit == 'tasse' || unit == 'fl oz') {
      final ml = quantity * _millilitres[unit]!;
      final density = _density(name);
      if (density != null && !_isLiquid(name)) {
        return _metricMass(ml * density, approximate: true);
      }
      return _metricVolume(ml);
    }
    return null;
  }

  static ConvertedAmount? _toImperial(
    double quantity,
    String unit,
    String name,
  ) {
    final grams = _grams[unit];
    if (grams != null && unit != 'oz' && unit != 'lb') {
      final oz = quantity * grams / _grams['oz']!;
      if (oz < 0.25) return null;
      return oz >= 16
          ? ConvertedAmount(oz / 16, 'lb')
          : ConvertedAmount(oz, 'oz');
    }
    final ml = _millilitres[unit];
    if (ml != null && !_spoons.contains(unit) && unit != 'tasse') {
      final total = quantity * ml;
      if (total >= 60) return ConvertedAmount(total / 240, 'tasse');
      if (total >= 15) return ConvertedAmount(total / 15, 'c. à s.');
      return ConvertedAmount(total / 5, 'c. à c.');
    }
    return null;
  }

  static ConvertedAmount _metricMass(
    double grams, {
    bool approximate = false,
  }) => grams >= 1000
      ? ConvertedAmount(grams / 1000, 'kg', approximate: approximate)
      : ConvertedAmount(grams, 'g', approximate: approximate);

  static ConvertedAmount _metricVolume(double ml) =>
      ml >= 1000 ? ConvertedAmount(ml / 1000, 'L') : ConvertedAmount(ml, 'ml');

  static String _key(String name) =>
      normalizeForSearch(name).replaceAll(RegExp(r"['’-]"), ' ').trim();

  static double? _density(String name) {
    final key = _key(name);
    for (final entry in _densities.entries) {
      if (key == entry.key || key.startsWith('${entry.key} ')) {
        return entry.value;
      }
    }
    return null;
  }

  static bool _isLiquid(String name) {
    final key = _key(name);
    return _liquids.any((l) => key == l || key.startsWith('$l '));
  }

  // --- Préparation : températures et dimensions des moules ---

  static final _temperature = RegExp(
    r'(\d{2,3})\s?(?:°\s?([CF])\b|°|degrés(?:\s+celsius)?)',
    caseSensitive: false,
  );
  static final _thermostat = RegExp(
    r'\b(th(?:ermostat|\.)?\s?(\d{1,2}))\b(?!\s?\()',
    caseSensitive: false,
  );

  /// Les températures de [text] dans [target] : « 350 °F » → « 175 °C ».
  /// Un thermostat (« th. 6 ») reçoit la température entre parenthèses.
  static String convertTemperatures(String text, TemperatureUnit target) {
    if (target == TemperatureUnit.recipe) return text;
    final celsius = target == TemperatureUnit.celsius;
    var result = text.replaceAllMapped(_temperature, (m) {
      final value = int.parse(m.group(1)!);
      final isF = m.group(2)?.toUpperCase() == 'F';
      if (isF == !celsius) return m.group(0)!;
      return celsius
          ? '${_roundTo((value - 32) * 5 / 9, 5)} °C'
          : '${_fahrenheit(value.toDouble())} °F';
    });
    result = result.replaceAllMapped(_thermostat, (m) {
      final position = int.parse(m.group(2)!);
      if (position < 1 || position > 10) return m.group(0)!;
      final c = position * 30;
      return '${m.group(1)} (${celsius ? '$c °C' : '${_fahrenheit(c.toDouble())} °F'})';
    });
    return result;
  }

  static final _centimetres = RegExp(r'(\d{1,2}(?:[.,]\d)?)\s?cm\b');
  static final _inches = RegExp(
    r'''(\d{1,2}(?:[.,]\d)?)\s?(?:"|″|inch(?:es)?\b|pouces?\b)''',
    caseSensitive: false,
  );

  /// Les dimensions de [text] (moules, épaisseur) dans [system] :
  /// « 24 cm » ↔ « 9 ½ pouces ».
  static String convertLengths(String text, UnitSystem system) {
    double parse(String s) => double.parse(s.replaceAll(',', '.'));
    return switch (system) {
      UnitSystem.recipe => text,
      UnitSystem.metric => text.replaceAllMapped(
        _inches,
        (m) => '${_roundTo(parse(m.group(1)!) * 2.54, 1)} cm',
      ),
      UnitSystem.imperial => text.replaceAllMapped(_centimetres, (m) {
        final inches = (parse(m.group(1)!) / 2.54 * 2).round() / 2;
        return '${IngredientText.formatQuantity(inches)} pouces';
      }),
    };
  }

  /// °F d'un four : au 25 le plus proche (350, 375, 400), au 5 en dessous de
  /// 200 °F.
  static int _fahrenheit(double celsius) {
    final f = celsius * 9 / 5 + 32;
    return f >= 200 ? _roundTo(f, 25) : _roundTo(f, 5);
  }

  static int _roundTo(double value, int step) => (value / step).round() * step;
}
