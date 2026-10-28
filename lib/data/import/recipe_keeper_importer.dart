import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;

import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
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
  });

  final List<Recipe> recipes;

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

    for (final node in document.querySelectorAll('.recipe-details')) {
      final recipe = _recipe(node, images, photos, issues, stamp);
      if (recipe == null || !seen.add(recipe.id)) continue;
      recipes.add(recipe);
    }
    return RecipeKeeperExport(recipes: recipes, photos: photos, issues: issues);
  }

  static Recipe? _recipe(
    Element node,
    Map<String, List<int>> images,
    Map<String, List<int>> photos,
    List<ImportIssue> issues,
    DateTime now,
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
    final category = categories.where((c) => c != toTestCategory).join(', ');

    final (servings, yieldNote) = _yield(
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
    );
    final stepText = _paragraphs(
      node.querySelector('[itemprop=recipeDirections]'),
    );

    final linked = _meta(node, 'recipeLinkedRecipeId');

    return Recipe(
      id: id,
      title: title,
      source: _text(node.querySelector('[itemprop=recipeSource]')),
      notes: notes,
      servings: servings,
      prepMinutes: _minutes(_meta(node, 'prepTime').firstOrNull),
      cookMinutes: _minutes(_meta(node, 'cookTime').firstOrNull),
      mainPhoto: kept.firstOrNull,
      extraPhotos: kept.skip(1).toList(),
      isFavorite: _meta(node, 'recipeIsFavourite').firstOrNull == 'True',
      status: toTest ? RecipeStatus.toTest : null,
      course: _text(node.querySelector('span[itemprop=recipeCourse]')),
      category: category,
      collections: _meta(node, 'recipeCollection'),
      linkedRecipeIds: linked,
      createdAt: now,
      updatedAt: now,
      ingredients: IngredientText.parseList(ingredientText),
      steps: StepText.parse(stepText),
    );
  }

  static List<String> _meta(Element node, String itemprop) => [
    for (final meta in node.querySelectorAll('meta[itemprop=$itemprop]'))
      if ((meta.attributes['content'] ?? '').trim().isNotEmpty)
        meta.attributes['content']!.trim(),
  ];

  /// Texte d'un élément, espaces normalisés. Les renvois « [recipe:Pâte] » de
  /// Recipe Keeper deviennent le simple nom de la recette.
  static String _text(Element? element) => (element?.text ?? '')
      .replaceAllMapped(RegExp(r'\[recipe:([^\]]+)\]'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Un paragraphe par ligne. Un paragraphe entièrement en gras est un titre
  /// de groupe (« **Pour la pâte** ») : il est réécrit pour que l'analyse des
  /// ingrédients le reconnaisse.
  static String _paragraphs(Element? container, {bool boldAsTitle = false}) {
    if (container == null) return '';
    final lines = <String>[];
    for (final paragraph in container.querySelectorAll('p')) {
      final text = _text(paragraph);
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

  /// « 4 personnes » → 4 portions. Une autre unité (« 15 biscuits ») ne peut
  /// pas être une portion : le texte d'origine est gardé dans les notes.
  static (int?, String?) _yield(String text) {
    if (text.isEmpty) return (null, null);
    final match = RegExp(r'^(\d+)\s*(.*)$').firstMatch(text);
    if (match == null) return (null, 'Quantité : $text');
    final count = int.parse(match.group(1)!);
    final unit = match.group(2)!.trim().toLowerCase();
    if (unit.isEmpty ||
        RegExp(r'^(personne|portion|part|pers)').hasMatch(unit)) {
      return (count, null);
    }
    return (null, 'Quantité : $text');
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
