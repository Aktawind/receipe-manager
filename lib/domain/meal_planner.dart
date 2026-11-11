import 'dart:math';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'default_labels.dart';
import 'ingredient_match.dart';
import 'label.dart';
import 'recipe.dart';

/// Les saisons, dans l'ordre du classement (`DefaultLabels.seasonNames`).
enum Season {
  spring,
  summer,
  autumn,
  winter;

  /// Le nom de l'élément « saison » du classement.
  String get labelName => DefaultLabels.seasonNames[index];

  String get labelId => Label.idFor(LabelKind.season, labelName);

  /// La saison d'une date (mois entiers : mars à mai = printemps…).
  static Season of(DateTime date) => switch (date.month) {
    3 || 4 || 5 => spring,
    6 || 7 || 8 => summer,
    9 || 10 || 11 => autumn,
    _ => winter,
  };

  static Season? fromCode(String code) =>
      values.where((s) => s.name == code).firstOrNull;
}

/// Ce qu'un accompagnement apporte au repas.
enum SideKind {
  starch,
  protein,
  vegetable;

  static SideKind? fromCode(String code) =>
      values.where((k) => k.name == code).firstOrNull;
}

/// Un accompagnement pour compléter un repas (riz, poulet, courgettes…), de
/// toutes saisons ([seasons] vide) ou de certaines.
@immutable
class SideDish {
  const SideDish({
    required this.id,
    required this.kind,
    required this.name,
    this.seasons = const {},
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final SideKind kind;
  final String name;
  final Set<Season> seasons;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  bool fits(Season season) => seasons.isEmpty || seasons.contains(season);

  SideDish copyWith({
    String? name,
    Set<Season>? seasons,
    int? position,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => SideDish(
    id: id,
    kind: kind,
    name: name ?? this.name,
    seasons: seasons ?? this.seasons,
    position: position ?? this.position,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SideDish &&
      other.id == id &&
      other.kind == kind &&
      other.name == name &&
      other.seasons.length == seasons.length &&
      other.seasons.containsAll(seasons) &&
      other.position == position &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    Object.hashAllUnordered(seasons),
    position,
    createdAt,
    updatedAt,
    deletedAt,
  );
}

/// Les accompagnements fournis au départ ; identifiants déterministes.
abstract final class DefaultSideDishes {
  static const _all = <Season>{};
  static const starches = [
    'Riz',
    'Pâtes',
    'Semoule',
    'Quinoa',
    'Boulgour',
    'Pommes de terre',
    'Patate douce',
    'Polenta',
    'Pain',
    'Lentilles',
  ];
  static const proteins = [
    'Poulet',
    'Dinde',
    'Bœuf haché',
    'Steak',
    'Porc',
    'Poisson blanc',
    'Saumon',
    'Thon',
    'Œufs',
    'Jambon',
    'Tofu',
    'Pois chiches',
  ];
  static const vegetables = <String, Set<Season>>{
    'Poireaux': {Season.autumn, Season.winter},
    'Carottes': {Season.winter, Season.spring},
    'Chou': {Season.winter},
    'Endives': {Season.winter},
    'Courge': {Season.winter},
    'Épinards': {Season.winter, Season.spring},
    'Céleri': {Season.winter},
    'Navets': {Season.winter},
    'Asperges': {Season.spring},
    'Petits pois': {Season.spring},
    'Radis': {Season.spring},
    'Artichauts': {Season.spring},
    'Courgettes': {Season.summer},
    'Tomates': {Season.summer},
    'Aubergines': {Season.summer},
    'Poivrons': {Season.summer},
    'Haricots verts': {Season.summer},
    'Salade': {Season.summer},
    'Concombre': {Season.summer},
    'Potiron': {Season.autumn},
    'Champignons': {Season.autumn},
    'Brocoli': {Season.autumn},
    'Chou-fleur': {Season.autumn},
    'Betteraves': {Season.autumn},
  };

  static String idFor(SideKind kind, String name) =>
      const Uuid().v5(Namespace.url.value, 'recettes:side:${kind.name}:$name');

  static List<SideDish> build(DateTime now) {
    SideDish make(SideKind kind, String name, int position, Set<Season> s) =>
        SideDish(
          id: idFor(kind, name),
          kind: kind,
          name: name,
          seasons: s,
          position: position,
          createdAt: now,
          updatedAt: now,
        );
    return [
      for (final (i, n) in starches.indexed) make(SideKind.starch, n, i, _all),
      for (final (i, n) in proteins.indexed) make(SideKind.protein, n, i, _all),
      for (final (i, e) in vegetables.entries.indexed)
        make(SideKind.vegetable, e.key, i, e.value),
    ];
  }
}

/// Un repas à prévoir dans une planification : un jour de la semaine
/// (1 = lundi), un créneau, le temps disponible et, au besoin, une collection.
@immutable
class PlannerSlot {
  const PlannerSlot({
    required this.weekday,
    required this.slotId,
    this.minutes = 30,
    this.collectionId,
  });

  final int weekday;
  final String slotId;

  /// Le temps disponible ; `null` = sans limite.
  final int? minutes;
  final String? collectionId;

  PlannerSlot copyWith({
    int? weekday,
    String? slotId,
    int? Function()? minutes,
    String? Function()? collectionId,
  }) => PlannerSlot(
    weekday: weekday ?? this.weekday,
    slotId: slotId ?? this.slotId,
    minutes: minutes != null ? minutes() : this.minutes,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
  );

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'slot': slotId,
    'minutes': minutes,
    'collection': collectionId,
  };

  static PlannerSlot? fromJson(Object? json) {
    if (json is! Map) return null;
    final weekday = json['weekday'];
    final slot = json['slot'];
    final minutes = json['minutes'];
    if (weekday is! int || weekday < 1 || weekday > 7 || slot is! String) {
      return null;
    }
    return PlannerSlot(
      weekday: weekday,
      slotId: slot,
      // `null` écrit = sans limite ; absent (ancienne version) = 30 min.
      minutes: minutes is int && minutes > 0
          ? minutes
          : json.containsKey('minutes') && minutes == null
          ? null
          : 30,
      collectionId: json['collection'] is String
          ? json['collection'] as String
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlannerSlot &&
      other.weekday == weekday &&
      other.slotId == slotId &&
      other.minutes == minutes &&
      other.collectionId == collectionId;

  @override
  int get hashCode => Object.hash(weekday, slotId, minutes, collectionId);
}

/// Une planification enregistrée (« Semaine de travail ») : ses repas à
/// prévoir, à remettre d'une semaine sur l'autre.
@immutable
class PlannerSetup {
  const PlannerSetup({
    required this.id,
    required this.name,
    this.slots = const [],
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final List<PlannerSlot> slots;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  PlannerSetup copyWith({
    String? name,
    List<PlannerSlot>? slots,
    DateTime? updatedAt,
    DateTime? Function()? deletedAt,
  }) => PlannerSetup(
    id: id,
    name: name ?? this.name,
    slots: slots ?? this.slots,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt != null ? deletedAt() : this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PlannerSetup &&
      other.id == id &&
      other.name == name &&
      other.slots.length == slots.length &&
      [for (var i = 0; i < slots.length; i++) other.slots[i] == slots[i]]
          .every((same) => same) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(slots),
    createdAt,
    updatedAt,
    deletedAt,
  );
}

/// Le planificateur (un calcul, sans IA) : des recettes pour chaque repas à
/// prévoir, selon le temps, la saison, la collection et les ingrédients à
/// écouler ; et des accompagnements de saison pour compléter un repas.
abstract final class MealPlanner {
  /// Les recettes possibles pour [slot] : pas plus longues que le temps
  /// disponible (une recette sans durée convient), de [season] (une recette
  /// sans saison convient), de la collection demandée ; celles qui
  /// utilisent le plus d'ingrédients de [useUp] d'abord, les autres dans un
  /// ordre tiré au sort ([random]). [categories] : les types de plat du
  /// créneau (sous-catégories comprises) ; vide = tous.
  static List<Recipe> candidates(
    List<Recipe> recipes,
    PlannerSlot slot, {
    required Season season,
    List<String> useUp = const [],
    Set<String> categories = const {},
    required Random random,
  }) {
    final seasonIds = {for (final s in Season.values) s.labelId};
    final allSeasons = Label.idFor(LabelKind.season, DefaultLabels.allSeasons);
    final fitting = [
      for (final r in recipes)
        if (!r.isDeleted &&
            (slot.minutes == null ||
                r.totalMinutes == null ||
                r.totalMinutes! <= slot.minutes!) &&
            (categories.isEmpty || r.labelIds.any(categories.contains)) &&
            (slot.collectionId == null ||
                r.labelIds.contains(slot.collectionId)) &&
            _fitsSeason(r, season, seasonIds, allSeasons))
          r,
    ]..shuffle(random);
    if (useUp.isEmpty) return fitting;
    int score(Recipe r) =>
        useUp.where((term) => IngredientMatch.has(r, term)).length;
    final scores = {for (final r in fitting) r.id: score(r)};
    // Tri stable : à score égal, l'ordre tiré au sort reste.
    final indexed = [...fitting.indexed]
      ..sort((a, b) {
        final byScore = scores[b.$2.id]!.compareTo(scores[a.$2.id]!);
        return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
      });
    return [for (final (_, r) in indexed) r];
  }

  static bool _fitsSeason(
    Recipe recipe,
    Season season,
    Set<String> seasonIds,
    String allSeasons,
  ) {
    final own = recipe.labelIds.where(seasonIds.contains).toSet();
    if (own.isEmpty || recipe.labelIds.contains(allSeasons)) return true;
    return own.contains(season.labelId);
  }

  /// Une recette par repas à prévoir, sans en prendre deux fois la même
  /// (sauf s'il n'y en a pas assez) ; `null` quand aucune ne convient.
  /// [categories] : les types de plat de chaque créneau (par identifiant).
  static List<Recipe?> propose(
    List<Recipe> recipes,
    List<PlannerSlot> slots, {
    required Season season,
    List<String> useUp = const [],
    Map<String, Set<String>> categories = const {},
    required Random random,
  }) {
    final used = <String>{};
    return [
      for (final slot in slots)
        () {
          final options = candidates(
            recipes,
            slot,
            season: season,
            useUp: useUp,
            categories: categories[slot.slotId] ?? const {},
            random: random,
          );
          final pick =
              options.where((r) => !used.contains(r.id)).firstOrNull ??
              options.firstOrNull;
          if (pick != null) used.add(pick.id);
          return pick;
        }(),
    ];
  }

  /// Une autre recette pour [slot] que [current] et que celles déjà
  /// proposées ([taken]) ou écartées ([rejected]) ; `null` s'il n'y en a pas.
  static Recipe? replace(
    List<Recipe> recipes,
    PlannerSlot slot, {
    required Season season,
    List<String> useUp = const [],
    Set<String> taken = const {},
    Set<String> rejected = const {},
    Set<String> categories = const {},
    required Random random,
  }) {
    final options = candidates(
      recipes,
      slot,
      season: season,
      useUp: useUp,
      categories: categories,
      random: random,
    );
    return options
            .where((r) => !taken.contains(r.id) && !rejected.contains(r.id))
            .firstOrNull ??
        options.where((r) => !rejected.contains(r.id)).firstOrNull;
  }

  /// Un accompagnement de [kind] pour [season], autre que ceux de [exclude]
  /// (noms) ; `null` si la liste est vide.
  static SideDish? side(
    List<SideDish> sides,
    SideKind kind, {
    required Season season,
    Set<String> exclude = const {},
    required Random random,
  }) {
    final options = [
      for (final s in sides)
        if (!s.isDeleted && s.kind == kind && s.fits(season)) s,
    ];
    if (options.isEmpty) return null;
    final fresh = [
      for (final s in options)
        if (!exclude.contains(s.name)) s,
    ];
    final pool = fresh.isEmpty ? options : fresh;
    return pool[random.nextInt(pool.length)];
  }
}
