import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '../../core/format/text_search.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/label.dart';
import '../../domain/legacy_classification.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_links.dart';
import '../../domain/step_text.dart';
import '../photo_store.dart';

/// Un point d'attention remonté dans le rapport d'import.
class ImportIssue {
  const ImportIssue(this.recipeTitle, this.message);

  final String recipeTitle;
  final String message;

  @override
  String toString() => '$recipeTitle : $message';
}

/// Résultat de la lecture d'un export Recipe Keeper, sans rien écrire.
class RecipeKeeperExport {
  const RecipeKeeperExport({
    required this.recipes,
    required this.photos,
    required this.issues,
    this.labels = const [],
  });

  final List<Recipe> recipes;

  /// Les éléments de classement utilisés par les recettes (catégories,
  /// sous-catégories, saisons, collections).
  final List<Label> labels;

  /// Contenu des photos, par nom de fichier.
  final Map<String, List<int>> photos;
  final List<ImportIssue> issues;
}

/// Lecture de l'export de Recipe Keeper (Paramètres → Exporter les recettes) :
/// un ZIP qui contient `recipes.html` et un dossier `images/`.
///
/// Les identifiants de Recipe Keeper sont conservés : réimporter le même
/// fichier ne crée pas de doublons. Le format est décrit dans
/// docs/FORMAT_EXPORT.md.
abstract final class RecipeKeeperImporter {
  /// Catégorie Recipe Keeper qui sert de statut « à tester ».
  static const toTestCategory = '_A tester';

  static const _dataFile = 'recipes.html';

  /// Vrai si [archive] ressemble à un export Recipe Keeper.
  static bool looksLikeExport(Archive archive) => _find(archive) != null;

  static ArchiveFile? _find(Archive archive) {
    for (final file in archive.files) {
      if (file.isFile && p.basename(file.name) == _dataFile) return file;
    }
    return null;
  }

  static RecipeKeeperExport read(List<int> zipBytes, {DateTime? now}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } on Object {
      throw const FormatException('not a zip');
    }
    final data = _find(archive);
    if (data == null) throw const FormatException('no recipes.html');

    final images = <String, List<int>>{
      for (final file in archive.files)
        if (file.isFile && p.basename(p.dirname(file.name)) == 'images')
          p.basename(file.name): file.content,
    };
    return parse(utf8.decode(data.content), images: images, now: now);
  }

  /// Lit le HTML de l'export. [images] : photos disponibles, par nom de
  /// fichier ; seules celles qui servent à une recette sont gardées.
  static RecipeKeeperExport parse(
    String htmlText, {
    Map<String, List<int>> images = const {},
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now();
    final document = html.parse(htmlText);
    final recipes = <Recipe>[];
    final photos = <String, List<int>>{};
    final issues = <ImportIssue>[];
    final seen = <String>{};

    // Les titres de toutes les recettes : un renvoi « [recipe:Pâte brisée] »
    // dans une liste d'ingrédients devient un lien vers cette recette.
    final nodes = document.querySelectorAll('.recipe-details');
    final byTitle = <String, RecipeRef>{};
    for (final node in nodes) {
      final id = _meta(node, 'recipeId').firstOrNull?.trim();
      final title = _text(node.querySelector('[itemprop=name]'));
      if (id != null && id.isNotEmpty && title.isNotEmpty) {
        byTitle.putIfAbsent(
          normalizeForSearch(title),
          () => (id: id, title: title),
        );
      }
    }
    final titleOf = {for (final r in byTitle.values) r.id: r.title};

    final entries = <LegacyEntry>[];
    for (final node in nodes) {
      final recipe = _recipe(node, images, photos, issues, stamp, byTitle);
      if (recipe == null || !seen.add(recipe.id)) continue;
      entries.add(
        LegacyEntry(
          recipeId: recipe.id,
          course: _text(node.querySelector('span[itemprop=recipeCourse]')),
          categories: [
            for (final c in _meta(node, 'recipeCategory'))
              if (c != toTestCategory) c,
          ],
          collections: _meta(node, 'recipeCollection'),
        ),
      );
      recipes.add(
        RecipeLinks.attach(
          recipe,
          _meta(node, 'recipeLinkedRecipeId'),
          (id) => titleOf[id],
        ),
      );
    }

    // Type de plat → catégorie, catégorie → sous-catégorie, collections de
    // saisons → saisons (voir LegacyClassification).
    final plan = LegacyClassification.plan(entries, stamp);
    return RecipeKeeperExport(
      recipes: [
        for (final recipe in recipes)
          recipe.copyWith(labelIds: plan.byRecipe[recipe.id] ?? const []),
      ],
      photos: photos,
      issues: issues,
      labels: plan.labels,
    );
  }

  static Recipe? _recipe(
    Element node,
    Map<String, List<int>> images,
    Map<String, List<int>> photos,
    List<ImportIssue> issues,
    DateTime now,
    Map<String, RecipeRef> byTitle,
  ) {
    final id = _meta(node, 'recipeId').firstOrNull?.trim();
    if (id == null || id.isEmpty) return null;
    final title = _text(node.querySelector('[itemprop=name]'));
    final label = title.isEmpty ? id : title;

    // Photos : « images/<id>_0.jpg » est la principale, les suivantes viennent
    // ensuite.
    final photoNames = <String>[];
    for (final img in node.querySelectorAll('img.recipe-photos')) {
      final name = p.basename(img.attributes['src'] ?? '');
      if (name.isNotEmpty && !photoNames.contains(name)) photoNames.add(name);
    }
    if (photoNames.isEmpty) {
      final main = node.querySelector('img.recipe-photo');
      final name = p.basename(main?.attributes['src'] ?? '');
      if (name.isNotEmpty) photoNames.add(name);
    }
    final kept = <String>[];
    for (final name in photoNames) {
      if (!PhotoStore.isValidName(name)) continue;
      final bytes = images[name];
      if (bytes == null) {
        issues.add(ImportIssue(label, 'photo « $name » absente du fichier'));
      } else {
        photos[name] = bytes;
        kept.add(name);
      }
    }

    final categories = _meta(node, 'recipeCategory');
    final toTest = categories.contains(toTestCategory);

    final (servings, servingsUnit, yieldNote) = _yield(
      _text(node.querySelector('[itemprop=recipeYield]')),
    );
    final nutrition = _nutrition(node);
    final notes = [
      ?yieldNote,
      _paragraphs(node.querySelector('[itemprop=recipeNotes]')),
      ?nutrition,
    ].where((part) => part.trim().isNotEmpty).join('\n\n');

    final ingredientText = _paragraphs(
      node.querySelector('[itemprop=recipeIngredients]'),
      boldAsTitle: true,
      keepRecipeLinks: true,
    );
    final stepText = _paragraphs(
      node.querySelector('[itemprop=recipeDirections]'),
    );

    return Recipe(
      id: id,
      title: title,
      source: _text(node.querySelector('[itemprop=recipeSource]')),
      notes: notes,
      servings: servings,
      servingsUnit: servingsUnit,
      prepMinutes: _minutes(_meta(node, 'prepTime').firstOrNull),
      cookMinutes: _minutes(_meta(node, 'cookTime').firstOrNull),
      mainPhoto: kept.firstOrNull,
      extraPhotos: kept.skip(1).toList(),
      isFavorite: _meta(node, 'recipeIsFavourite').firstOrNull == 'True',
      status: toTest ? RecipeStatus.toTest : null,
      createdAt: now,
      updatedAt: now,
      ingredients: IngredientText.parseList(
        ingredientText,
        resolveRecipe: (title) => byTitle[normalizeForSearch(title)],
      ),
      steps: StepText.parse(stepText),
    );
  }

  static List<String> _meta(Element node, String itemprop) => [
    for (final meta in node.querySelectorAll('meta[itemprop=$itemprop]'))
      if ((meta.attributes['content'] ?? '').trim().isNotEmpty)
        meta.attributes['content']!.trim(),
  ];

  /// Texte d'un élément, espaces normalisés. Les renvois « [recipe:Pâte] » de
  /// Recipe Keeper deviennent le simple nom de la recette, ou « [[Pâte]] » avec
  /// [keepRecipeLinks] (lien dans une liste d'ingrédients).
  static String _text(Element? element, {bool keepRecipeLinks = false}) =>
      (element?.text ?? '')
          .replaceAllMapped(
            RegExp(r'\[recipe:([^\]]+)\]'),
            (m) => keepRecipeLinks ? '[[${m.group(1)}]]' : m.group(1)!,
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  /// Un paragraphe par ligne. Un paragraphe entièrement en gras est un titre
  /// de groupe (« **Pour la pâte** ») : il est réécrit pour que l'analyse des
  /// ingrédients le reconnaisse.
  static String _paragraphs(
    Element? container, {
    bool boldAsTitle = false,
    bool keepRecipeLinks = false,
  }) {
    if (container == null) return '';
    final lines = <String>[];
    for (final paragraph in container.querySelectorAll('p')) {
      final text = _text(paragraph, keepRecipeLinks: keepRecipeLinks);
      if (text.isEmpty) {
        // Ligne vide de l'export : on la garde entre deux blocs de texte.
        if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
        continue;
      }
      final boldText = _text(paragraph.querySelector('b'));
      final allBold =
          boldAsTitle &&
          paragraph.querySelectorAll('b').isNotEmpty &&
          paragraph.nodes.every(
            (n) => n is Element ? n.localName == 'b' : n.text!.trim().isEmpty,
          );
      lines.add(allBold && boldText.isNotEmpty ? '**$text**' : text);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

  /// « 4 personnes » → 4 ; « 12 blinis » → 12 avec l'unité « blinis ». Un texte
  /// sans nombre (« Une dizaine ») est gardé dans les notes.
  static (int?, String, String?) _yield(String text) {
    if (text.isEmpty) return (null, '', null);
    final match = RegExp(r'^(\d+)\s*(.*)$').firstMatch(text);
    if (match == null) return (null, '', 'Quantité : $text');
    final count = int.parse(match.group(1)!);
    final unit = match.group(2)!.trim();
    final people = RegExp(
      r'^(personne|portion|part|pers)',
      caseSensitive: false,
    );
    return (count, people.hasMatch(unit) ? '' : unit, null);
  }

  /// « PT1H15M » → 75 ; « PT0S » → `null`.
  static int? _minutes(String? iso) {
    if (iso == null) return null;
    final match = RegExp(r'^PT(?:(\d+)H)?(?:(\d+)M)?(?:\d+S)?$')
        .firstMatch(iso);
    if (match == null) return null;
    final total =
        int.parse(match.group(1) ?? '0') * 60 +
        int.parse(match.group(2) ?? '0');
    return total == 0 ? null : total;
  }

  static const _nutritionLabels = {
    'recipeNutServingSize': 'Portion',
    'recipeNutCalories': 'Calories',
    'recipeNutTotalFat': 'Lipides',
    'recipeNutSaturatedFat': 'dont saturés',
    'recipeNutCholesterol': 'Cholestérol',
    'recipeNutSodium': 'Sodium',
    'recipeNutTotalCarbohydrate': 'Glucides',
    'recipeNutSugars': 'dont sucres',
    'recipeNutDietaryFiber': 'Fibres',
    'recipeNutProtein': 'Protéines',
  };

  /// Les valeurs nutritionnelles (rares) sont gardées en texte dans les notes
  /// pour ne rien perdre.
  static String? _nutrition(Element node) {
    final parts = [
      for (final entry in _nutritionLabels.entries)
        if (_meta(node, entry.key).firstOrNull case final value?)
          '${entry.value} : $value',
    ];
    return parts.isEmpty
        ? null
        : 'Valeurs nutritionnelles — ${parts.join(' · ')}';
  }
}
