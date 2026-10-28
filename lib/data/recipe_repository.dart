import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/recipe.dart';
import 'database.dart';

/// Accès aux recettes. Une recette est toujours lue et écrite d'un bloc, avec
/// ses ingrédients et ses étapes, dans une transaction.
class RecipeRepository {
  RecipeRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  static String newId() => _uuid.v4();

  /// Recettes hors corbeille, sans ingrédients ni étapes (pour les listes).
  Stream<List<Recipe>> watchRecipes() {
    final query = _db.select(_db.recipes)..where((r) => r.deletedAt.isNull());
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  /// Recettes dans la corbeille, les plus récemment supprimées d'abord.
  Stream<List<Recipe>> watchTrash() {
    final query = _db.select(_db.recipes)
      ..where((r) => r.deletedAt.isNotNull())
      ..orderBy([(r) => OrderingTerm.desc(r.deletedAt)]);
    return query.watch().map((rows) => rows.map(_fromRow).toList());
  }

  Stream<Recipe?> watchRecipe(String id) {
    final query = _db.select(_db.recipes)..where((r) => r.id.equals(id));
    return query.watchSingleOrNull().asyncMap(
      (row) => row == null ? null : _withChildren(row),
    );
  }

  Future<Recipe?> getRecipe(String id) async {
    final row = await (_db.select(
      _db.recipes,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return row == null ? null : _withChildren(row);
  }

  /// Toutes les recettes, corbeille comprise, avec leurs détails (export).
  Future<List<Recipe>> getAllWithDetails() async {
    final rows = await _db.select(_db.recipes).get();
    return [for (final row in rows) await _withChildren(row)];
  }

  /// Crée une recette vide et renvoie son identifiant.
  Future<Recipe> create() async {
    final now = _clock();
    final recipe = Recipe(id: newId(), createdAt: now, updatedAt: now);
    await _db.transaction(() => _write(recipe));
    return recipe;
  }

  /// Enregistre la recette telle quelle, en mettant à jour sa date de
  /// modification.
  Future<Recipe> save(Recipe recipe) async {
    final saved = recipe.copyWith(updatedAt: _clock());
    await _db.transaction(() => _write(saved));
    return saved;
  }

  /// Écrit la recette sans toucher à ses dates (import, restauration).
  Future<void> put(Recipe recipe) => _db.transaction(() => _write(recipe));

  Future<Recipe?> duplicate(String id, {required String titleSuffix}) async {
    final original = await getRecipe(id);
    if (original == null) return null;
    final now = _clock();
    final copy = Recipe(
      id: newId(),
      title: '${original.title}$titleSuffix'.trim(),
      description: original.description,
      source: original.source,
      notes: original.notes,
      servings: original.servings,
      prepMinutes: original.prepMinutes,
      cookMinutes: original.cookMinutes,
      restMinutes: original.restMinutes,
      mainPhoto: original.mainPhoto,
      extraPhotos: original.extraPhotos,
      isFavorite: original.isFavorite,
      rating: original.rating,
      status: original.status,
      course: original.course,
      category: original.category,
      collections: original.collections,
      linkedRecipeIds: original.linkedRecipeIds,
      createdAt: now,
      updatedAt: now,
      ingredients: [
        for (final line in original.ingredients)
          IngredientLine(
            id: newId(),
            isSection: line.isSection,
            name: line.name,
            quantity: line.quantity,
            unit: line.unit,
            note: line.note,
            optional: line.optional,
          ),
      ],
      steps: [
        for (final step in original.steps)
          RecipeStep(id: newId(), title: step.title, text: step.text),
      ],
    );
    await _db.transaction(() => _write(copy));
    return copy;
  }

  Future<void> incrementTimesCooked(String id, int delta) async {
    await _db.customUpdate(
      'UPDATE recipes SET times_cooked = MAX(0, times_cooked + ?), '
      'updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(delta),
        Variable.withString(_clock().toIso8601String()),
        Variable.withString(id),
      ],
      updates: {_db.recipes},
    );
  }

  Future<void> setFavorite(String id, bool value) {
    return (_db.update(_db.recipes)..where((r) => r.id.equals(id))).write(
      RecipesCompanion(isFavorite: Value(value), updatedAt: Value(_clock())),
    );
  }

  /// Met la recette à la corbeille.
  Future<void> moveToTrash(String id) => _setDeletedAt(id, _clock());

  Future<void> restore(String id) => _setDeletedAt(id, null);

  Future<void> _setDeletedAt(String id, DateTime? value) {
    return (_db.update(_db.recipes)..where((r) => r.id.equals(id))).write(
      RecipesCompanion(deletedAt: Value(value), updatedAt: Value(_clock())),
    );
  }

  /// Supprime définitivement (ingrédients et étapes suivent par cascade).
  /// Renvoie les photos qui ne sont plus utilisées par aucune recette.
  Future<Set<String>> deletePermanently(Iterable<String> ids) async {
    final idList = ids.toList();
    if (idList.isEmpty) return {};
    return _db.transaction(() async {
      final photos = <String>{
        ...(await (_db.selectOnly(_db.recipes)
                  ..addColumns([_db.recipes.mainPhoto])
                  ..where(_db.recipes.id.isIn(idList)))
                .map((row) => row.read(_db.recipes.mainPhoto))
                .get())
            .nonNulls,
        ...(await (_db.select(
          _db.recipePhotos,
        )..where((p) => p.recipeId.isIn(idList))).get()).map((p) => p.file),
      };
      await (_db.delete(_db.recipes)..where((r) => r.id.isIn(idList))).go();
      return _unusedPhotos(photos);
    });
  }

  /// Vide la corbeille des recettes supprimées avant [before].
  Future<Set<String>> purgeTrash({required DateTime before}) async {
    final ids =
        await (_db.selectOnly(_db.recipes)
              ..addColumns([_db.recipes.id])
              ..where(_db.recipes.deletedAt.isSmallerThanValue(before)))
            .map((row) => row.read(_db.recipes.id)!)
            .get();
    return deletePermanently(ids);
  }

  /// Supprime toutes les recettes (import en mode « remplacer »).
  Future<void> deleteAll() => _db.delete(_db.recipes).go();

  Future<T> transaction<T>(Future<T> Function() action) =>
      _db.transaction(action);

  Future<Set<String>> usedPhotos() async {
    final main =
        await (_db.selectOnly(_db.recipes)..addColumns([_db.recipes.mainPhoto]))
            .map((row) => row.read(_db.recipes.mainPhoto))
            .get();
    final extra = await _db.select(_db.recipePhotos).get();
    return {...main.nonNulls, ...extra.map((p) => p.file)};
  }

  Future<Set<String>> _unusedPhotos(Set<String> candidates) async {
    if (candidates.isEmpty) return {};
    return candidates.difference(await usedPhotos());
  }

  Future<void> _write(Recipe recipe) async {
    await _db
        .into(_db.recipes)
        .insertOnConflictUpdate(
          RecipesCompanion.insert(
            id: recipe.id,
            title: Value(recipe.title),
            description: Value(recipe.description),
            source: Value(recipe.source),
            notes: Value(recipe.notes),
            servings: Value(recipe.servings),
            prepMinutes: Value(recipe.prepMinutes),
            cookMinutes: Value(recipe.cookMinutes),
            restMinutes: Value(recipe.restMinutes),
            timesCooked: Value(recipe.timesCooked),
            mainPhoto: Value(recipe.mainPhoto),
            isFavorite: Value(recipe.isFavorite),
            rating: Value(recipe.rating),
            status: Value(recipe.status?.code),
            course: Value(recipe.course),
            category: Value(recipe.category),
            collections: Value(recipe.collections.join('\n')),
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt,
            deletedAt: Value(recipe.deletedAt),
          ),
        );
    await (_db.delete(
      _db.ingredients,
    )..where((i) => i.recipeId.equals(recipe.id))).go();
    await (_db.delete(
      _db.recipeSteps,
    )..where((s) => s.recipeId.equals(recipe.id))).go();
    await (_db.delete(
      _db.recipePhotos,
    )..where((p) => p.recipeId.equals(recipe.id))).go();
    await (_db.delete(
      _db.recipeLinks,
    )..where((l) => l.recipeId.equals(recipe.id))).go();
    await _db.batch((batch) {
      batch.insertAll(_db.recipePhotos, [
        for (final (index, file) in recipe.extraPhotos.indexed)
          RecipePhotosCompanion.insert(
            recipeId: recipe.id,
            position: index,
            file: file,
          ),
      ]);
      batch.insertAll(_db.recipeLinks, [
        for (final (index, linked) in recipe.linkedRecipeIds.indexed)
          RecipeLinksCompanion.insert(
            recipeId: recipe.id,
            position: index,
            linkedRecipeId: linked,
          ),
      ]);
      batch.insertAll(_db.ingredients, [
        for (final (index, line) in recipe.ingredients.indexed)
          IngredientsCompanion.insert(
            id: line.id,
            recipeId: recipe.id,
            position: index,
            isSection: Value(line.isSection),
            name: Value(line.name),
            quantity: Value(line.quantity),
            unit: Value(line.unit),
            note: Value(line.note),
            optional: Value(line.optional),
          ),
      ]);
      batch.insertAll(_db.recipeSteps, [
        for (final (index, step) in recipe.steps.indexed)
          RecipeStepsCompanion.insert(
            id: step.id,
            recipeId: recipe.id,
            position: index,
            title: Value(step.title),
            body: Value(step.text),
          ),
      ]);
    });
  }

  Future<Recipe> _withChildren(RecipeRow row) async {
    final ingredients =
        await (_db.select(_db.ingredients)
              ..where((i) => i.recipeId.equals(row.id))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    final steps =
        await (_db.select(_db.recipeSteps)
              ..where((s) => s.recipeId.equals(row.id))
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();
    final photos =
        await (_db.select(_db.recipePhotos)
              ..where((p) => p.recipeId.equals(row.id))
              ..orderBy([(p) => OrderingTerm.asc(p.position)]))
            .get();
    final links =
        await (_db.select(_db.recipeLinks)
              ..where((l) => l.recipeId.equals(row.id))
              ..orderBy([(l) => OrderingTerm.asc(l.position)]))
            .get();
    return _fromRow(row).copyWith(
      extraPhotos: [for (final p in photos) p.file],
      linkedRecipeIds: [for (final l in links) l.linkedRecipeId],
      ingredients: [
        for (final i in ingredients)
          IngredientLine(
            id: i.id,
            isSection: i.isSection,
            name: i.name,
            quantity: i.quantity,
            unit: i.unit,
            note: i.note,
            optional: i.optional,
          ),
      ],
      steps: [
        for (final s in steps)
          RecipeStep(id: s.id, title: s.title, text: s.body),
      ],
    );
  }

  static Recipe _fromRow(RecipeRow row) => Recipe(
    id: row.id,
    title: row.title,
    description: row.description,
    source: row.source,
    notes: row.notes,
    servings: row.servings,
    prepMinutes: row.prepMinutes,
    cookMinutes: row.cookMinutes,
    restMinutes: row.restMinutes,
    timesCooked: row.timesCooked,
    mainPhoto: row.mainPhoto,
    isFavorite: row.isFavorite,
    rating: row.rating,
    status: RecipeStatus.fromCode(row.status),
    course: row.course,
    category: row.category,
    collections: row.collections.isEmpty
        ? const []
        : row.collections.split('\n'),
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}
