import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../core/format/text_search.dart';
import '../domain/default_labels.dart';
import '../domain/equipment.dart';
import '../domain/label.dart';
import '../domain/legacy_classification.dart';

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

  /// Dernière ouverture de la fiche (recettes récentes), propre à l'appareil ;
  /// ajouté en v7. [course], [category] et [collections] (v3) sont vidés par
  /// la migration v7 : le classement est dans [Labels] et [RecipeLabels].
  DateTimeColumn get lastViewedAt => dateTime().nullable()();

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

/// Le classement commun : catégories, collections, étiquettes… ; v7. Suppression
/// douce, identifiants déterministes pour les éléments par défaut.
@DataClassName('LabelRow')
class Labels extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get icon => text().withDefault(const Constant(''))();
  TextColumn get color => text().withDefault(const Constant(''))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Le classement d'une recette ; [sortIndex] est le rang de la recette dans
/// l'élément (ordre personnalisé d'une collection) ; v7.
@DataClassName('RecipeLabelRow')
class RecipeLabels extends Table {
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get labelId => text()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {recipeId, labelId};
}

@DriftDatabase(
  tables: [
    Recipes,
    Ingredients,
    RecipeSteps,
    RecipePhotos,
    EquipmentItems,
    RecipeEquipment,
    Labels,
    RecipeLabels,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Toute modification du schéma : incrémenter, écrire la migration, puis
  /// `dart run drift_dev make-migrations` (voir CLAUDE.md).
  static const latestSchemaVersion = 8;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultLabels(DateTime.now());
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
      // v7 : classement commun (catégories, collections, étiquettes, saisons…).
      from6To7: (m, schema) async {
        await m.addColumn(schema.recipes, schema.recipes.lastViewedAt);
        await m.createTable(schema.labels);
        await m.createTable(schema.recipeLabels);
        await _legacyClassificationToLabels();
      },
      // v8 : le classement se limite à quatre familles ; étiquettes et
      // occasions deviennent des collections, le type de repas disparaît.
      from7To8: (m, schema) async {
        await _foldRemovedLabelKinds();
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

  /// Les catégories, étiquettes et saisons fournies au départ.
  Future<void> _seedDefaultLabels(DateTime now) async {
    for (final label in DefaultLabels.build(now)) {
      await _insertLabel(label);
    }
  }

  Future<void> _insertLabel(Label label) {
    return customStatement(
      'INSERT OR IGNORE INTO labels (id, kind, name, parent_id, icon, color, '
      'position, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        label.id,
        label.kind.code,
        label.name,
        label.parentId,
        label.icon,
        label.color,
        label.position,
        label.createdAt.toUtc().toIso8601String(),
        label.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  /// Type de plat, catégorie et collections en texte libre (v3 à v6) → classement
  /// commun. Voir [LegacyClassification] pour les règles de conversion.
  Future<void> _legacyClassificationToLabels() async {
    final now = DateTime.now();
    await _seedDefaultLabels(now);
    final rows = await customSelect(
      'SELECT id, course, category, collections FROM recipes ORDER BY created_at',
    ).get();
    final plan = LegacyClassification.plan([
      for (final row in rows)
        LegacyEntry(
          recipeId: row.read<String>('id'),
          course: row.read<String>('course'),
          categories: [row.read<String>('category')],
          collections: row.read<String>('collections').split('\n'),
        ),
    ], now);
    for (final label in plan.labels) {
      await _insertLabel(label);
    }
    final next = <String, int>{};
    for (final entry in plan.byRecipe.entries) {
      for (final labelId in entry.value) {
        final index = next.update(labelId, (n) => n + 1, ifAbsent: () => 0);
        await customStatement(
          'INSERT INTO recipe_labels (recipe_id, label_id, sort_index) '
          'VALUES (?, ?, ?)',
          [entry.key, labelId, index],
        );
      }
    }
    await customStatement(
      "UPDATE recipes SET course = '', category = '', collections = ''",
    );
  }

  /// Étiquettes et occasions utilisées → collections du même nom (les
  /// recettes gardent leur classement) ; types de repas et éléments inutilisés
  /// supprimés. Ces éléments n'ont jamais été synchronisés : suppression
  /// définitive.
  Future<void> _foldRemovedLabelKinds() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final removed = await customSelect(
      "SELECT id, kind, name FROM labels WHERE kind IN ('tag', 'occasion', 'meal')",
    ).get();
    for (final row in removed) {
      final id = row.read<String>('id');
      if (row.read<String>('kind') == 'meal') continue;
      final links = await customSelect(
        'SELECT recipe_id FROM recipe_labels WHERE label_id = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (links.isEmpty) continue;

      final name = row.read<String>('name');
      final target = Label.idFor(LabelKind.collection, name);
      final position = await customSelect(
        "SELECT COUNT(*) AS n FROM labels WHERE kind = 'collection'",
      ).getSingle();
      await customStatement(
        'INSERT OR IGNORE INTO labels (id, kind, name, parent_id, icon, color, '
        "position, created_at, updated_at) VALUES (?, 'collection', ?, NULL, '', '', ?, ?, ?)",
        [target, name, position.read<int>('n'), now, now],
      );
      for (final link in links) {
        final recipeId = link.read<String>('recipe_id');
        final already = await customSelect(
          'SELECT 1 FROM recipe_labels WHERE recipe_id = ? AND label_id = ?',
          variables: [
            Variable.withString(recipeId),
            Variable.withString(target),
          ],
        ).get();
        if (already.isNotEmpty) continue;
        await customStatement(
          'INSERT INTO recipe_labels (recipe_id, label_id, sort_index) VALUES '
          '(?, ?, (SELECT COALESCE(MAX(sort_index), -1) + 1 FROM recipe_labels '
          'WHERE label_id = ?))',
          [recipeId, target, target],
        );
      }
    }
    await customStatement(
      'DELETE FROM recipe_labels WHERE label_id IN '
      "(SELECT id FROM labels WHERE kind IN ('tag', 'occasion', 'meal'))",
    );
    await customStatement(
      "DELETE FROM labels WHERE kind IN ('tag', 'occasion', 'meal')",
    );
  }
}
