import '../core/format/text_search.dart';

/// Les rubriques d'une recette écrite (texte collé, page de livre).
enum RecipeSection { ingredients, steps, notes }

/// Ce que mesure un temps annoncé (« Préparation : 20 min »).
enum RecipeTime { prep, cook, total, rest }

/// Le vocabulaire des recettes écrites, commun aux lectures de texte collé
/// (`TextRecipeParser`) et de pages de livre (`OcrLayout`) : une règle ajoutée
/// ici profite aux deux.
abstract final class RecipeWords {
  /// La rubrique qu'annoncent les premiers mots de [line] : « Ingrédients »,
  /// « La préparation (15 minutes) », « Nos petites astuces », « Bon à
  /// savoir ». Dire si la ligne est bien une rubrique (courte, seule) revient
  /// à l'appelant.
  static RecipeSection? sectionOf(String line) {
    final key = normalizeForSearch(line)
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'[:.!]'), '')
        .trim();
    if (RegExp(r'^(les )?ingredients\b').hasMatch(key)) {
      return RecipeSection.ingredients;
    }
    if (RegExp(
      r'^(la )?(preparation|instructions?|etapes|deroulement|realisation|methode|recette)\b',
    ).hasMatch(key)) {
      return RecipeSection.steps;
    }
    if (RegExp(
      r'^((mes|mon|ma|nos|notre|les|quelques) )?((petite?s?|bonne?s?) )?(astuces?|conseils?|notes?|variantes?|suggestions?|le petit plus|petit plus|bon a savoir|a savoir|conservation)\b',
    ).hasMatch(key)) {
      return RecipeSection.notes;
    }
    return null;
  }

  /// Un libellé seul sur sa ligne, dont la valeur suit (fiches des IA, pages
  /// de livre) : « PRÉPARATION », « Temps de cuisson : », « Portions ».
  static bool isInfoLabel(String line) => RegExp(
    r'^(preparation|cuisson|repos|refrigeration|temps( de \w+)?|temps total|total|quantite|portions?|personnes?|parts?|rendement|difficulte)\s*:?$',
  ).hasMatch(normalizeForSearch(line).trim());

  /// Ce que mesure le temps annoncé dans [part] (déjà normalisé par
  /// `normalizeForSearch`) : « préparation », « cuisson », « prêt en »,
  /// « repos », « réfrigération »…
  static RecipeTime? timeOf(String part) {
    if (RegExp(r'\b(preparation|prep)\b').hasMatch(part)) {
      return RecipeTime.prep;
    }
    if (RegExp(r'\bcuisson\b').hasMatch(part)) return RecipeTime.cook;
    if (RegExp(r'\b(total|temps total|pret en)\b').hasMatch(part)) {
      return RecipeTime.total;
    }
    if (RegExp(
      r'\b(repos|refrigeration|attente|marinade|levee|pousse|congelation)\b',
    ).hasMatch(part)) {
      return RecipeTime.rest;
    }
    return null;
  }
}
