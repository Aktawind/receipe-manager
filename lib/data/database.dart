import 'package:drift/drift.dart';

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
  TextColumn get tips => text().withDefault(const Constant(''))();
  IntColumn get servings => integer().nullable()();
  IntColumn get prepMinutes => integer().nullable()();
  IntColumn get cookMinutes => integer().nullable()();
  IntColumn get restMinutes => integer().nullable()();
  IntColumn get timesCooked => integer().withDefault(const Constant(0))();
  TextColumn get mainPhoto => text().nullable()();
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('StepRow')
class RecipeSteps extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get body => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Recipes, Ingredients, RecipeSteps])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Toute modification du schéma : incrémenter, écrire la migration, puis
  /// `dart run drift_dev make-migrations` (voir CLAUDE.md).
  static const latestSchemaVersion = 1;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
