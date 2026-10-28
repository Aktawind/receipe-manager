import 'package:flutter/foundation.dart';

/// Où en est la recette : à essayer, adoptée, ou à revoir.
enum RecipeStatus {
  toTest,
  validated,
  toImprove;

  /// Valeur enregistrée en base et dans les sauvegardes.
  String get code => name;

  static RecipeStatus? fromCode(String? code) {
    for (final status in values) {
      if (status.name == code) return status;
    }
    return null;
  }
}

/// Une recette complète : informations, ingrédients et étapes.
///
/// La recette est l'unité d'enregistrement, d'export et (plus tard) de
/// synchronisation : ses ingrédients et étapes sont toujours écrits ensemble.
@immutable
class Recipe {
  const Recipe({
    required this.id,
    this.title = '',
    this.description = '',
    this.source = '',
    this.notes = '',
    this.servings,
    this.servingsUnit = '',
    this.prepMinutes,
    this.cookMinutes,
    this.restMinutes,
    this.timesCooked = 0,
    this.mainPhoto,
    this.extraPhotos = const [],
    this.isFavorite = false,
    this.rating,
    this.status,
    this.course = '',
    this.category = '',
    this.collections = const [],
    this.linkedRecipeIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.ingredients = const [],
    this.steps = const [],
  });

  final String id;
  final String title;
  final String description;
  final String source;
  final String notes;
  final int? servings;

  /// Ce que compte [servings] quand ce ne sont pas des personnes : « blinis »,
  /// « ramequins ». Vide = des personnes.
  final String servingsUnit;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? restMinutes;
  final int timesCooked;

  /// Nom du fichier de la photo principale dans le dossier des photos.
  final String? mainPhoto;

  /// Photos supplémentaires, après la principale.
  final List<String> extraPhotos;
  final bool isFavorite;

  /// Note de 1 à 5 étoiles ; `null` tant que la recette n'est pas notée.
  final int? rating;
  final RecipeStatus? status;

  /// Type de plat (« Plat », « Dessert », « Goûter »…), texte libre pour
  /// l'instant : le classement complet arrive en 0.3.
  final String course;
  final String category;
  final List<String> collections;

  /// Recettes utilisées par celle-ci (pâte, sauce préparée à l'avance).
  final List<String> linkedRecipeIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<IngredientLine> ingredients;
  final List<RecipeStep> steps;

  bool get isDeleted => deletedAt != null;

  /// Toutes les photos, la principale en premier.
  List<String> get allPhotos => [?mainPhoto, ...extraPhotos];

  int? get totalMinutes {
    final parts = [prepMinutes, cookMinutes, restMinutes].nonNulls;
    return parts.isEmpty ? null : parts.reduce((a, b) => a + b);
  }

  /// Vrai si l'utilisateur n'a encore rien saisi.
  bool get isBlank =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      source.trim().isEmpty &&
      notes.trim().isEmpty &&
      servings == null &&
      servingsUnit.trim().isEmpty &&
      prepMinutes == null &&
      cookMinutes == null &&
      restMinutes == null &&
      mainPhoto == null &&
      extraPhotos.isEmpty &&
      ingredients.every((i) => i.isBlank) &&
      steps.every((s) => s.text.trim().isEmpty);

  Recipe copyWith({
    String? title,
    String? description,
    String? source,
    String? notes,
    ValueGetter<int?>? servings,
    String? servingsUnit,
    ValueGetter<int?>? prepMinutes,
    ValueGetter<int?>? cookMinutes,
    ValueGetter<int?>? restMinutes,
    int? timesCooked,
    ValueGetter<String?>? mainPhoto,
    List<String>? extraPhotos,
    bool? isFavorite,
    ValueGetter<int?>? rating,
    ValueGetter<RecipeStatus?>? status,
    String? course,
    String? category,
    List<String>? collections,
    List<String>? linkedRecipeIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    ValueGetter<DateTime?>? deletedAt,
    List<IngredientLine>? ingredients,
    List<RecipeStep>? steps,
  }) {
    return Recipe(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      notes: notes ?? this.notes,
      servings: servings != null ? servings() : this.servings,
      servingsUnit: servingsUnit ?? this.servingsUnit,
      prepMinutes: prepMinutes != null ? prepMinutes() : this.prepMinutes,
      cookMinutes: cookMinutes != null ? cookMinutes() : this.cookMinutes,
      restMinutes: restMinutes != null ? restMinutes() : this.restMinutes,
      timesCooked: timesCooked ?? this.timesCooked,
      mainPhoto: mainPhoto != null ? mainPhoto() : this.mainPhoto,
      extraPhotos: extraPhotos ?? this.extraPhotos,
      isFavorite: isFavorite ?? this.isFavorite,
      rating: rating != null ? rating() : this.rating,
      status: status != null ? status() : this.status,
      course: course ?? this.course,
      category: category ?? this.category,
      collections: collections ?? this.collections,
      linkedRecipeIds: linkedRecipeIds ?? this.linkedRecipeIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
    );
  }
}

/// Une ligne de la liste d'ingrédients : un ingrédient, ou un titre de groupe
/// (« Pour la pâte »).
@immutable
class IngredientLine {
  const IngredientLine({
    required this.id,
    this.isSection = false,
    this.name = '',
    this.quantity,
    this.unit = '',
    this.note = '',
    this.optional = false,
  });

  final String id;
  final bool isSection;
  final String name;

  /// Absente pour les ingrédients sans quantité précise (« selon le goût »).
  final double? quantity;
  final String unit;

  /// Précision libre : « finement haché », « selon le goût »…
  final String note;
  final bool optional;

  bool get isBlank =>
      name.trim().isEmpty &&
      quantity == null &&
      unit.isEmpty &&
      note.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is IngredientLine &&
      other.id == id &&
      other.isSection == isSection &&
      other.name == name &&
      other.quantity == quantity &&
      other.unit == unit &&
      other.note == note &&
      other.optional == optional;

  @override
  int get hashCode =>
      Object.hash(id, isSection, name, quantity, unit, note, optional);
}

@immutable
class RecipeStep {
  const RecipeStep({required this.id, this.title = '', this.text = ''});

  final String id;

  /// Titre optionnel de la partie (« Biscuit », « Montage »), affiché au-dessus
  /// de l'étape.
  final String title;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is RecipeStep &&
      other.id == id &&
      other.title == title &&
      other.text == text;

  @override
  int get hashCode => Object.hash(id, title, text);
}
