import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import '../domain/equipment.dart';

import 'database.steps.dart';

part 'database.g.dart';

/// Une recette. Les identifiants sont des UUID générés sur l'appareil, et une
/// suppression ne fait que remplir [deletedAt] (corbeille, puis synchro).
@DataClassName('RecipeRow')
class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Ancien champ « Astuces », fusionné dans [notes] par la migration v2.
  /// Toujours vide : la colonne reste pour ne pas reconstruire la table.
  TextColumn get tips => text().withDefault(const Constant(''))();
  IntColumn get servings => integer().nullable()();

  /// « blinis », « ramequins »… ; vide = des personnes. Ajouté en v4.
  TextColumn get servingsUnit => text().withDefault(const Constant(''))();
  IntColumn get prepMinutes => integer().nullable()();
  IntColumn get cookMinutes => integer().nullable()();
  IntColumn get restMinutes => integer().nullable()();
  IntColumn get timesCooked => integer().withDefault(const Constant(0))();
  TextColumn get mainPhoto => text().nullable()();

  /// Favori ; ajouté en v3.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Note de 1 à 5, `null` si non notée ; ajouté en v3.
  IntColumn get rating => integer().nullable()();

  /// `toTest`, `validated`, `toImprove` ou `null` ; ajouté en v3.
  TextColumn get status => text().nullable()();

  /// Type de plat, catégorie et collections (une par ligne) en texte libre
  /// en attendant le classement complet de la 0.3 ; ajoutés en v3.
  TextColumn get course => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get collections => text().withDefault(const Constant(''))();

  /// Liens vidéo, un par ligne ; ajouté en v5. [equipment] (matériel en texte,
  /// v5) est vidé par la migration v6 : le matériel est dans [RecipeEquipment].
  TextColumn get equipment => text().withDefault(const Constant(''))();
  TextColumn get videoLinks => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('IngredientRow')
class Ingredients extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  BoolColumn get isSection => boolean().withDefault(const Constant(false))();
  TextColumn get name => text().withDefault(const Constant(''))();
  RealColumn get quantity => real().nullable()();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get optional => boolean().withDefault(const Constant(false))();

  /// Remplaçants possibles de l'ingrédient ; ajouté en v5.
  TextColumn get substitutes => text().withDefault(const Constant(''))();

  /// Recette qu'est cet ingrédient (pâte, sauce) ; ajouté en v6.
  TextColumn get linkedRecipeId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StepRow')
class RecipeSteps extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  /// Titre optionnel de la partie (« Biscuit ») ; ajouté en v2.
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Photos d'une recette en plus de la principale ([Recipes.mainPhoto]) ; v3.
@DataClassName('ExtraPhotoRow')
class RecipePhotos extends Table {
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get file => text()();

  @override
  Set<Column<Object>> get primaryKey => {recipeId, position};
}

/// La liste commune du matériel (moules, robots…) ; v6. Suppression douce.
@DataClassName('EquipmentRow')
class EquipmentItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Le matériel nécessaire à une recette ; v6.
@DataClassName('RecipeEquipmentRow')
class RecipeEquipment extends Table {
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get equipmentId => text()();

  @override
  Set<Column<Object>> get primaryKey => {recipeId, position};
}

@DriftDatabase(
  tables: [
    Recipes,
    Ingredients,
    RecipeSteps,
    RecipePhotos,
    EquipmentItems,
    RecipeEquipment,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Toute modification du schéma : incrémenter, écrire la migration, puis
  /// `dart run drift_dev make-migrations` (voir CLAUDE.md).
  static const latestSchemaVersion = 6;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: stepByStep(
      // v2 : titres d'étapes, et « Astuces » fusionnées dans « Notes ».
      from1To2: (m, schema) async {
        await m.addColumn(schema.recipeSteps, schema.recipeSteps.title);
        await customStatement('''
UPDATE recipes SET
  notes = CASE
    WHEN trim(tips) = '' THEN notes
    WHEN trim(notes) = '' THEN trim(tips)
    ELSE trim(notes) || char(10) || char(10) || trim(tips)
  END,
  tips = ''
''');
      },
      // v3 : favoris, note, statut, classement libre, photos supplémentaires
      // et recettes liées.
      from2To3: (m, schema) async {
        await m.addColumn(schema.recipes, schema.recipes.isFavorite);
        await m.addColumn(schema.recipes, schema.recipes.rating);
        await m.addColumn(schema.recipes, schema.recipes.status);
        await m.addColumn(schema.recipes, schema.recipes.course);
        await m.addColumn(schema.recipes, schema.recipes.category);
        await m.addColumn(schema.recipes, schema.recipes.collections);
        await m.createTable(schema.recipePhotos);
        await m.createTable(schema.recipeLinks);
      },
      // v4 : ce que comptent les portions (« 12 blinis »). L'import de la
      // 0.2 de test avait gardé ces quantités en tête des notes
      // (« Quantité : 12 blinis ») : elles redeviennent des portions.
      from3To4: (m, schema) async {
        await m.addColumn(schema.recipes, schema.recipes.servingsUnit);
        final rows = await m.database
            .customSelect(
              'SELECT id, notes FROM recipes '
              "WHERE servings IS NULL AND notes LIKE 'Quantité : %'",
            )
            .get();
        for (final row in rows) {
          final notes = row.read<String>('notes');
          final newline = notes.indexOf('\n');
          final first = newline < 0 ? notes : notes.substring(0, newline);
          final match = RegExp(r'^Quantité : (\d+)\s+(\S.*)$')
              .firstMatch(first.trim());
          if (match == null) continue;
          await m.database.customUpdate(
            'UPDATE recipes SET servings = ?, servings_unit = ?, notes = ? '
            'WHERE id = ?',
            variables: [
              Variable.withInt(int.parse(match.group(1)!)),
              Variable.withString(match.group(2)!.trim()),
              Variable.withString(
                newline < 0 ? '' : notes.substring(newline + 1).trim(),
              ),
              Variable.withString(row.read<String>('id')),
            ],
          );
        }
      },
      // v5 : matériel, liens vidéo et remplaçants d'ingrédients.
      from4To5: (m, schema) async {
        await m.addColumn(schema.recipes, schema.recipes.equipment);
        await m.addColumn(schema.recipes, schema.recipes.videoLinks);
        await m.addColumn(schema.ingredients, schema.ingredients.substitutes);
      },
      // v6 : le matériel devient une liste commune, et les recettes liées
      // passent dans les ingrédients.
      from5To6: (m, schema) async {
        await m.createTable(schema.equipmentItems);
        await m.createTable(schema.recipeEquipment);
        await m.addColumn(
          schema.ingredients,
          schema.ingredients.linkedRecipeId,
        );
        await _equipmentTextToCatalog();
        await _linksToIngredients();
        await customStatement('DROP TABLE IF EXISTS recipe_links');
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Matériel saisi en texte (un par ligne, v5) → liste commune. Un même nom,
  /// à la casse et aux accents près, donne un seul matériel.
  Future<void> _equipmentTextToCatalog() async {
    final rows = await customSelect(
      "SELECT id, equipment FROM recipes WHERE equipment != ''",
    ).get();
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      final recipeId = row.read<String>('id');
      final seen = <String>{};
      var position = 0;
      for (final raw in row.read<String>('equipment').split('\n')) {
        final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (name.isEmpty) continue;
        final id = EquipmentItem.idForName(name);
        if (!seen.add(id)) continue;
        await customStatement(
          'INSERT OR IGNORE INTO equipment_items '
          '(id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
          [id, name, now, now],
        );
        await customStatement(
          'INSERT INTO recipe_equipment (recipe_id, position, equipment_id) '
          'VALUES (?, ?, ?)',
          [recipeId, position++, id],
        );
      }
    }
    await customStatement("UPDATE recipes SET equipment = ''");
  }

  /// Recettes liées (v3 à v5) → lignes d'ingrédients. Une ligne qui porte déjà
  /// le nom de la recette liée devient le lien ; sinon une ligne est ajoutée.
  Future<void> _linksToIngredients() async {
    final links = await customSelect(
      'SELECT recipe_id, linked_recipe_id FROM recipe_links '
      'ORDER BY recipe_id, position',
    ).get();
    for (final link in links) {
      final recipeId = link.read<String>('recipe_id');
      final linkedId = link.read<String>('linked_recipe_id');
      final titles = await customSelect(
        'SELECT title FROM recipes WHERE id = ?',
        variables: [Variable.withString(linkedId)],
      ).get();
      if (titles.isEmpty) continue;
      final title = titles.first.read<String>('title').trim();
      if (title.isEmpty) continue;
      final already = await customSelect(
        'SELECT 1 FROM ingredients WHERE recipe_id = ? AND linked_recipe_id = ?',
        variables: [
          Variable.withString(recipeId),
          Variable.withString(linkedId),
        ],
      ).get();
      if (already.isNotEmpty) continue;

      final lines = await customSelect(
        'SELECT id, name FROM ingredients WHERE recipe_id = ? '
        'AND is_section = 0 AND linked_recipe_id IS NULL',
        variables: [Variable.withString(recipeId)],
      ).get();
      final key = normalizeForSearch(title);
      final match = lines
          .where(
            (l) => normalizeForSearch(l.read<String>('name').trim()) == key,
          )
          .firstOrNull;
      if (match != null) {
        await customStatement(
          'UPDATE ingredients SET name = ?, linked_recipe_id = ? WHERE id = ?',
          [title, linkedId, match.read<String>('id')],
        );
      } else {
        final next = await customSelect(
          'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM ingredients '
          'WHERE recipe_id = ?',
          variables: [Variable.withString(recipeId)],
        ).getSingle();
        await customStatement(
          'INSERT INTO ingredients (id, recipe_id, position, is_section, name, '
          "quantity, unit, note, optional, substitutes, linked_recipe_id) "
          "VALUES (?, ?, ?, 0, ?, NULL, '', '', 0, '', ?)",
          [
            const Uuid().v4(),
            recipeId,
            next.read<int>('next'),
            title,
            linkedId,
          ],
        );
      }
    }
  }
}
