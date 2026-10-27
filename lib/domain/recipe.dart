import 'package:flutter/foundation.dart';

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
    this.tips = '',
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.restMinutes,
    this.timesCooked = 0,
    this.mainPhoto,
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
  final String tips;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;
  final int? restMinutes;
  final int timesCooked;

  /// Nom du fichier de la photo principale dans le dossier des photos.
  final String? mainPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<IngredientLine> ingredients;
  final List<RecipeStep> steps;

  bool get isDeleted => deletedAt != null;

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
      tips.trim().isEmpty &&
      servings == null &&
      prepMinutes == null &&
      cookMinutes == null &&
      restMinutes == null &&
      mainPhoto == null &&
      ingredients.every((i) => i.isBlank) &&
      steps.every((s) => s.text.trim().isEmpty);

  Recipe copyWith({
    String? title,
    String? description,
    String? source,
    String? notes,
    String? tips,
    ValueGetter<int?>? servings,
    ValueGetter<int?>? prepMinutes,
    ValueGetter<int?>? cookMinutes,
    ValueGetter<int?>? restMinutes,
    int? timesCooked,
    ValueGetter<String?>? mainPhoto,
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
      tips: tips ?? this.tips,
      servings: servings != null ? servings() : this.servings,
      prepMinutes: prepMinutes != null ? prepMinutes() : this.prepMinutes,
      cookMinutes: cookMinutes != null ? cookMinutes() : this.cookMinutes,
      restMinutes: restMinutes != null ? restMinutes() : this.restMinutes,
      timesCooked: timesCooked ?? this.timesCooked,
      mainPhoto: mainPhoto != null ? mainPhoto() : this.mainPhoto,
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
  const RecipeStep({required this.id, this.text = ''});

  final String id;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is RecipeStep && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}
