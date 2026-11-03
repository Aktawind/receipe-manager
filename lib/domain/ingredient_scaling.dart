import '../core/format/text_search.dart';
import 'recipe.dart';

/// Ce qui demande de l'attention quand on change les portions d'un
/// ingrédient.
enum ScaleNotice {
  /// Arrondi à une quantité entière (œufs, sachets, boîtes…) : la quantité
  /// exacte est donnée à côté.
  rounded,

  /// Levure, bicarbonate : leur effet n'est pas proportionnel.
  leavening,

  /// Sel, poivre, piment, épices : à goûter plutôt qu'à multiplier.
  seasoning,

  /// Sans quantité lisible (« 2 à 3 œufs », « un peu de lait ») : à ajuster
  /// soi-même.
  manual,
}

/// Un ingrédient à l'échelle : la nouvelle quantité (arrondie pour la
/// cuisine), la quantité exacte et ce qui mérite attention.
class ScaledIngredient {
  const ScaledIngredient({
    required this.line,
    required this.quantity,
    required this.exact,
    this.notice,
  });

  /// La ligne d'origine, inchangée.
  final IngredientLine line;

  /// La quantité à afficher, arrondie ; `null` sans quantité.
  final double? quantity;

  /// La quantité proportionnelle, sans arrondi.
  final double? exact;

  final ScaleNotice? notice;

  /// La ligne avec sa nouvelle quantité.
  IngredientLine get scaledLine => IngredientLine(
    id: line.id,
    isSection: line.isSection,
    name: line.name,
    quantity: quantity,
    unit: line.unit,
    note: line.note,
    optional: line.optional,
    substitutes: line.substitutes,
    linkedRecipeId: line.linkedRecipeId,
  );
}

/// Recalcul des quantités d'une recette pour un autre nombre de portions.
abstract final class IngredientScaling {
  /// Le facteur entre les portions d'origine et celles voulues.
  static double factor(int original, num wanted) =>
      original <= 0 ? 1 : wanted / original;

  static const _metricSmall = {'g', 'ml', 'mg'};
  static const _metricLarge = {'kg', 'L'};
  static const _metricMid = {'cl', 'dl'};
  static const _spoons = {'c. à s.', 'c. à c.', 'tasse', 'verre'};
  static const _halves = {
    'pincée',
    'poignée',
    'noix',
    'noisette',
    'filet',
    'trait',
    'branche',
    'brin',
    'feuille',
    'tranche',
    'botte',
    'bouquet',
    'tige',
    'morceau',
    'gousse',
    'pièce',
  };

  /// Unités qu'on ne coupe pas : arrondi à l'entier.
  static const _indivisibleUnits = {
    'sachet',
    'boîte',
    'pot',
    'cube',
    'rouleau',
    'bocal',
    'barquette',
  };

  /// Ingrédients comptés qu'on ne coupe pas (sans unité : « 3 œufs »).
  static const _indivisibleNames = {
    'oeuf',
    'jaune',
    'blanc',
    'yaourt',
    'sachet',
    'boite',
    'rouleau',
    'pate',
    'feuille',
    'abaisse',
    'pot',
    'cube',
    'brique',
    'canette',
    'bouteille',
  };

  static const _leaveningWords = {
    'levure',
    'bicarbonate',
    'poudre a lever',
    'baking powder',
    'baking soda',
  };

  static const _seasoningWords = {
    'sel',
    'fleur de sel',
    'poivre',
    'piment',
    'cayenne',
    'espelette',
    'harissa',
    'tabasco',
    'sriracha',
    'epice',
    'curry',
    'paprika fume',
    'muscade',
    'cumin',
    'ras el hanout',
    'wasabi',
    'chili',
  };

  /// Les lignes de [ingredients] multipliées par [factor]. Les titres de
  /// groupe et les lignes vides sont gardés tels quels (sans quantité).
  static List<ScaledIngredient> scale(
    List<IngredientLine> ingredients,
    double factor,
  ) => [for (final line in ingredients) scaleLine(line, factor)];

  static ScaledIngredient scaleLine(IngredientLine line, double factor) {
    final original = line.quantity;
    if (line.isSection || line.isBlank) {
      return ScaledIngredient(line: line, quantity: null, exact: null);
    }
    final same = (factor - 1).abs() < 1e-9;
    if (original == null) {
      return ScaledIngredient(
        line: line,
        quantity: null,
        exact: null,
        notice: same || !_needsAmount(line) ? null : ScaleNotice.manual,
      );
    }
    final exact = original * factor;
    if (same) {
      return ScaledIngredient(line: line, quantity: original, exact: original);
    }
    final quantity = round(exact, line);
    ScaleNotice? notice;
    final name = normalizeForSearch(line.name);
    if (_containsAny(name, _leaveningWords)) {
      notice = ScaleNotice.leavening;
    } else if (_containsAny(name, _seasoningWords)) {
      notice = ScaleNotice.seasoning;
    } else if ((quantity - exact).abs() > exact * 0.05 + 1e-9) {
      notice = ScaleNotice.rounded;
    }
    return ScaledIngredient(
      line: line,
      quantity: quantity,
      exact: exact,
      notice: notice,
    );
  }

  /// Arrondi « de cuisine » d'une quantité, selon son unité : au gramme sur
  /// la balance, au quart de cuillère, à l'entier pour un œuf ou un sachet.
  static double round(double value, IngredientLine line) {
    final unit = line.unit;
    if (_metricSmall.contains(unit)) {
      final step = value < 10
          ? 0.5
          : value < 250
          ? 1.0
          : value < 1000
          ? 5.0
          : 10.0;
      return _toStep(value, step, minimum: step);
    }
    if (_metricLarge.contains(unit)) {
      return _toStep(value, value < 2 ? 0.05 : 0.1, minimum: 0.05);
    }
    if (_metricMid.contains(unit)) {
      return _toStep(value, value < 10 ? 0.5 : 1, minimum: 0.5);
    }
    if (_spoons.contains(unit)) return _toFraction(value);
    if (_indivisibleUnits.contains(unit) || _isIndivisible(line)) {
      return value < 1 ? 1 : value.roundToDouble();
    }
    if (_halves.contains(unit) || unit.isEmpty) {
      // Les grandes quantités sans unité (« 24 blinis ») restent entières.
      if (unit.isEmpty && value >= 10) return value.roundToDouble();
      return _toStep(value, 0.5, minimum: 0.5);
    }
    return _toFraction(value);
  }

  static bool _isIndivisible(IngredientLine line) {
    if (line.unit.isNotEmpty) return false;
    final first = normalizeForSearch(line.name).split(' ').first;
    final stem = first.endsWith('s') || first.endsWith('x')
        ? first.substring(0, first.length - 1)
        : first;
    return _indivisibleNames.contains(stem) ||
        _indivisibleNames.contains(first);
  }

  // Une ligne sans quantité mérite-t-elle d'être signalée ? Pas « sel » ni
  // « poivre » ni « huile pour la friture » : seulement celles qui commencent
  // par un nombre (« 2 à 3 œufs ») ou disent « un peu ».
  static bool _needsAmount(IngredientLine line) {
    final name = normalizeForSearch(line.name);
    return RegExp(r'^\d').hasMatch(name) ||
        RegExp(r'^(un peu|quelques)\b').hasMatch(name);
  }

  static bool _containsAny(String name, Set<String> words) {
    for (final word in words) {
      if (RegExp('(^| )${RegExp.escape(word)}s?( |\$)').hasMatch(name)) {
        return true;
      }
    }
    return false;
  }

  static double _toStep(double value, double step, {required double minimum}) {
    final rounded = (value / step).round() * step;
    final result = rounded < minimum ? minimum : rounded;
    // Pas de 0,30000000000000004.
    return double.parse(result.toStringAsFixed(3));
  }

  // Au quart, au tiers ou à la demie la plus proche : ce que les cuillères
  // et les tasses permettent de mesurer.
  static double _toFraction(double value) {
    const fractions = [0.0, 0.25, 1 / 3, 0.5, 2 / 3, 0.75, 1.0];
    final whole = value.floorToDouble();
    final part = value - whole;
    var best = fractions.first;
    for (final f in fractions) {
      if ((part - f).abs() < (part - best).abs()) best = f;
    }
    final result = whole + best;
    return result < 0.25 ? 0.25 : result;
  }
}
