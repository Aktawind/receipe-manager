import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Une recette lue sur une page web, avant import : tout en texte, comme on
/// le saisirait (les ingrédients et la préparation sont ensuite analysés par
/// `IngredientText` et `StepText`).
class WebRecipe {
  const WebRecipe({
    this.source,
    this.title = '',
    this.description = '',
    this.ingredients = const [],
    this.steps = const [],
    this.imageUrl,
    this.servings,
    this.servingsUnit = '',
    this.prepMinutes,
    this.cookMinutes,
    this.totalMinutes,
    this.notes = '',
  });

  /// La page lue ; `null` pour un texte collé.
  final Uri? source;
  final String title;
  final String description;

  /// Une ligne par ingrédient ; une ligne terminée par « : » est un titre de
  /// groupe.
  final List<String> ingredients;

  /// Une étape par entrée ; « Titre : » pour un titre de partie.
  final List<String> steps;
  final Uri? imageUrl;
  final int? servings;
  final String servingsUnit;
  final int? prepMinutes;
  final int? cookMinutes;

  /// Durée totale annoncée par le site : sert de repos quand elle dépasse
  /// préparation + cuisson.
  final int? totalMinutes;

  /// Commentaires ou astuces du site, quand il y en a.
  final String notes;

  bool get isEmpty => title.isEmpty && ingredients.isEmpty && steps.isEmpty;

  /// Le temps qui n'est ni préparation ni cuisson (repos, réfrigération).
  int? get restMinutes {
    final total = totalMinutes;
    if (total == null) return null;
    final rest = total - (prepMinutes ?? 0) - (cookMinutes ?? 0);
    return rest > 0 && (prepMinutes != null || cookMinutes != null)
        ? rest
        : null;
  }
}

/// Lecture d'une page de recette. La plupart des sites publient la recette au
/// format standard schema.org/Recipe (JSON-LD, lu en premier, ou
/// microdonnées) ; sinon, [WebRecipeParser.parse] renvoie `null`.
abstract final class WebRecipeParser {
  static WebRecipe? parse(String page, Uri source) {
    final document = html.parse(page);
    return _fromJsonLd(document, source) ?? _fromMicrodata(document, source);
  }

  // --- JSON-LD ---

  static WebRecipe? _fromJsonLd(Document document, Uri source) {
    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      final Object? json;
      try {
        json = jsonDecode(script.text.trim());
      } on FormatException {
        continue;
      }
      final recipe = _findRecipe(json);
      if (recipe != null) {
        final parsed = _fromJson(recipe, source);
        if (!parsed.isEmpty) return parsed;
      }
    }
    return null;
  }

  static Map<String, Object?>? _findRecipe(Object? node) {
    if (node is List) {
      for (final item in node) {
        final found = _findRecipe(item);
        if (found != null) return found;
      }
    } else if (node is Map<String, Object?>) {
      if (_isType(node['@type'], 'Recipe')) return node;
      for (final key in const ['@graph', 'mainEntity', 'mainEntityOfPage']) {
        final found = _findRecipe(node[key]);
        if (found != null) return found;
      }
    }
    return null;
  }

  static bool _isType(Object? type, String name) =>
      type == name || (type is List && type.contains(name));

  static WebRecipe _fromJson(Map<String, Object?> json, Uri source) {
    final (servings, unit) = _yield(json['recipeYield']);
    return WebRecipe(
      source: source,
      title: _text(json['name']),
      description: _text(json['description']),
      ingredients: [
        for (final item in _list(
          json['recipeIngredient'] ?? json['ingredients'],
        ))
          if (_text(item).isNotEmpty) _text(item),
      ],
      steps: _instructions(json['recipeInstructions']),
      imageUrl: _image(json['image'], source),
      servings: servings,
      servingsUnit: unit,
      prepMinutes: _minutes(json['prepTime']),
      cookMinutes: _minutes(json['cookTime']),
      totalMinutes: _minutes(json['totalTime']),
    );
  }

  static List<Object?> _list(Object? value) => switch (value) {
    null => const [],
    List() => value,
    _ => [value],
  };

  /// Les étapes : texte, HowToStep, HowToSection (avec un titre de partie),
  /// ou une liste de tout cela.
  static List<String> _instructions(Object? value) {
    final steps = <String>[];
    void visit(Object? node) {
      if (node is String) {
        // Un seul bloc de texte : une étape par ligne (ou par paragraphe).
        for (final line in _clean(node).split(RegExp(r'\n+'))) {
          final step = line.trim();
          if (step.isNotEmpty) steps.add(step);
        }
      } else if (node is List) {
        node.forEach(visit);
      } else if (node is Map<String, Object?>) {
        if (_isType(node['@type'], 'HowToSection')) {
          final name = _text(node['name']);
          if (name.isNotEmpty) steps.add('$name :');
          visit(node['itemListElement']);
        } else if (node['itemListElement'] != null && node['text'] == null) {
          visit(node['itemListElement']);
        } else {
          final text = _text(node['text']);
          final name = _text(node['name']);
          if (text.isNotEmpty) {
            steps.add(text);
          } else if (name.isNotEmpty) {
            steps.add(name);
          }
        }
      }
    }

    visit(value);
    return steps;
  }

  static Uri? _image(Object? value, Uri source) {
    Object? first = value;
    if (first is List) first = first.isEmpty ? null : first.first;
    if (first is Map<String, Object?>) first = first['url'] ?? first['@id'];
    if (first is! String || first.trim().isEmpty) return null;
    return source.resolve(first.trim());
  }

  /// « 4 », « 4 personnes », « 12 blinis », ["4", "4 servings"].
  static (int?, String) _yield(Object? value) {
    for (final item in _list(value)) {
      final text = _text(item);
      final match = RegExp(r'(\d+)\s*(.*)').firstMatch(text);
      if (match == null) continue;
      final count = int.tryParse(match.group(1)!);
      var unit = match.group(2)!.trim().toLowerCase();
      if (RegExp(
        r'^(pers(onnes?|\.)?|portions?|parts?|servings?|people|couverts?)?$',
      ).hasMatch(unit)) {
        unit = '';
      }
      return (count, unit);
    }
    return (null, '');
  }

  /// Durée ISO 8601 (« PT1H30M », « P0DT20M », « PT90M ») en minutes.
  static int? _minutes(Object? value) {
    final text = _text(value).toUpperCase();
    final match = RegExp(
      r'^P(?:(\d+)D)?(?:T(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+)S)?)?$',
    ).firstMatch(text);
    if (match == null) return null;
    double part(int group) => double.tryParse(match.group(group) ?? '') ?? 0;
    final minutes = (part(1) * 1440 + part(2) * 60 + part(3) + part(4) / 60)
        .round();
    return minutes > 0 ? minutes : null;
  }

  static String _text(Object? value) {
    if (value is List) value = value.isEmpty ? null : value.first;
    if (value is Map<String, Object?>) value = value['text'] ?? value['name'];
    if (value is num) return '$value';
    if (value is! String) return '';
    return _clean(value).replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
  }

  /// Retire les balises et décode les entités (« &amp; », « &#39; ») : certains
  /// sites mettent du HTML dans leur JSON.
  static String _clean(String value) {
    final withBreaks = value.replaceAll(
      RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false),
      '\n',
    );
    final text = html.parseFragment(withBreaks).text ?? '';
    return text.replaceAll(' ', ' ').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  // --- Microdonnées (itemprop) ---

  static WebRecipe? _fromMicrodata(Document document, Uri source) {
    final root = document.querySelector('[itemtype*="schema.org/Recipe"]');
    if (root == null) return null;
    String prop(String name) {
      final element = root.querySelector('[itemprop="$name"]');
      if (element == null) return '';
      return _clean(element.attributes['content'] ?? element.innerHtml)
          .replaceAll(RegExp(r'\s*\n\s*'), ' ');
    }

    List<String> props(String name) => [
      for (final e in root.querySelectorAll('[itemprop="$name"]'))
        if (_clean(e.innerHtml).isNotEmpty)
          _clean(e.innerHtml).replaceAll(RegExp(r'\s*\n\s*'), ' '),
    ];

    final image = root.querySelector('[itemprop="image"]');
    final imageUrl =
        image?.attributes['src'] ??
        image?.attributes['content'] ??
        image?.attributes['href'];
    final (servings, unit) = _yield(prop('recipeYield'));
    final ingredients = props('recipeIngredient');
    final recipe = WebRecipe(
      source: source,
      title: prop('name'),
      description: prop('description'),
      ingredients: ingredients.isEmpty ? props('ingredients') : ingredients,
      steps: _instructions(
        root
            .querySelectorAll('[itemprop="recipeInstructions"]')
            .map((e) => e.innerHtml)
            .toList(),
      ),
      imageUrl: imageUrl == null ? null : source.resolve(imageUrl),
      servings: servings,
      servingsUnit: unit,
      prepMinutes: _minutes(
        root.querySelector('[itemprop="prepTime"]')?.attributes['content'],
      ),
      cookMinutes: _minutes(
        root.querySelector('[itemprop="cookTime"]')?.attributes['content'],
      ),
      totalMinutes: _minutes(
        root.querySelector('[itemprop="totalTime"]')?.attributes['content'],
      ),
    );
    return recipe.isEmpty ? null : recipe;
  }
}
