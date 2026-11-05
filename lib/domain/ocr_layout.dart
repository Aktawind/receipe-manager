import 'dart:math' as math;

import '../core/format/text_search.dart';
import 'ingredient_text.dart';
import 'ocr_text.dart';
import 'step_durations.dart';

/// Une ligne lue sur une page, avec sa place (page remise droite).
class OcrLine {
  const OcrLine(
    this.text, {
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.block = 0,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;

  /// Le bloc (paragraphe, légende) auquel la lecture l'a rattachée.
  final int block;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;

  OcrLine copyWith({String? text, int? block}) => OcrLine(
    text ?? this.text,
    left: left,
    top: top,
    width: width,
    height: height,
    block: block ?? this.block,
  );

  @override
  String toString() => 'OcrLine($text @ $left,$top ${width}x$height #$block)';
}

/// Une ligne telle que la lecture la donne : les quatre coins (dans l'ordre
/// haut-gauche, haut-droite, bas-droite, bas-gauche du texte) et l'angle.
class RawOcrLine {
  const RawOcrLine(
    this.text,
    this.corners, {
    this.angle,
    this.block = 0,
    this.confidence,
  });

  final String text;
  final List<({double x, double y})> corners;
  final double? angle;
  final int block;

  /// L'assurance de la lecture (0 à 1), quand elle est connue.
  final double? confidence;
}

/// Reconstitue une recette à partir des lignes lues sur des pages de livre :
/// page remise droite, titre (le plus gros texte), colonnes, légendes des
/// photos rapprochées de leur quantité, informations (personnes, temps),
/// ingrédients, étapes et astuces. Le résultat est un texte structuré,
/// corrigeable, que lit ensuite `TextRecipeParser`.
abstract final class OcrLayout {
  /// Les lignes dans le sens de la lecture : si la page est tournée (sur le
  /// côté, à l'envers), les coins sont tournés de l'angle médian des lignes.
  static List<OcrLine> upright(List<RawOcrLine> lines) {
    final angles = [
      for (final l in lines)
        if (l.angle != null) l.angle!,
    ]..sort();
    final angle = angles.isEmpty ? 0.0 : angles[angles.length ~/ 2];
    final radians = -angle * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return [
      for (final line in lines)
        if (line.corners.isNotEmpty)
          () {
            final xs = <double>[];
            final ys = <double>[];
            for (final p in line.corners) {
              xs.add(p.x * cos - p.y * sin);
              ys.add(p.x * sin + p.y * cos);
            }
            final left = xs.reduce(math.min);
            final top = ys.reduce(math.min);
            return OcrLine(
              line.text,
              left: left,
              top: top,
              width: xs.reduce(math.max) - left,
              height: ys.reduce(math.max) - top,
              block: line.block,
            );
          }(),
    ];
  }

  /// Le texte d'une recette, à partir des pages (une liste de lignes par
  /// page, dans l'ordre des pages).
  static String recipeText(List<List<OcrLine>> pages) {
    final recipe = _Recipe();
    for (final page in pages) {
      _Page(page, recipe).read();
    }
    return recipe.render();
  }
}

class _Recipe {
  String title = '';
  final info = <String>[];
  final ingredients = <String>[];
  final steps = <String>[];
  final notes = <String>[];

  String render() {
    final out = StringBuffer();
    if (title.isNotEmpty) out.writeln('# $title');
    if (info.isNotEmpty) out.writeln();
    for (final line in info) {
      out.writeln(line);
    }
    if (ingredients.isNotEmpty) {
      out.writeln('\n## Ingrédients');
      for (final item in ingredients) {
        out.writeln(item.endsWith(':') ? '\n$item' : '- $item');
      }
    }
    if (steps.isNotEmpty) {
      out.writeln('\n## Préparation');
      for (final (index, step) in steps.indexed) {
        out.writeln('${index + 1}. $step');
      }
    }
    if (notes.isNotEmpty) {
      out.writeln('\n## Astuces');
      for (final note in notes) {
        out.writeln(note);
      }
    }
    return out.toString().trim();
  }
}

enum _Kind { info, ingredient, step, note, ignore }

/// Un bloc de lignes (paragraphe, liste, légende) et ce qu'il contient.
class _Block {
  _Block(this.lines);

  final List<OcrLine> lines;

  double get left => lines.map((l) => l.left).reduce(math.min);
  double get top => lines.map((l) => l.top).reduce(math.min);
  double get right => lines.map((l) => l.right).reduce(math.max);
  double get bottom => lines.map((l) => l.bottom).reduce(math.max);

  /// Numéro d'étape lu à côté du bloc (gros chiffre, pastille).
  int? number;
}

class _Page {
  _Page(List<OcrLine> lines, this.recipe)
    : lines = [
        for (final l in lines)
          if (_clean(l.text).isNotEmpty) l.copyWith(text: _clean(l.text)),
      ];

  final List<OcrLine> lines;
  final _Recipe recipe;

  /// Hauteur typique d'une ligne de texte courant.
  late final double h;

  /// Les chiffres seuls (numéros d'étapes, quantités de légendes).
  final markers = <OcrLine>[];

  void read() {
    if (lines.isEmpty) return;
    final heights = lines.map((l) => l.height).toList()..sort();
    h = math.max(1, heights[heights.length ~/ 2]);
    final pageTop = lines.map((l) => l.top).reduce(math.min);
    final pageBottom = lines.map((l) => l.bottom).reduce(math.max);
    final span = math.max(1.0, pageBottom - pageTop);

    // 1. Titre : le plus gros texte, en haut de la page.
    _takeTitle();

    // 2. Bruit : numéros de page, rubriques du livre en haut ou en bas,
    //    symboles, prix ; chiffres seuls mis de côté.
    lines.removeWhere((l) {
      final n = normalizeForSearch(l.text);
      final inMargin =
          l.top < pageTop + span * 0.07 || l.bottom > pageBottom - span * 0.07;
      if (RegExp(r'^\d{1,2}$').hasMatch(l.text)) {
        if (!inMargin) markers.add(l);
        return true;
      }
      if (RegExp(r'^(page\s*)?\d{1,4}$').hasMatch(n)) return true;
      if (!RegExp(r'[a-z]').hasMatch(n) && !_isDurations(l.text)) return true;
      if (l.text.length <= 2 && !RegExp(r'\d').hasMatch(l.text)) return true;
      if (RegExp(r'^[€$£\s]+$').hasMatch(l.text) || n.contains('kcal')) {
        return true;
      }
      if (inMargin &&
          lines.where((o) => o.block == l.block).length == 1 &&
          l.height < h * 1.3 &&
          !RegExp(r'\d').hasMatch(l.text) &&
          _headingOf(l.text) == null &&
          l.text.split(' ').length <= 4) {
        return true;
      }
      return false;
    });

    // 3. Légendes de photos : « escalope de dinde » + « 800 g ».
    _pairCaptions();

    // 4. Blocs dans l'ordre de lecture (colonnes, puis de haut en bas).
    final blocks = _order(_blocks());
    _numberSteps(blocks);

    // 5. Ce que dit chaque bloc.
    _classify(blocks);
  }

  // --- Titre ---

  void _takeTitle() {
    if (recipe.title.isNotEmpty) return;
    final big = [
      for (final l in lines)
        if (l.height >= h * 1.6 &&
            RegExp(r'\p{L}{2}', unicode: true).hasMatch(l.text) &&
            !RegExp(r'\d').hasMatch(l.text))
          l,
    ]..sort((a, b) => a.top.compareTo(b.top));
    if (big.isEmpty) return;
    final title = <OcrLine>[big.first];
    for (final l in big.skip(1)) {
      final previous = title.last;
      if (l.top - previous.bottom < previous.height * 1.2) title.add(l);
    }
    lines.removeWhere(title.contains);
    final words = [
      for (final part in title)
        part.text == part.text.toUpperCase()
            ? part.text.toLowerCase()
            : part.text,
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (words.isEmpty) return;
    recipe.title = words[0].toUpperCase() + words.substring(1);
  }

  // --- Légendes ---

  static final _unitWords = {
    for (final variants in IngredientText.units.values)
      for (final v in variants) normalizeForSearch(v),
    'boule',
    'boules',
    'tete',
    'tetes',
    'paquet',
    'paquets',
    'tablette',
    'tablettes',
    'louche',
    'louches',
    'cuillere',
    'cuilleres',
    'cuilleree',
    'cuillerees',
    'c',
    'grosse',
    'grosses',
    'petite',
    'petites',
    'belle',
    'belles',
  };

  /// « 800 g », « × 2 brins », « x 4 (petites et aplaties) », « 1/2 bouquet »,
  /// « 4 tranches (fines) », « 4 » : une quantité seule, sans ingrédient.
  static bool _isQuantity(String text) {
    final t = text.trim();
    final m = RegExp(r'^[x×]?\s*(\d+(?:[.,/]\d+)?|½|¼|¾)\s*(.*?)\s*(\(.*\))?$')
        .firstMatch(t);
    if (m == null || t.length > 40) return false;
    final rest = normalizeForSearch(m.group(2)!).trim();
    if (rest.isEmpty) return true;
    if (_isDurations(t) || _isInfo(t)) return false;
    final words = rest.split(RegExp(r'\s+'));
    return words.length <= 4 && _unitWords.contains(words.first);
  }

  /// La légende sous (ou sur) une photo : le nom à côté de sa quantité.
  void _pairCaptions() {
    final quantities = [...lines.where((l) => _isQuantity(l.text)), ...markers];
    for (final q in quantities) {
      OcrLine? best;
      var bestGap = double.infinity;
      for (final l in lines) {
        if (identical(l, q) || _isQuantity(l.text)) continue;
        if (_startsWithQuantity(l.text) || l.text.length > 40) continue;
        if (_headingOf(l.text) != null || _isInfo(l.text)) continue;
        final width = math.max(l.width, q.width);
        if ((l.centerX - q.centerX).abs() > width * 0.6) continue;
        final gap = l.top > q.top ? l.top - q.bottom : q.top - l.bottom;
        if (gap < -h * 0.5 || gap > h * 2.5) continue;
        if (gap < bestGap) {
          bestGap = gap;
          best = l;
        }
      }
      final found = best;
      if (found == null) continue;
      // Une légende sur deux lignes (« Escalopes de veau » / « fines ») : les
      // lignes du même bloc, collées au-dessus et au-dessous.
      bool fits(OcrLine l) =>
          !identical(l, q) &&
          l.block == found.block &&
          l.text.length <= 40 &&
          !_isQuantity(l.text) &&
          !_startsWithQuantity(l.text);
      final chain = [found];
      for (var grew = true; grew && chain.length < 3;) {
        grew = false;
        for (final l in lines) {
          if (chain.contains(l) || !fits(l)) continue;
          final above = chain.first.top - l.bottom;
          final below = l.top - chain.last.bottom;
          if (above >= -h * 0.3 && above < h * 0.8) {
            chain.insert(0, l);
          } else if (below >= -h * 0.3 && below < h * 0.8) {
            chain.add(l);
          } else {
            continue;
          }
          grew = true;
          break;
        }
      }
      final name = chain.first;
      final fullName = [for (final l in chain) l.text].join(' ');
      lines.removeWhere((l) => chain.skip(1).contains(l));
      final index = lines.indexOf(name);
      lines[index] = name.copyWith(text: _withQuantity(fullName, q.text));
      lines.remove(q);
      markers.remove(q);
    }
  }

  /// « 4 Escalopes de veau (petites et aplaties) » à partir du nom et de la
  /// quantité « x 4 (petites et aplaties) ».
  static String _withQuantity(String name, String quantity) {
    final m = RegExp(r'^[x×]?\s*(.*?)\s*(\(.*\))?$')
        .firstMatch(quantity.trim())!;
    final note = m.group(2);
    return [m.group(1)!, name, ?note].join(' ').trim();
  }

  // --- Blocs et ordre de lecture ---

  List<_Block> _blocks() {
    final byId = <int, List<OcrLine>>{};
    for (final l in lines) {
      byId.putIfAbsent(l.block, () => []).add(l);
    }
    final blocks = <_Block>[];
    for (final group in byId.values) {
      group.sort((a, b) => a.top.compareTo(b.top));
      // Un bloc qui réunit deux colonnes (la lecture le fait parfois) est
      // coupé là où les lignes ne se chevauchent plus.
      var current = <OcrLine>[group.first];
      for (final l in group.skip(1)) {
        final previous = current.last;
        final overlap =
            math.min(previous.right, l.right) - math.max(previous.left, l.left);
        final gap = l.top - previous.bottom;
        if (overlap < 0 || gap > h * 1.6) {
          blocks.add(_Block(current));
          current = [l];
        } else {
          current.add(l);
        }
      }
      blocks.add(_Block(current));
    }
    return blocks;
  }

  /// Découpe récursive de la page (« XY-cut ») : d'abord en colonnes séparées
  /// par un blanc vertical, sinon en bandes séparées par un blanc horizontal.
  List<_Block> _order(List<_Block> blocks) {
    if (blocks.length <= 1) return blocks;
    // Colonnes.
    final byLeft = [...blocks]..sort((a, b) => a.left.compareTo(b.left));
    var reach = byLeft.first.right;
    for (var i = 1; i < byLeft.length; i++) {
      if (byLeft[i].left > reach + h * 0.8) {
        return [..._order(byLeft.sublist(0, i)), ..._order(byLeft.sublist(i))];
      }
      reach = math.max(reach, byLeft[i].right);
    }
    // Bandes.
    final byTop = [...blocks]..sort((a, b) => a.top.compareTo(b.top));
    var bottom = byTop.first.bottom;
    for (var i = 1; i < byTop.length; i++) {
      if (byTop[i].top > bottom - h * 0.2) {
        return [..._order(byTop.sublist(0, i)), ..._order(byTop.sublist(i))];
      }
      bottom = math.max(bottom, byTop[i].bottom);
    }
    return byTop;
  }

  /// Les gros chiffres et pastilles posés à gauche d'une étape.
  void _numberSteps(List<_Block> blocks) {
    for (final marker in markers) {
      _Block? best;
      var bestDistance = double.infinity;
      for (final b in blocks) {
        if (b.left < marker.left - h) continue;
        final dy = (b.top - marker.top).abs();
        final dx = b.left - marker.right;
        if (dy > h * 2 || dx > h * 4) continue;
        final distance = dx.abs() + dy;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = b;
        }
      }
      best?.number ??= int.parse(marker.text);
    }
  }

  // --- Ce que dit chaque bloc ---

  void _classify(List<_Block> blocks) {
    var section = _Kind.ignore;
    final unlabeled = <Duration>[];
    var labeledTimes = false;
    final steps = <(int?, String)>[];

    for (final block in blocks) {
      final rest = <OcrLine>[];
      for (var i = 0; i < block.lines.length; i++) {
        final text = block.lines[i].text;
        final next = i + 1 < block.lines.length
            ? block.lines[i + 1].text
            : null;
        // « Préparation » puis « 10 MIN » : une information.
        if (_isTimeLabel(text) && next != null && _isDurations(next)) {
          recipe.info.add('$text : $next');
          labeledTimes = true;
          i++;
          continue;
        }
        if (_isInfo(text)) {
          recipe.info.add(text);
          if (StepDurations.find(normalizeForSearch(text)).isNotEmpty) {
            labeledTimes = true;
          }
          continue;
        }
        if (_isDurations(text)) {
          final servings = RegExp(r'^\s*(\d{1,2})\s').firstMatch(text);
          if (servings != null) {
            recipe.info.add('Pour ${servings.group(1)} personnes');
          }
          unlabeled.addAll(StepDurations.find(normalizeForSearch(text)));
          continue;
        }
        final heading = _headingOf(text);
        if (heading != null) {
          section = heading.$1;
          if (heading.$2 case final group?) recipe.ingredients.add(group);
          continue;
        }
        rest.add(block.lines[i]);
      }
      if (rest.isEmpty) continue;

      final kind = _kindOf(rest, section);
      switch (kind) {
        case _Kind.ingredient:
          section = _Kind.ingredient;
          recipe.ingredients.addAll(_ingredients(rest));
        case _Kind.step:
          section = _Kind.step;
          for (final (n, text) in _steps(rest)) {
            steps.add((n ?? (steps.isEmpty ? block.number : null), text));
          }
        case _Kind.note:
          section = _Kind.note;
          recipe.notes.add(_join(rest));
        case _Kind.info:
        case _Kind.ignore:
          break;
      }
    }

    // Temps sans libellé (icônes) : préparation, cuisson, repos, dans l'ordre.
    if (!labeledTimes && unlabeled.isNotEmpty) {
      const labels = ['Préparation', 'Cuisson', 'Repos'];
      for (final (i, d) in unlabeled.take(3).indexed) {
        recipe.info.add('${labels[i]} : ${d.inMinutes} min');
      }
    }

    // Étapes numérotées (sur deux colonnes, par exemple) : dans l'ordre.
    final numbered = steps.where((s) => s.$1 != null).length;
    final ordered = [...steps.indexed];
    if (numbered >= 2 && numbered >= steps.length * 0.6) {
      ordered.sort((a, b) {
        final na = a.$2.$1 ?? 1000 + a.$1;
        final nb = b.$2.$1 ?? 1000 + b.$1;
        return na.compareTo(nb);
      });
    }
    recipe.steps.addAll([for (final (_, s) in ordered) s.$2]);
  }

  _Kind _kindOf(List<OcrLine> block, _Kind section) {
    final text = _join(block);
    final first = normalizeForSearch(block.first.text);
    if (RegExp(
      r'^(astuce|conseil|le petit plus|petit plus|variante|bon a savoir|vous pouvez|mon conseil|notre conseil)\b',
    ).hasMatch(first)) {
      return _Kind.note;
    }
    // « 3 œufs + 150 g de sucre + … » : une liste d'ingrédients en une phrase.
    if (RegExp(r'\d[^+]*\+\s*\d').hasMatch(text)) return _Kind.ingredient;
    // Rubrique du livre, nom de chapitre (« DESSERTS », « LES BASES »).
    if (text.length <= 40 &&
        !RegExp(r'\d').hasMatch(text) &&
        text == text.toUpperCase() &&
        RegExp(r'\p{L}', unicode: true).hasMatch(text)) {
      return _Kind.ignore;
    }
    final sentence =
        RegExp(r'[.!]$').hasMatch(text.trim()) ||
        text.length > 110 ||
        _startsWithVerb(block.first.text) ||
        _isNumberedStep(block.first.text);
    final listy = block.every((l) => l.text.length <= 55);
    final quantities = block
        .where(
          (l) =>
              (_startsWithQuantity(l.text) && !_isNumberedStep(l.text)) ||
              _endsWithQuantity(l.text) ||
              l.text.contains(' + '),
        )
        .length;
    if (sentence && !(listy && quantities >= block.length / 2)) {
      return section == _Kind.note ? _Kind.note : _Kind.step;
    }
    if (quantities > 0 || text.contains(' + ')) return _Kind.ingredient;
    if (section == _Kind.ingredient && listy) return _Kind.ingredient;
    if (section == _Kind.note) return _Kind.note;
    // « Sel, poivre », « sel et poivre » : un ingrédient sans quantité.
    if (listy &&
        RegExp(r'^(sel|poivre|huile|beurre|eau|sucre)\b').hasMatch(first)) {
      return _Kind.ingredient;
    }
    if (listy && block.length >= 2 && section == _Kind.ingredient) {
      return _Kind.ingredient;
    }
    return listy ? _Kind.ignore : _Kind.step;
  }

  /// Les ingrédients d'un bloc : une ligne chacun, sauf la suite d'une ligne
  /// coupée (« 1 c. à café de piment doux » + « moulu ») et les listes en
  /// une phrase (« 3 œufs + 150 g de sucre + … »).
  List<String> _ingredients(List<OcrLine> block) {
    // Une liste en une phrase, coupée par la largeur de la page.
    if (block.length > 1 && block.any((l) => l.text.contains('+'))) {
      block = [block.first.copyWith(text: _join(block))];
    }
    final items = <String>[];
    for (final l in block) {
      final text = _stripBullet(l.text);
      if (RegExp(r'^et aussi\b').hasMatch(normalizeForSearch(text))) continue;
      final continues =
          items.isNotEmpty &&
          !_startsWithQuantity(text) &&
          RegExp(
            r"^(de|d'|d’|du|des|en|à|au|aux|ou|moulu|moulus|haché|hachée|hachés|hachées|ciselé|ciselés|finement|non|bien|frais|fraîche|coupé|coupée|coupés|émincé|émincée|épluché|épluchée|pelé|pelés|fondu|ramolli|râpé|râpée|\()",
            caseSensitive: false,
          ).hasMatch(text) &&
          !items.last.endsWith(':');
      if (continues ||
          (items.isNotEmpty && items.last.trimRight().endsWith('+'))) {
        items[items.length - 1] = '${items.last} $text';
      } else if (items.isNotEmpty && text.startsWith('+')) {
        items[items.length - 1] = '${items.last} $text';
      } else {
        items.add(text);
      }
    }
    return [
      for (final item in items)
        for (final part in item.split(RegExp(r'\s*\+\s*')))
          if (part.trim().isNotEmpty) _normalizeIngredient(part.trim()),
    ];
  }

  /// « romarin × 2 brins » → « 2 brins romarin » ; « Jambon cru 4 tranches
  /// (fines) » → « 4 tranches Jambon cru (fines) » ; « oignon × 1 » → « 1 oignon ».
  static String _normalizeIngredient(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ');
    final trailing = RegExp(
      r'^(.*?\p{L}.*?)\s+[x×]?\s*(\d+(?:[.,/]\d+)?|½|¼|¾)\s*([\p{L}.]+(?:\s(?:à|a)\s(?:soupe|café|cafe))?)?\s*(\(.*\))?$',
      unicode: true,
    ).firstMatch(t);
    if (trailing != null && !_startsWithQuantity(t)) {
      final unit = trailing.group(3);
      final unitOk =
          unit == null || _unitWords.contains(normalizeForSearch(unit));
      if (unitOk) {
        t = [
          trailing.group(2)!,
          ?unit,
          trailing.group(1)!,
          ?trailing.group(4),
        ].join(' ');
      }
    }
    return t.replaceFirst(RegExp(r'^[x×]\s*(?=\d)'), '');
  }

  /// Les étapes d'un bloc : une par paragraphe, ou une par numéro.
  List<(int?, String)> _steps(List<OcrLine> block) {
    final result = <(int?, String)>[];
    int? number;
    final current = <OcrLine>[];
    void flush() {
      if (current.isEmpty) return;
      result.add((number, _join(current)));
      current.clear();
    }

    for (final l in block) {
      final m = RegExp(
        r'^(?:étape\s*)?(\d{1,2})(?:\s*[.)\-–]\s*|\s+(?=\p{Lu}))(?=\p{L})',
        unicode: true,
        caseSensitive: false,
      ).firstMatch(l.text);
      if (m != null) {
        flush();
        number = int.parse(m.group(1)!);
        current.add(l.copyWith(text: l.text.substring(m.end)));
      } else {
        current.add(l.copyWith(text: _stripBullet(l.text)));
      }
    }
    flush();
    return result;
  }

  /// Les lignes d'un bloc en un paragraphe (mots coupés recollés).
  static String _join(List<OcrLine> block) {
    final out = StringBuffer();
    for (final l in block) {
      final text = l.text.trim();
      final s = out.toString();
      if (s.isEmpty) {
        out.write(text);
      } else if (RegExp(r'\p{Ll}-$', unicode: true).hasMatch(s) &&
          RegExp(r'^\p{Ll}', unicode: true).hasMatch(text)) {
        out
          ..clear()
          ..write(s.substring(0, s.length - 1))
          ..write(text);
      } else {
        out.write(' $text');
      }
    }
    return out.toString();
  }

  // --- Reconnaissance des lignes ---

  static String _clean(String text) {
    var t = OcrText.fixLine(
      text.trim().replaceFirst(RegExp(r'^[@©®◎⊙●*]+\s*'), ''),
    ).replaceAll(RegExp(r'\s+'), ' ');
    // « 5' » (minutes) des pictogrammes de temps.
    t = t.replaceAllMapped(
      RegExp(r"(\d+)\s?['’′]"),
      (m) => '${m.group(1)} min',
    );
    // « 1 . Mélanger » → « 1. Mélanger ».
    t = t.replaceFirstMapped(
      RegExp(r'^(\d{1,2})\s+\.\s+'),
      (m) => '${m.group(1)}. ',
    );
    return t.trim();
  }

  static String _stripBullet(String text) => text
      .replaceFirst(
        RegExp(r'^(?:[-*•·▪◦○●➤►✓]|[oO](?=\s+\p{Lu}))\s*', unicode: true),
        '',
      )
      .trim();

  static bool _startsWithQuantity(String text) => RegExp(
    r'^(?:[-*•·]\s*)?[x×]?\s*(\d|½|¼|¾|une?\s)',
    caseSensitive: false,
  ).hasMatch(text.trim());

  /// « 1. Émincez », « 2) Ajoutez », « 3 Versez » : un numéro d'étape.
  static bool _isNumberedStep(String text) {
    final t = text.trim();
    if (RegExp(r'^\d{1,2}\s*[.)]\s*\p{Lu}', unicode: true).hasMatch(t)) {
      return true;
    }
    final m = RegExp(r'^\d{1,2}\s+(?=\p{Lu})', unicode: true).firstMatch(t);
    return m != null && _startsWithVerb(t.substring(m.end));
  }

  static bool _endsWithQuantity(String text) =>
      !_startsWithQuantity(text) &&
      !RegExp(
        r'\d\s*(min(utes?)?|mn|h|heures?|°c?)\.?$',
        caseSensitive: false,
      ).hasMatch(text.trim()) &&
      RegExp(
        r'\p{L}.*\s[x×]?\s*\d+(?:[.,/]\d+)?\s*(\p{L}+\.?(\s(à|a)\s(soupe|café))?)?\s*(\(.*\))?$',
        unicode: true,
      ).hasMatch(text.trim()) &&
      text.length <= 55;

  /// Uniquement des durées (pictogrammes) : « 20 MIN 15 MIN 30 MIN ».
  static bool _isDurations(String text) {
    final n = normalizeForSearch(text);
    if (StepDurations.find(n).isEmpty) return false;
    final rest = n
        .replaceAll(RegExp(r'\d+\s*(h|heures?|min(utes?)?|mn|s)\b'), '')
        .replaceAll(RegExp(r'[^a-z]'), '');
    return rest.length <= 3;
  }

  static bool _isTimeLabel(String text) => RegExp(
    r'^(preparation|cuisson|repos|refrigeration|temps total|total)\s*:?$',
  ).hasMatch(normalizeForSearch(text).trim());

  /// Personnes, temps : « POUR 4 PERSONNES », « PRÉPARATION : 15 MIN »,
  /// « prêt en 10 minutes », « 10 minutes de cuisson », « 4 pers. ».
  static bool _isInfo(String text) {
    final n = normalizeForSearch(text);
    if (text.length > 90 ||
        RegExp(r'\.\s+\p{Lu}', unicode: true).hasMatch(text)) {
      return false;
    }
    if (!RegExp(r'\d').hasMatch(n)) return false;
    return RegExp(
      r'^(pour\s+(environ\s+)?\d|\d+\s*(personnes?|pers\b|parts?\b|portions?)|portions?\s*:|preparation\s*:?\s*\d|cuisson\s*:?\s*\d|repos|refrigeration|temps|pret en|quantite|\d+\s*min(utes)? de (cuisson|preparation|repos))',
    ).hasMatch(n.trim());
  }

  /// Une rubrique : (section, titre de groupe d'ingrédients éventuel).
  static (_Kind, String?)? _headingOf(String text) {
    final n = normalizeForSearch(text).replaceAll(RegExp(r'[:!.]'), '').trim();
    if (n.split(' ').length > 6 ||
        RegExp(r'\d').hasMatch(text.split('(').first)) {
      // « Ingrédients pour 1,5 litre de bouillon » reste une rubrique.
      if (!n.startsWith('ingredients')) return null;
    }
    if (RegExp(r'^(les )?ingredients\b').hasMatch(n)) {
      return (_Kind.ingredient, null);
    }
    if (RegExp(r'^et aussi$').hasMatch(n)) return (_Kind.ingredient, null);
    if (RegExp(r'^(preparation|realisation|etapes|recette|deroulement)$')
        .hasMatch(n)) {
      return (_Kind.step, null);
    }
    if (RegExp(r'^(astuces?|conseils?|variantes?|le petit plus|bon a savoir)\b')
        .hasMatch(n)) {
      return (_Kind.note, null);
    }
    // « POUR LA MARINADE », « Pour la pâte : » : un groupe d'ingrédients.
    final group = RegExp(r"^pour (la|le|les|l |un|une) .{2,30}$").firstMatch(n);
    if (group != null && !RegExp(r'\d').hasMatch(n)) {
      final label = text.replaceFirst(RegExp(r'\s*:\s*$'), '');
      final pretty = label == label.toUpperCase()
          ? label[0] + label.substring(1).toLowerCase()
          : label;
      return (_Kind.ingredient, '$pretty :');
    }
    return null;
  }

  static const _verbs = {
    'prechauffez',
    'prechauffer',
    'melangez',
    'melanger',
    'ajoutez',
    'ajouter',
    'faites',
    'faire',
    'versez',
    'verser',
    'coupez',
    'couper',
    'epluchez',
    'eplucher',
    'battez',
    'battre',
    'laissez',
    'laisser',
    'incorporez',
    'incorporer',
    'etalez',
    'etaler',
    'cassez',
    'casser',
    'portez',
    'porter',
    'disposez',
    'disposer',
    'posez',
    'poser',
    'placez',
    'placer',
    'sortez',
    'sortir',
    'retirez',
    'retirer',
    'abaissez',
    'baisser',
    'servez',
    'servir',
    'dressez',
    'dresser',
    'saupoudrez',
    'saupoudrer',
    'parsemez',
    'parsemer',
    'decalez',
    'hachez',
    'hacher',
    'emincez',
    'emincer',
    'colorer',
    'colorez',
    'cuire',
    'enfournez',
    'enfourner',
    'reservez',
    'reserver',
    'repliez',
    'replier',
    'dorer',
    'dorez',
    'garnir',
    'garnissez',
    'filtrez',
    'filtrer',
    'pelez',
    'peler',
    'rincez',
    'rincer',
    'taillez',
    'tailler',
    'assaisonnez',
    'roulez',
    'rouler',
    'separez',
    'separer',
    'egouttez',
    'egoutter',
    'chauffez',
    'chauffer',
    'fouettez',
    'fouetter',
    'mixez',
    'mixer',
    'salez',
    'saler',
    'poivrez',
    'poivrer',
    'preparez',
    'preparer',
    'pendant',
    'dans',
    'quand',
    'lorsque',
  };

  static bool _startsWithVerb(String text) {
    final first = normalizeForSearch(_stripBullet(text))
        .split(RegExp(r"[\s,']"))
        .first;
    return _verbs.contains(first);
  }
}
