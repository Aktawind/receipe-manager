import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/recipe.dart';

void main() {
  late AppDatabase db;
  late RecipeRepository repo;
  var now = DateTime(2026, 10, 27, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecipeRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Recipe sample(Recipe base) => base.copyWith(
    title: 'Quiche lorraine',
    servings: () => 6,
    prepMinutes: () => 20,
    cookMinutes: () => 35,
    ingredients: const [
      IngredientLine(id: 'i1', isSection: true, name: 'Pour la pâte'),
      IngredientLine(id: 'i2', name: 'farine', quantity: 250, unit: 'g'),
      IngredientLine(id: 'i3', name: 'sel', note: 'une pincée'),
    ],
    steps: const [
      RecipeStep(id: 's1', text: 'Préparer la pâte.'),
      RecipeStep(id: 's2', text: 'Cuire 35 min.'),
    ],
  );

  test('enregistre et relit une recette complète, dans l’ordre', () async {
    final created = await repo.create();
    await repo.save(sample(created));

    final read = (await repo.getRecipe(created.id))!;
    expect(read.title, 'Quiche lorraine');
    expect(read.servings, 6);
    expect(read.totalMinutes, 55);
    expect(read.ingredients.map((i) => i.id), ['i1', 'i2', 'i3']);
    expect(read.ingredients[1].quantity, 250);
    expect(read.ingredients[0].isSection, isTrue);
    expect(read.steps.map((s) => s.text), [
      'Préparer la pâte.',
      'Cuire 35 min.',
    ]);
  });

  test('réordonner les ingrédients est conservé', () async {
    final created = await repo.create();
    final recipe = sample(created);
    await repo.save(
      recipe.copyWith(ingredients: recipe.ingredients.reversed.toList()),
    );
    final read = (await repo.getRecipe(created.id))!;
    expect(read.ingredients.map((i) => i.id), ['i3', 'i2', 'i1']);
  });

  test('l’enregistrement met à jour la date de modification', () async {
    final created = await repo.create();
    now = now.add(const Duration(hours: 1));
    final saved = await repo.save(created.copyWith(title: 'Tarte'));
    expect(saved.updatedAt, now);
    expect(saved.createdAt, created.createdAt);
  });

  test('corbeille : supprimer, restaurer, vider', () async {
    final a = await repo.create();
    final b = await repo.create();
    await repo.moveToTrash(a.id);

    expect((await repo.watchRecipes().first).map((r) => r.id), [b.id]);
    expect((await repo.watchTrash().first).map((r) => r.id), [a.id]);

    await repo.restore(a.id);
    expect(await repo.watchTrash().first, isEmpty);

    await repo.moveToTrash(a.id);
    now = now.add(const Duration(days: 31));
    await repo.purgeTrash(before: now.subtract(const Duration(days: 30)));
    expect(await repo.getRecipe(a.id), isNull);
    expect(await repo.getRecipe(b.id), isNotNull);
  });

  test(
    'suppression définitive : renvoie les photos devenues inutiles',
    () async {
      final a = await repo.save(
        (await repo.create()).copyWith(mainPhoto: () => 'a.jpg'),
      );
      final b = await repo.save(
        (await repo.create()).copyWith(mainPhoto: () => 'shared.jpg'),
      );
      final c = await repo.save(
        (await repo.create()).copyWith(mainPhoto: () => 'shared.jpg'),
      );
      expect(await repo.deletePermanently([a.id, b.id]), {'a.jpg'});
      expect(await repo.getRecipe(c.id), isNotNull);
    },
  );

  test('dupliquer crée de nouveaux identifiants', () async {
    final original = await repo.save(sample(await repo.create()));
    final copy = (await repo.duplicate(original.id, titleSuffix: ' (copie)'))!;
    expect(copy.id, isNot(original.id));
    expect(copy.title, 'Quiche lorraine (copie)');
    expect(copy.ingredients.length, 3);
    expect(
      copy.ingredients.map((i) => i.id).toSet().intersection({'i1', 'i2'}),
      isEmpty,
    );
    final read = (await repo.getRecipe(copy.id))!;
    expect(read.steps.length, 2);
  });

  test('compteur de réalisations', () async {
    final r = await repo.create();
    await repo.incrementTimesCooked(r.id, 1);
    await repo.incrementTimesCooked(r.id, 1);
    expect((await repo.getRecipe(r.id))!.timesCooked, 2);
    await repo.incrementTimesCooked(r.id, -5);
    expect((await repo.getRecipe(r.id))!.timesCooked, 0);
  });
}
