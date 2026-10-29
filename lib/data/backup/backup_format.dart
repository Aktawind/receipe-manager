import '../../domain/equipment.dart';
import '../../domain/label.dart';
import '../../domain/legacy_classification.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_links.dart';
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
/// - v7 : classement commun (`labels` du document, `labels` des recettes =
///   identifiants) à la place de `course`, `category` et `collections`.
abstract final class BackupFormat {
  static const formatName = 'recettes-backup';
  static const currentVersion = 7;
  static const dataFile = 'recettes.json';
  static const photosFolder = 'photos/';

  static Map<String, Object?> encode(
    List<Recipe> recipes, {
    List<EquipmentItem> equipment = const [],
    List<Label> labels = const [],
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
    };
  }

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
      for (final item in _list(root, 'labels')) {
        final m = _map(item, 'label');
        final kind = LabelKind.fromCode(
          m['kind'] is String ? m['kind'] as String : null,
        );
        final id = _string(m, 'id', required: true);
        final name = Label.cleanName(_string(m, 'name', required: true));
        if (kind == null || id.isEmpty || name.isEmpty) {
          throw const BackupFormatException(BackupError.invalid, 'labels');
        }
        labels.add(
          Label(
            id: id,
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
    return BackupData(recipes, equipment, labels);
  }

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

/// Ce que contient une sauvegarde lue : les recettes et la liste du matériel.
class BackupData {
  const BackupData(this.recipes, this.equipment, this.labels);

  final List<Recipe> recipes;
  final List<EquipmentItem> equipment;
  final List<Label> labels;
}

enum BackupError { notABackup, newerVersion, invalid, missingPhoto }

class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail = '']);

  final BackupError error;
  final String detail;

  @override
  String toString() => 'BackupFormatException($error, $detail)';
}
