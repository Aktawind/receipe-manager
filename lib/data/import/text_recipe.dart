import '../../core/format/text_search.dart';
import '../../domain/step_durations.dart';
import 'web_recipe.dart';

/// Lecture d'une recette entière collée en texte : réponse d'une IA (souvent
/// en Markdown), recette copiée d'un document ou d'un message.
///
/// Repère le titre, les rubriques (« Ingrédients », « Préparation »,
/// « Astuces »…), le nombre de personnes et les temps. Le détail des lignes
/// d'ingrédients et d'étapes est ensuite lu par `IngredientText` et
/// `StepText`, comme une saisie.
abstract final class TextRecipeParser {
  static WebRecipe parse(String input) {
    // Une image Markdown (« ![…](https://…) ») : la photo de la recette.
    Uri? image;
    final rawLines = <String>[];
    for (final raw in input.split(RegExp(r'\r?\n'))) {
      final picture = RegExp(r'^\s*!\[[^\]]*\]\((https?://[^)\s]+)\)')
          .firstMatch(raw);
      if (picture != null) {
        image ??= Uri.tryParse(picture.group(1)!);
        continue;
      }
      rawLines.add(raw);
    }
    final lines = _joinLabels([for (final raw in rawLines) _strip(raw)]);

    var title = '';
    final description = <String>[];
    final ingredients = <String>[];
    final steps = <String>[];
    final notes = <String>[];
    int? servings;
    var servingsUnit = '';
    int? prep;
    int? cook;
    int? total;

    var section = _Section.intro;
    var sawSection = false;
    String? chatterTitle;
    var titleFromHeading = false;

    for (final (index, raw) in lines.indexed) {
      final line = raw.text;
      if (line.isEmpty || RegExp(r'^[-–—_*=~]{3,}$').hasMatch(line)) continue;

      // Les informations (personnes, temps) : avant les étapes, et jamais
      // une ligne d'ingrédient (« 2 portions de fromage »).
      final canBeInfo =
          section == _Section.intro ||
          (section == _Section.ingredients &&
              RegExp(
                r'^(pour|portions?|personnes?|parts?|temps|preparation|cuisson|repos)\b',
              ).hasMatch(normalizeForSearch(line)));
      final yield = canBeInfo ? _servings(line) : null;
      final times = canBeInfo ? _times(line) : const <_Time, int>{};
      void keepInfo() {
        if (yield != null) (servings, servingsUnit) = yield;
        prep ??= times[_Time.prep];
        cook ??= times[_Time.cook];
        total ??= times[_Time.total];
      }

      // Les phrases de conclusion d'une IA (« Bon appétit ! Veux-tu… ? »).
      if (_isClosing(line)) continue;

      // Rubrique : « ## Ingrédients », « **Préparation :** », « Étapes »,
      // « Préparation (15 minutes) ». « Préparation : 20 min » est un temps,
      // pas une rubrique.
      final heading = _sectionOf(line);
      if (heading != null && (raw.heading || _looksLikeHeading(line))) {
        section = heading;
        sawSection = true;
        keepInfo();
        continue;
      }

      // « Le petit plus : … », « Astuce : … » : une astuce, même au milieu.
      if (heading == _Section.notes && line.contains(':')) {
        section = _Section.notes;
        sawSection = true;
        notes.add(line);
        continue;
      }

      if (yield != null || times.isNotEmpty) {
        keepInfo();
        if (_isOnlyInfo(line)) continue;
      }

      // Les phrases d'introduction d'une IA (« Voici une recette… »). Le
      // plat qu'elles annoncent sert de titre s'il n'y en a pas, et une
      // vraie présentation est gardée en description.
      if (section == _Section.intro && _isChatter(line)) {
        chatterTitle ??= _titleFromChatter(line);
        if (line.length > 80 && !line.endsWith(':')) description.add(line);
        continue;
      }

      switch (section) {
        case _Section.intro:
          if (raw.heading) {
            // Un titre Markdown avant les rubriques : le nom de la recette,
            // même après une ou deux phrases de présentation.
            if (title.isNotEmpty && !titleFromHeading) {
              description.insert(0, title);
            }
            if (!titleFromHeading) {
              title = _cleanTitle(line);
              titleFromHeading = true;
            } else {
              description.add(line);
            }
          } else if (title.isEmpty && index < 6 && _looksLikeTitle(line)) {
            title = _cleanTitle(line);
          } else {
            description.add(line);
          }
        case _Section.ingredients:
          ingredients.add(raw.heading ? '${_noColon(line)} :' : line);
        case _Section.steps:
          steps.add(raw.heading ? '${_noColon(line)} :' : line);
        case _Section.notes:
          notes.add(line);
      }
    }

    // Pas de rubriques : les lignes qui commencent par une quantité sont des
    // ingrédients, les phrases sont des étapes.
    if (!sawSection && description.isNotEmpty) {
      for (final line in description) {
        if (RegExp(
              r'^(\d|½|¼|¾|un |une )',
              caseSensitive: false,
            ).hasMatch(line) &&
            line.length < 70) {
          ingredients.add(line);
        } else {
          steps.add(line);
        }
      }
      description.clear();
    }

    if (title.isEmpty) title = chatterTitle ?? '';

    return WebRecipe(
      imageUrl: image,
      title: title,
      description: description.join('\n'),
      ingredients: ingredients,
      steps: steps,
      servings: servings,
      servingsUnit: servingsUnit,
      prepMinutes: prep,
      cookMinutes: cook,
      totalMinutes: total,
      notes: notes.join('\n'),
    );
  }

  // Retire le Markdown d'une ligne ; dit si c'était un titre (« # », gras
  // seul sur sa ligne, ligne finie par « : »).
  static ({String text, bool heading}) _strip(String raw) {
    var text = raw.trim().replaceFirst(RegExp(r'^(>\s*)+'), '');
    var heading = false;
    final hashes = RegExp(r'^#{1,6}\s*(.*)$').firstMatch(text);
    if (hashes != null) {
      heading = true;
      text = hashes.group(1)!;
    }
    final bold = RegExp(r'^\*\*(.+?)\*\*\s*:?\s*$').firstMatch(text);
    if (bold != null && !RegExp(r'^\d').hasMatch(bold.group(1)!)) {
      heading = true;
      text = bold.group(1)!;
    }
    // Emojis en début de ligne (« 🥕 Ingrédients », « ⏱️ Temps »).
    text = _withoutLeadingSymbols(text);
    text = text.replaceAll('**', '').replaceAll('__', '').trim();
    return (text: text, heading: heading);
  }

  /// Retire les emojis et symboles en tête de ligne : tout caractère au-delà
  /// des lettres latines, grecques et cyrilliques (flèches, pictogrammes,
  /// sélecteurs de variante, liants d'emoji), et les espaces.
  static String _withoutLeadingSymbols(String text) {
    final runes = text.runes.toList();
    var start = 0;
    while (start < runes.length &&
        (runes[start] >= 0x2190 ||
            const {0x20, 0xA0, 0x200C, 0x200D}.contains(runes[start]))) {
      start++;
    }
    return String.fromCharCodes(runes.sublist(start));
  }

  /// Un titre plausible : court, sans phrase (pas de point final).
  static bool _looksLikeTitle(String line) =>
      line.length <= 70 &&
      !RegExp(r'[.!?…]$').hasMatch(line) &&
      line.split(' ').length <= 12;

  /// « PRÉPARATION » puis « 10 min » sur la ligne suivante (fiches des IA) :
  /// une seule ligne « PRÉPARATION : 10 min ».
  static List<({String text, bool heading})> _joinLabels(
    List<({String text, bool heading})> lines,
  ) {
    final label = RegExp(
      r'^(preparation|cuisson|repos|temps( de \w+)?|temps total|total|quantite|portions?|personnes?|parts?|rendement|difficulte)\s*:?$',
    );
    final result = <({String text, bool heading})>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.heading && label.hasMatch(normalizeForSearch(line.text))) {
        var next = i + 1;
        while (next < lines.length && lines[next].text.isEmpty) {
          next++;
        }
        // Une valeur courte (« 10 min », « 12 biscuits »), pas une étape.
        if (next < lines.length &&
            lines[next].text.length <= 24 &&
            RegExp(r'^[\d½¼¾]').hasMatch(lines[next].text)) {
          result.add((
            text: '${_noColon(line.text)} : ${lines[next].text}',
            heading: false,
          ));
          i = next;
          continue;
        }
      }
      result.add(line);
    }
    return result;
  }

  static _Section? _sectionOf(String line) {
    final key = normalizeForSearch(line)
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'[:.!]'), '')
        .trim();
    if (RegExp(r'^(les )?ingredients\b').hasMatch(key)) {
      return _Section.ingredients;
    }
    if (RegExp(
      r'^(la )?(preparation|instructions?|etapes|deroulement|realisation|methode|recette)\b',
    ).hasMatch(key)) {
      return _Section.steps;
    }
    if (RegExp(
      r'^((mes|mon|ma|nos|notre|les|quelques) )?((petite?s?|bonne?s?) )?(astuces?|conseils?|notes?|variantes?|suggestions?|le petit plus|petit plus|a savoir|conservation)\b',
    ).hasMatch(key)) {
      return _Section.notes;
    }
    return null;
  }

  static bool _isChatter(String line) {
    final text = normalizeForSearch(line);
    return RegExp(
          r'^(voici|bien sur|absolument|avec plaisir|d.accord|je vous propose|je te propose|excellente? (idee|choix)|super)\b',
        ).hasMatch(text) ||
        (line.endsWith(':') && line.length > 40);
  }

  /// Une rubrique écrite sans Markdown : quelques mots sans chiffres, hors
  /// parenthèses (« Préparation (15 minutes) », « Ingrédients : »).
  static bool _looksLikeHeading(String line) {
    final bare = _noColon(line.replaceAll(RegExp(r'\(.*?\)'), '')).trim();
    return bare.length <= 40 && !RegExp(r'\d').hasMatch(bare);
  }

  static bool _isClosing(String line) => RegExp(
    r"^(bon appetit|bonne degustation|n.hesite|n.hesitez|veux-tu|voulez-vous|souhaites-tu|souhaitez-vous|dis-moi|dites-moi|j.espere|si tu veux|si vous voulez)\b",
  ).hasMatch(normalizeForSearch(line));

  /// « Voici une délicieuse recette de biscuits (ou petits gâteaux) moelleux
  /// à la banane, idéale… » → « Biscuits moelleux à la banane ».
  static String? _titleFromChatter(String line) {
    final match = RegExp(
      r"recette (?:de |d'|d’|du |des |pour )(.+)",
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    var dish = match
        .group(1)!
        .replaceAll(RegExp(r'\s*\(.*?\)'), '')
        .split(RegExp(r'[,.!:;]| qui | que | idéale| parfaite| pour '))
        .first
        .trim();
    if (dish.isEmpty || dish.length > 60) return null;
    return dish[0].toUpperCase() + dish.substring(1);
  }

  static String _noColon(String line) =>
      line.replaceFirst(RegExp(r'\s*:\s*$'), '');

  static String _cleanTitle(String line) {
    final title = line
        .replaceFirst(
          RegExp(r'^(recette|titre)\s*:\s*', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Un titre de livre en capitales (« TARTE AUX POMMES ») : en minuscules,
    // avec une majuscule initiale.
    if (title.length > 3 &&
        title == title.toUpperCase() &&
        title != title.toLowerCase()) {
      final lower = title.toLowerCase();
      return lower[0].toUpperCase() + lower.substring(1);
    }
    return title;
  }

  /// « Pour 4 personnes », « 6 parts », « Portions : 4 », « 24 biscuits ».
  static (int, String)? _servings(String line) {
    final text = normalizeForSearch(line);
    final people = RegExp(
      r'(?:pour|portions?|parts?|personnes?|couverts?)\s*:?\s*(\d+)|(\d+)\s*(personnes?|pers\b|portions?|parts?|couverts?)',
    ).firstMatch(text);
    if (people != null) {
      return (int.parse(people.group(1) ?? people.group(2)!), '');
    }
    final pieces = RegExp(
      r'(?:pour|donne|rendement|quantite)\s*:?\s*(?:environ\s+)?(\d+)\s+([a-z]+)',
    ).firstMatch(text);
    if (pieces != null &&
        !RegExp(r'^(g|kg|ml|cl|l|min|minutes|h|heures?)$')
            .hasMatch(pieces.group(2)!)) {
      // Le mot tel qu'écrit (avec ses accents).
      final original = RegExp('${pieces.group(1)}\\s+(\\S+)')
          .firstMatch(line)
          ?.group(1);
      return (int.parse(pieces.group(1)!), original ?? pieces.group(2)!);
    }
    return null;
  }

  /// « Préparation : 20 min », « Temps de cuisson : 1 h 10 », « Repos 2 h ».
  static Map<_Time, int> _times(String line) {
    final result = <_Time, int>{};
    final text = normalizeForSearch(line);
    for (final part in text.split(RegExp(r'[|•·–—,;/]|\s-\s'))) {
      final durations = StepDurations.find(part);
      if (durations.isEmpty) continue;
      final minutes = durations.first.inMinutes;
      if (RegExp(r'\b(preparation|prep)\b').hasMatch(part)) {
        result[_Time.prep] = minutes;
      } else if (RegExp(r'\bcuisson\b').hasMatch(part)) {
        result[_Time.cook] = minutes;
      } else if (RegExp(r'\b(total|temps total)\b').hasMatch(part)) {
        result[_Time.total] = minutes;
      }
    }
    return result;
  }

  /// La ligne ne dit que des informations (personnes, temps, difficulté) :
  /// rien à garder en description.
  static bool _isOnlyInfo(String line) {
    final text = normalizeForSearch(line);
    return line.length <= 120 &&
        !RegExp(r'[.!?]\s+\p{Lu}', unicode: true).hasMatch(line) &&
        RegExp(
          r'(preparation|cuisson|repos|total|temps|personnes?|portions?|parts?|pour \d|difficulte|quantite)',
        ).hasMatch(text);
  }
}

enum _Section { intro, ingredients, steps, notes }

enum _Time { prep, cook, total }
