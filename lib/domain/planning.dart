import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Un créneau de repas (petit-déjeuner, déjeuner…), dans l'ordre choisi dans
/// les réglages. Un créneau masqué n'est plus proposé, mais ses repas restent.
@immutable
class MealSlot {
  const MealSlot({
    required this.id,
    required this.name,
    this.position = 0,
    this.hidden = false,
    this.categoryIds = const {},
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final int position;
  final bool hidden;

  /// Les catégories (types de plat) proposées par le planificateur pour ce
  /// créneau ; vide = toutes.
  final Set<String> categoryIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  MealSlot copyWith({
    String? name,
    int? position,
    bool? hidden,
    Set<String>? categoryIds,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => MealSlot(
    id: id,
    name: name ?? this.name,
    position: position ?? this.position,
    hidden: hidden ?? this.hidden,
    categoryIds: categoryIds ?? this.categoryIds,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is MealSlot &&
      other.id == id &&
      other.name == name &&
      other.position == position &&
      other.hidden == hidden &&
      _sameSet(other.categoryIds, categoryIds) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    position,
    hidden,
    Object.hashAllUnordered(categoryIds),
    createdAt,
    updatedAt,
    deletedAt,
  );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Les créneaux fournis au départ ; identifiants déterministes (les mêmes sur
/// tous les appareils).
abstract final class DefaultMealSlots {
  static const names = ['Petit-déjeuner', 'Déjeuner', 'Goûter', 'Dîner'];

  static String idFor(String name) =>
      const Uuid().v5(Namespace.url.value, 'recettes:slot:$name');

  static List<MealSlot> build(DateTime now) => [
    for (final (position, name) in names.indexed)
      MealSlot(
        id: idFor(name),
        name: name,
        position: position,
        createdAt: now,
        updatedAt: now,
      ),
  ];
}

/// Un repas du planning : un jour, un créneau, et une recette (avec son
/// nombre de personnes) ou une note libre (« Restaurant »).
@immutable
class PlannedMeal {
  const PlannedMeal({
    required this.id,
    required this.day,
    required this.slotId,
    this.recipeId,
    this.recipeTitle = '',
    this.servings,
    this.note = '',
    this.leftoverOf,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;

  /// Le jour, sans heure (voir [dayOf]).
  final DateTime day;
  final String slotId;

  /// La recette ; `null` pour une note libre.
  final String? recipeId;

  /// Le titre de la recette au moment de l'ajout (affiché si elle a disparu).
  final String recipeTitle;
  final int? servings;

  /// Une note libre (« Restaurant », « Pizza ») ou une précision.
  final String note;

  /// Les restes de ce repas (son identifiant) : déjà cuisiné, pas à acheter.
  final String? leftoverOf;

  /// L'ordre dans le créneau.
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isRecipe => recipeId != null;
  bool get isLeftovers => leftoverOf != null;

  /// Le jour d'une date (minuit, heure locale).
  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// « 2026-11-07 » : le jour en texte (base, sauvegarde).
  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime? parseDay(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  /// Le lundi de la semaine de [date].
  static DateTime weekStart(DateTime date) {
    final day = dayOf(date);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  PlannedMeal copyWith({
    String? id,
    DateTime? day,
    String? slotId,
    int? Function()? servings,
    String? note,
    String? Function()? leftoverOf,
    int? position,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => PlannedMeal(
    id: id ?? this.id,
    day: day != null ? dayOf(day) : this.day,
    slotId: slotId ?? this.slotId,
    recipeId: recipeId,
    recipeTitle: recipeTitle,
    servings: servings != null ? servings() : this.servings,
    note: note ?? this.note,
    leftoverOf: leftoverOf != null ? leftoverOf() : this.leftoverOf,
    position: position ?? this.position,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannedMeal &&
      other.id == id &&
      other.day == day &&
      other.slotId == slotId &&
      other.recipeId == recipeId &&
      other.recipeTitle == recipeTitle &&
      other.servings == servings &&
      other.note == note &&
      other.leftoverOf == leftoverOf &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    day,
    slotId,
    recipeId,
    recipeTitle,
    servings,
    note,
    leftoverOf,
    position,
    createdAt,
    updatedAt,
    deletedAt,
  );
}
