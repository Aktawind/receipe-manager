import '../../domain/equipment.dart';
import '../../domain/label.dart';
import '../../domain/legacy_classification.dart';
import '../../domain/meal_planner.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_links.dart';
import '../../domain/shopping.dart';
import '../photo_store.dart';

/// Format d'échange des sauvegardes, documenté dans docs/FORMAT_EXPORT.md.
///
/// Règle : une version de l'app sait toujours lire les versions précédentes du
/// format. Toute évolution incrémente [currentVersion] et garde la lecture de
/// l'ancienne.
///
/// - v1 : première version (champ `tips` « Astuces »).
/// - v2 : `tips` supprimé (fusionné dans `notes`), titre optionnel des étapes.
/// - v3 : favori, note, statut, type de plat, catégorie, collections, photos
///   supplémentaires et recettes liées.
/// - v4 : `servingsUnit` (« 12 blinis »).
/// - v5 : `equipment`, `videoLinks` et `substitutes` des ingrédients.
/// - v6 : liste commune du matériel (`equipment` au niveau du document, et
///   `equipment` des recettes = identifiants) ; recettes liées dans les
///   ingrédients (`linkedRecipe`) au lieu de `linkedRecipes`.
/// - v8 : le statut « à retester » (`toRetest`) ; rien d'autre ne change.
/// - v7 : classement commun (`labels` du document, `labels` des recettes =
///   identifiants) à la place de `course`, `category` et `collections`.
/// - v9 : listes de courses (`shoppingLists`), rayons (`aisles`) et rayon
///   retenu pour chaque produit (`productAisles`).
/// - v10 : planning des repas : créneaux (`mealSlots`) et repas
///   (`plannedMeals`).
/// - v11 : planificateur : accompagnements (`sideDishes`) et planifications
///   enregistrées (`plannerSetups`).
abstract final class BackupFormat {
  static const formatName = 'recettes-backup';
  static const currentVersion = 11;
  static const dataFile = 'recettes.json';
  static const photosFolder = 'photos/';

  static Map<String, Object?> encode(
    List<Recipe> recipes, {
    List<EquipmentItem> equipment = const [],
    List<Label> labels = const [],
    List<ShoppingList> shoppingLists = const [],
    List<Aisle> aisles = const [],
    List<ProductAisle> productAisles = const [],
    List<MealSlot> mealSlots = const [],
    List<PlannedMeal> plannedMeals = const [],
    List<SideDish> sideDishes = const [],
    List<PlannerSetup> plannerSetups = const [],
    required DateTime exportedAt,
    required String appVersion,
  }) {
    return {
      'format': formatName,
      'version': currentVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appVersion': appVersion,
      'equipment': [
        for (final item in equipment)
          {
            'id': item.id,
            'name': item.name,
            'createdAt': item.createdAt.toUtc().toIso8601String(),
            'updatedAt': item.updatedAt.toUtc().toIso8601String(),
            'deletedAt': item.deletedAt?.toUtc().toIso8601String(),
          },
      ],
      'labels': [
        for (final l in labels)
          {
            'id': l.id,
            'kind': l.kind.code,
            'name': l.name,
            'parentId': l.parentId,
            'icon': l.icon,
            'color': l.color,
            'position': l.position,
            'createdAt': l.createdAt.toUtc().toIso8601String(),
            'updatedAt': l.updatedAt.toUtc().toIso8601String(),
            'deletedAt': l.deletedAt?.toUtc().toIso8601String(),
          },
      ],
      'recipes': [for (final recipe in recipes) _encodeRecipe(recipe)],
      if (aisles.isNotEmpty)
        'aisles': [
          for (final a in aisles)
            {
              'id': a.id,
              'name': a.name,
              'position': a.position,
              'createdAt': a.createdAt.toUtc().toIso8601String(),
              'updatedAt': a.updatedAt.toUtc().toIso8601String(),
              'deletedAt': a.deletedAt?.toUtc().toIso8601String(),
            },
        ],
      if (productAisles.isNotEmpty)
        'productAisles': [
          for (final p in productAisles)
            {
              'key': p.key,
              'aisle': p.aisleId,
              'updatedAt': p.updatedAt.toUtc().toIso8601String(),
            },
        ],
      if (shoppingLists.isNotEmpty)
        'shoppingLists': [for (final l in shoppingLists) _encodeList(l)],
      if (mealSlots.isNotEmpty)
        'mealSlots': [
          for (final s in mealSlots)
            {
              'id': s.id,
              'name': s.name,
              'position': s.position,
              'hidden': s.hidden,
              'createdAt': s.createdAt.toUtc().toIso8601String(),
              'updatedAt': s.updatedAt.toUtc().toIso8601String(),
              'deletedAt': s.deletedAt?.toUtc().toIso8601String(),
            },
        ],
      if (sideDishes.isNotEmpty)
        'sideDishes': [
          for (final d in sideDishes)
            {
              'id': d.id,
              'kind': d.kind.name,
              'name': d.name,
              'seasons': [for (final s in d.seasons) s.name],
              'position': d.position,
              'createdAt': d.createdAt.toUtc().toIso8601String(),
              'updatedAt': d.updatedAt.toUtc().toIso8601String(),
              'deletedAt': d.deletedAt?.toUtc().toIso8601String(),
            },
        ],
      if (plannerSetups.isNotEmpty)
        'plannerSetups': [
          for (final p in plannerSetups)
            {
              'id': p.id,
              'name': p.name,
              'slots': [for (final s in p.slots) s.toJson()],
              'createdAt': p.createdAt.toUtc().toIso8601String(),
              'updatedAt': p.updatedAt.toUtc().toIso8601String(),
              'deletedAt': p.deletedAt?.toUtc().toIso8601String(),
            },
        ],
      if (plannedMeals.isNotEmpty)
        'plannedMeals': [
          for (final m in plannedMeals)
            {
              'id': m.id,
              'day': PlannedMeal.dayKey(m.day),
              'slot': m.slotId,
              'recipe': m.recipeId,
              'recipeTitle': m.recipeTitle,
              'servings': m.servings,
              'note': m.note,
              'leftoverOf': m.leftoverOf,
              'position': m.position,
              'createdAt': m.createdAt.toUtc().toIso8601String(),
              'updatedAt': m.updatedAt.toUtc().toIso8601String(),
              'deletedAt': m.deletedAt?.toUtc().toIso8601String(),
            },
        ],
    };
  }

  static Map<String, Object?> _encodeList(ShoppingList l) => {
    'id': l.id,
    'name': l.name,
    'createdAt': l.createdAt.toUtc().toIso8601String(),
    'updatedAt': l.updatedAt.toUtc().toIso8601String(),
    'deletedAt': l.deletedAt?.toUtc().toIso8601String(),
    'items': [
      for (final i in l.items)
        {
          'id': i.id,
          'name': i.name,
          'quantity': i.quantity,
          'unit': i.unit,
          'toBuy': i.toBuy,
          'format': i.format,
          'note': i.note,
          'aisle': i.aisleId,
          'checked': i.checked,
          'sources': [
            for (final s in i.sources)
              {
                'recipe': s.recipeId,
                'title': s.recipeTitle,
                'quantity': s.quantity,
                'unit': s.unit,
              },
          ],
        },
    ],
  };

  static Map<String, Object?> _encodeRecipe(Recipe r) => {
    'id': r.id,
    'title': r.title,
    'description': r.description,
    'source': r.source,
    'notes': r.notes,
    'servings': r.servings,
    'servingsUnit': r.servingsUnit,
    'prepMinutes': r.prepMinutes,
    'cookMinutes': r.cookMinutes,
    'restMinutes': r.restMinutes,
    'timesCooked': r.timesCooked,
    'mainPhoto': r.mainPhoto,
    'extraPhotos': r.extraPhotos,
    'favorite': r.isFavorite,
    'rating': r.rating,
    'status': r.status?.code,
    'labels': r.labelIds,
    'equipment': r.equipmentIds,
    'videoLinks': r.videoLinks,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
    'deletedAt': r.deletedAt?.toUtc().toIso8601String(),
    'ingredients': [
      for (final i in r.ingredients)
        {
          'id': i.id,
          'section': i.isSection,
          'name': i.name,
          'quantity': i.quantity,
          'unit': i.unit,
          'note': i.note,
          'optional': i.optional,
          'substitutes': i.substitutes,
          'linkedRecipe': i.linkedRecipeId,
        },
    ],
    'steps': [
      for (final s in r.steps) {'id': s.id, 'title': s.title, 'text': s.text},
    ],
  };

  /// Lit et valide un document. Lève [BackupFormatException] au moindre
  /// problème : rien n'est importé d'un fichier invalide.
  static BackupData decode(Object? json) {
    final root = _map(json, 'document');
    if (root['format'] != formatName) {
      throw const BackupFormatException(BackupError.notABackup);
    }
    final version = root['version'];
    if (version is! int || version < 1) {
      throw const BackupFormatException(BackupError.invalid, 'version');
    }
    if (version > currentVersion) {
      throw const BackupFormatException(BackupError.newerVersion);
    }
    final list = root['recipes'];
    if (list is! List) {
      throw const BackupFormatException(BackupError.invalid, 'recipes');
    }
    var recipes = [for (final item in list) _decodeRecipe(item, version)];
    final ids = <String>{};
    for (final recipe in recipes) {
      if (!ids.add(recipe.id)) {
        throw BackupFormatException(BackupError.invalid, 'id ${recipe.id}');
      }
    }

    final equipment = <EquipmentItem>[];
    if (version >= 6) {
      for (final item in _list(root, 'equipment')) {
        final m = _map(item, 'equipment');
        final id = _string(m, 'id', required: true);
        final name = EquipmentItem.cleanName(
          _string(m, 'name', required: true),
        );
        if (id.isEmpty || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'equipment');
        }
        equipment.add(
          EquipmentItem(
            id: id,
            name: name,
            createdAt: _date(m, 'createdAt')!,
            updatedAt: _date(m, 'updatedAt')!,
            deletedAt: _date(m, 'deletedAt', required: false),
          ),
        );
      }
    } else {
      // v3 à v5 : le matériel est une liste de noms dans chaque recette, et les
      // recettes liées sont à part.
      final stamp =
          DateTime.tryParse(
            root['exportedAt'] is String ? root['exportedAt'] as String : '',
          ) ??
          DateTime.now();
      final byId = <String, EquipmentItem>{};
      final titles = {for (final r in recipes) r.id: r.title};
      final rawRecipes = list.cast<Map<String, Object?>>();
      final updated = <Recipe>[];
      for (final (index, recipe) in recipes.indexed) {
        final raw = rawRecipes[index];
        final equipmentIds = <String>[];
        for (final name in _strings(raw, 'equipment')) {
          if (name.trim().isEmpty) continue;
          final id = EquipmentItem.idForName(name);
          if (equipmentIds.contains(id)) continue;
          equipmentIds.add(id);
          byId.putIfAbsent(
            id,
            () => EquipmentItem(
              id: id,
              name: EquipmentItem.cleanName(name),
              createdAt: stamp,
              updatedAt: stamp,
            ),
          );
        }
        updated.add(
          RecipeLinks.attach(
            recipe.copyWith(equipmentIds: equipmentIds),
            _strings(raw, 'linkedRecipes'),
            (id) => titles[id],
          ),
        );
      }
      recipes = updated;
      equipment.addAll(byId.values);
    }

    final labels = <Label>[];
    if (version >= 7) {
      // Les étiquettes et occasions des versions de test sont devenues des
      // collections, le type de repas a disparu : leurs liens suivent.
      final remap = <String, String?>{};
      for (final item in _list(root, 'labels')) {
        final m = _map(item, 'label');
        final code = m['kind'] is String ? m['kind'] as String : null;
        final id = _string(m, 'id', required: true);
        final name = Label.cleanName(_string(m, 'name', required: true));
        if (id.isEmpty || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'labels');
        }
        var kind = LabelKind.fromCode(code);
        if (kind == null && (code == 'tag' || code == 'occasion')) {
          kind = LabelKind.collection;
          remap[id] = Label.idFor(LabelKind.collection, name);
        } else if (kind == null && code == 'meal') {
          remap[id] = null;
          continue;
        } else if (kind == null) {
          throw const BackupFormatException(BackupError.invalid, 'labels');
        }
        labels.add(
          Label(
            id: remap[id] ?? id,
            kind: kind,
            name: name,
            parentId: m['parentId'] is String ? m['parentId'] as String : null,
            icon: _string(m, 'icon'),
            color: _string(m, 'color'),
            position: _int(m, 'position') ?? 0,
            createdAt: _date(m, 'createdAt')!,
            updatedAt: _date(m, 'updatedAt')!,
            deletedAt: _date(m, 'deletedAt', required: false),
          ),
        );
      }
      if (remap.isNotEmpty) {
        recipes = [
          for (final recipe in recipes)
            recipe.copyWith(
              labelIds: {
                for (final id in recipe.labelIds)
                  if (!remap.containsKey(id)) id else ?remap[id],
              }.toList(),
            ),
        ];
      }
    } else {
      // v3 à v6 : type de plat, catégorie et collections en texte libre.
      final rawRecipes = list.cast<Map<String, Object?>>();
      final stamp =
          DateTime.tryParse(
            root['exportedAt'] is String ? root['exportedAt'] as String : '',
          ) ??
          DateTime.now();
      final plan = LegacyClassification.plan([
        for (final (index, recipe) in recipes.indexed)
          LegacyEntry(
            recipeId: recipe.id,
            course: _string(rawRecipes[index], 'course'),
            categories: [_string(rawRecipes[index], 'category')],
            collections: _strings(rawRecipes[index], 'collections'),
          ),
      ], stamp);
      labels.addAll(plan.labels);
      recipes = [
        for (final recipe in recipes)
          recipe.copyWith(labelIds: plan.byRecipe[recipe.id] ?? const []),
      ];
    }
    return BackupData(
      recipes,
      equipment,
      labels,
      shoppingLists: version >= 9 ? _decodeLists(root) : const [],
      aisles: version >= 9 ? _decodeAisles(root) : const [],
      productAisles: version >= 9 ? _decodeProductAisles(root) : const [],
      mealSlots: version >= 10 ? _decodeSlots(root) : const [],
      plannedMeals: version >= 10 ? _decodeMeals(root) : const [],
      sideDishes: version >= 11 ? _decodeSides(root) : const [],
      plannerSetups: version >= 11 ? _decodeSetups(root) : const [],
    );
  }

  static List<SideDish> _decodeSides(Map<String, Object?> root) => [
    for (final item in _list(root, 'sideDishes'))
      () {
        final m = _map(item, 'sideDish');
        final id = _string(m, 'id', required: true);
        final kind = SideKind.fromCode(_string(m, 'kind', required: true));
        final name = _string(m, 'name', required: true).trim();
        if (id.isEmpty || kind == null || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'sideDishes');
        }
        return SideDish(
          id: id,
          kind: kind,
          name: name,
          seasons: {
            for (final code in _strings(m, 'seasons')) ?Season.fromCode(code),
          },
          position: _int(m, 'position') ?? 0,
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
        );
      }(),
  ];

  static List<PlannerSetup> _decodeSetups(Map<String, Object?> root) => [
    for (final item in _list(root, 'plannerSetups'))
      () {
        final m = _map(item, 'plannerSetup');
        final id = _string(m, 'id', required: true);
        if (id.isEmpty) {
          throw const BackupFormatException(
            BackupError.invalid,
            'plannerSetups',
          );
        }
        return PlannerSetup(
          id: id,
          name: _string(m, 'name'),
          slots: [
            for (final raw in _list(m, 'slots')) ?PlannerSlot.fromJson(raw),
          ],
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
        );
      }(),
  ];

  static List<MealSlot> _decodeSlots(Map<String, Object?> root) => [
    for (final item in _list(root, 'mealSlots'))
      () {
        final m = _map(item, 'mealSlot');
        final id = _string(m, 'id', required: true);
        final name = _string(m, 'name', required: true).trim();
        if (id.isEmpty || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'mealSlots');
        }
        return MealSlot(
          id: id,
          name: name,
          position: _int(m, 'position') ?? 0,
          hidden: m['hidden'] == true,
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
        );
      }(),
  ];

  static List<PlannedMeal> _decodeMeals(Map<String, Object?> root) => [
    for (final item in _list(root, 'plannedMeals'))
      () {
        final m = _map(item, 'plannedMeal');
        final id = _string(m, 'id', required: true);
        final day = PlannedMeal.parseDay(_string(m, 'day', required: true));
        final slot = _string(m, 'slot', required: true);
        if (id.isEmpty || day == null || slot.isEmpty) {
          throw const BackupFormatException(
            BackupError.invalid,
            'plannedMeals',
          );
        }
        return PlannedMeal(
          id: id,
          day: day,
          slotId: slot,
          recipeId: m['recipe'] is String ? m['recipe'] as String : null,
          recipeTitle: _string(m, 'recipeTitle'),
          servings: _int(m, 'servings'),
          note: _string(m, 'note'),
          leftoverOf: m['leftoverOf'] is String
              ? m['leftoverOf'] as String
              : null,
          position: _int(m, 'position') ?? 0,
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
        );
      }(),
  ];

  static List<ShoppingList> _decodeLists(Map<String, Object?> root) {
    final lists = <ShoppingList>[];
    for (final item in _list(root, 'shoppingLists')) {
      final m = _map(item, 'shoppingList');
      final id = _string(m, 'id', required: true);
      if (id.isEmpty) {
        throw const BackupFormatException(BackupError.invalid, 'shoppingList');
      }
      lists.add(
        ShoppingList(
          id: id,
          name: _string(m, 'name'),
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
          items: [
            for (final raw in _list(m, 'items'))
              () {
                final i = _map(raw, 'shoppingItem');
                return ShoppingItem(
                  id: _string(i, 'id', required: true),
                  name: _string(i, 'name'),
                  quantity: _double(i, 'quantity'),
                  unit: _string(i, 'unit'),
                  toBuy: _string(i, 'toBuy'),
                  format: _string(i, 'format'),
                  note: _string(i, 'note'),
                  aisleId: i['aisle'] is String ? i['aisle'] as String : null,
                  checked: i['checked'] == true,
                  sources: [
                    for (final rawSource in _list(i, 'sources'))
                      () {
                        final s = _map(rawSource, 'source');
                        return ShoppingSource(
                          recipeId: _string(s, 'recipe', required: true),
                          recipeTitle: _string(s, 'title'),
                          quantity: _double(s, 'quantity'),
                          unit: _string(s, 'unit'),
                        );
                      }(),
                  ],
                );
              }(),
          ],
        ),
      );
    }
    return lists;
  }

  static List<Aisle> _decodeAisles(Map<String, Object?> root) => [
    for (final item in _list(root, 'aisles'))
      () {
        final m = _map(item, 'aisle');
        final id = _string(m, 'id', required: true);
        final name = _string(m, 'name', required: true).trim();
        if (id.isEmpty || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'aisles');
        }
        return Aisle(
          id: id,
          name: name,
          position: _int(m, 'position') ?? 0,
          createdAt: _date(m, 'createdAt')!,
          updatedAt: _date(m, 'updatedAt')!,
          deletedAt: _date(m, 'deletedAt', required: false),
        );
      }(),
  ];

  static List<ProductAisle> _decodeProductAisles(Map<String, Object?> root) => [
    for (final item in _list(root, 'productAisles'))
      () {
        final m = _map(item, 'productAisle');
        final key = _string(m, 'key', required: true);
        final aisle = _string(m, 'aisle', required: true);
        if (key.isEmpty || aisle.isEmpty) {
          throw const BackupFormatException(
            BackupError.invalid,
            'productAisles',
          );
        }
        return ProductAisle(
          key: key,
          aisleId: aisle,
          updatedAt: _date(m, 'updatedAt')!,
        );
      }(),
  ];

  static Recipe _decodeRecipe(Object? json, int version) {
    final m = _map(json, 'recipe');
    final id = _string(m, 'id', required: true);
    if (id.isEmpty) {
      throw const BackupFormatException(BackupError.invalid, 'id');
    }
    final photo = m['mainPhoto'];
    if (photo != null && (photo is! String || !PhotoStore.isValidName(photo))) {
      throw BackupFormatException(BackupError.invalid, 'mainPhoto $id');
    }
    final extraPhotos = _strings(m, 'extraPhotos');
    if (!extraPhotos.every(PhotoStore.isValidName)) {
      throw BackupFormatException(BackupError.invalid, 'extraPhotos $id');
    }
    final rating = _int(m, 'rating');
    if (rating != null && (rating < 1 || rating > 5)) {
      throw BackupFormatException(BackupError.invalid, 'rating $id');
    }
    return Recipe(
      id: id,
      title: _string(m, 'title'),
      description: _string(m, 'description'),
      source: _string(m, 'source'),
      notes: version >= 2
          ? _string(m, 'notes')
          : _mergeNotes(_string(m, 'notes'), _string(m, 'tips')),
      servings: _int(m, 'servings'),
      servingsUnit: _string(m, 'servingsUnit'),
      prepMinutes: _int(m, 'prepMinutes'),
      cookMinutes: _int(m, 'cookMinutes'),
      restMinutes: _int(m, 'restMinutes'),
      timesCooked: _int(m, 'timesCooked') ?? 0,
      mainPhoto: photo as String?,
      extraPhotos: extraPhotos,
      isFavorite: m['favorite'] == true,
      rating: rating,
      status: RecipeStatus.fromCode(
        m['status'] is String ? m['status'] as String : null,
      ),
      labelIds: version >= 7 ? _strings(m, 'labels') : const [],
      equipmentIds: version >= 6 ? _strings(m, 'equipment') : const [],
      videoLinks: _strings(m, 'videoLinks'),
      createdAt: _date(m, 'createdAt')!,
      updatedAt: _date(m, 'updatedAt')!,
      deletedAt: _date(m, 'deletedAt', required: false),
      ingredients: [
        for (final item in _list(m, 'ingredients'))
          () {
            final i = _map(item, 'ingredient');
            return IngredientLine(
              id: _string(i, 'id', required: true),
              isSection: i['section'] == true,
              name: _string(i, 'name'),
              quantity: _double(i, 'quantity'),
              unit: _string(i, 'unit'),
              note: _string(i, 'note'),
              optional: i['optional'] == true,
              substitutes: _string(i, 'substitutes'),
              linkedRecipeId: i['linkedRecipe'] is String
                  ? i['linkedRecipe'] as String
                  : null,
            );
          }(),
      ],
      steps: [
        for (final item in _list(m, 'steps'))
          () {
            final s = _map(item, 'step');
            return RecipeStep(
              id: _string(s, 'id', required: true),
              title: _string(s, 'title'),
              text: _string(s, 'text'),
            );
          }(),
      ],
    );
  }

  /// v1 : « Astuces » et « Notes » étaient deux champs ; ils n'en font plus qu'un.
  static String _mergeNotes(String notes, String tips) {
    final a = notes.trim(), b = tips.trim();
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a\n\n$b';
  }

  static Map<String, Object?> _map(Object? value, String what) {
    if (value is Map<String, Object?>) return value;
    throw BackupFormatException(BackupError.invalid, what);
  }

  static List<Object?> _list(Map<String, Object?> m, String key) {
    final value = m[key];
    if (value == null) return const [];
    if (value is List) return value;
    throw BackupFormatException(BackupError.invalid, key);
  }

  static List<String> _strings(Map<String, Object?> m, String key) {
    final list = _list(m, key);
    if (list.every((item) => item is String)) return list.cast<String>();
    throw BackupFormatException(BackupError.invalid, key);
  }

  static String _string(
    Map<String, Object?> m,
    String key, {
    bool required = false,
  }) {
    final value = m[key];
    if (value is String) return value;
    if (value == null && !required) return '';
    throw BackupFormatException(BackupError.invalid, key);
  }

  static int? _int(Map<String, Object?> m, String key) {
    final value = m[key];
    if (value == null) return null;
    if (value is int && value >= 0) return value;
    throw BackupFormatException(BackupError.invalid, key);
  }

  static double? _double(Map<String, Object?> m, String key) {
    final value = m[key];
    if (value == null) return null;
    if (value is num && value >= 0) return value.toDouble();
    throw BackupFormatException(BackupError.invalid, key);
  }

  static DateTime? _date(
    Map<String, Object?> m,
    String key, {
    bool required = true,
  }) {
    final value = m[key];
    if (value == null && !required) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) throw BackupFormatException(BackupError.invalid, key);
    return parsed.toLocal();
  }
}

/// Ce que contient une sauvegarde lue : les recettes, le matériel, le
/// classement et les courses.
class BackupData {
  const BackupData(
    this.recipes,
    this.equipment,
    this.labels, {
    this.shoppingLists = const [],
    this.aisles = const [],
    this.productAisles = const [],
    this.mealSlots = const [],
    this.plannedMeals = const [],
    this.sideDishes = const [],
    this.plannerSetups = const [],
  });

  final List<Recipe> recipes;
  final List<EquipmentItem> equipment;
  final List<Label> labels;
  final List<ShoppingList> shoppingLists;
  final List<Aisle> aisles;
  final List<ProductAisle> productAisles;
  final List<MealSlot> mealSlots;
  final List<PlannedMeal> plannedMeals;
  final List<SideDish> sideDishes;
  final List<PlannerSetup> plannerSetups;
}

enum BackupError { notABackup, newerVersion, invalid, missingPhoto }

class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail = '']);

  final BackupError error;
  final String detail;

  @override
  String toString() => 'BackupFormatException($error, $detail)';
}
