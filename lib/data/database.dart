import 'package:drift/drift.dart';

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

  /// Matériel nécessaire et liens vidéo, un par ligne ; ajoutés en v5.
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

/// Recettes utilisées par une autre (pâte, sauce) ; v3. [linkedRecipeId] n'est
/// pas une clé étrangère : la recette liée peut être supprimée sans perdre
/// celle qui l'utilise.
@DataClassName('RecipeLinkRow')
class RecipeLinks extends Table {
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get linkedRecipeId => text()();

  @override
  Set<Column<Object>> get primaryKey => {recipeId, position};
}

@DriftDatabase(
  tables: [Recipes, Ingredients, RecipeSteps, RecipePhotos, RecipeLinks],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Toute modification du schéma : incrémenter, écrire la migration, puis
  /// `dart run drift_dev make-migrations` (voir CLAUDE.md).
  static const latestSchemaVersion = 5;

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
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
