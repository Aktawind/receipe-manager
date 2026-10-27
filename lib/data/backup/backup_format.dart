import '../../domain/recipe.dart';
import '../photo_store.dart';

/// Format d'échange des sauvegardes, documenté dans docs/FORMAT_EXPORT.md.
///
/// Règle : une version de l'app sait toujours lire les versions précédentes du
/// format. Toute évolution incrémente [currentVersion] et garde la lecture de
/// l'ancienne.
///
/// - v1 : première version (champ `tips` « Astuces »).
/// - v2 : `tips` supprimé (fusionné dans `notes`), titre optionnel des étapes.
abstract final class BackupFormat {
  static const formatName = 'recettes-backup';
  static const currentVersion = 2;
  static const dataFile = 'recettes.json';
  static const photosFolder = 'photos/';

  static Map<String, Object?> encode(
    List<Recipe> recipes, {
    required DateTime exportedAt,
    required String appVersion,
  }) {
    return {
      'format': formatName,
      'version': currentVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'appVersion': appVersion,
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
    'prepMinutes': r.prepMinutes,
    'cookMinutes': r.cookMinutes,
    'restMinutes': r.restMinutes,
    'timesCooked': r.timesCooked,
    'mainPhoto': r.mainPhoto,
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
        },
    ],
    'steps': [
      for (final s in r.steps) {'id': s.id, 'title': s.title, 'text': s.text},
    ],
  };

  /// Lit et valide un document. Lève [BackupFormatException] au moindre
  /// problème : rien n'est importé d'un fichier invalide.
  static List<Recipe> decode(Object? json) {
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
    final recipes = [for (final item in list) _decodeRecipe(item, version)];
    final ids = <String>{};
    for (final recipe in recipes) {
      if (!ids.add(recipe.id)) {
        throw BackupFormatException(BackupError.invalid, 'id ${recipe.id}');
      }
    }
    return recipes;
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
    return Recipe(
      id: id,
      title: _string(m, 'title'),
      description: _string(m, 'description'),
      source: _string(m, 'source'),
      notes: version >= 2
          ? _string(m, 'notes')
          : _mergeNotes(_string(m, 'notes'), _string(m, 'tips')),
      servings: _int(m, 'servings'),
      prepMinutes: _int(m, 'prepMinutes'),
      cookMinutes: _int(m, 'cookMinutes'),
      restMinutes: _int(m, 'restMinutes'),
      timesCooked: _int(m, 'timesCooked') ?? 0,
      mainPhoto: photo as String?,
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

enum BackupError { notABackup, newerVersion, invalid, missingPhoto }

class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail = '']);

  final BackupError error;
  final String detail;

  @override
  String toString() => 'BackupFormatException($error, $detail)';
}
