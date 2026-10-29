import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/database.dart';
import 'package:recettes/data/label_repository.dart';
import 'package:recettes/data/recipe_repository.dart';
import 'package:recettes/domain/label.dart';

void main() {
  late AppDatabase db;
  late LabelRepository labels;
  late RecipeRepository recipes;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    labels = LabelRepository(db);
    recipes = RecipeRepository(db);
  });

  tearDown(() => db.close());

  Future<List<String>> names(LabelKind kind) async => [
    for (final l in await labels.watchAll().first)
      if (l.kind == kind) l.name,
  ];

  test('une base neuve contient le classement par défaut', () async {
    expect(await names(LabelKind.category), [
      'Apéritifs et entrées',
      'Plats',
      'Desserts',
      'Goûters',
      'Boissons',
      'Pains',
      'Sauces',
      'Préparations',
    ]);
    expect(await names(LabelKind.tag), [
      'Rapide',
      'Économique',
      'Végétarien',
      'Batch cooking',
    ]);
    expect(await names(LabelKind.season), [
      'Printemps',
      'Été',
      'Automne',
      'Hiver',
      'Toute saison',
    ]);
    expect(await names(LabelKind.meal), contains('Dîner'));
  });

  test(
    'un nom = un élément, à la casse, aux accents et au pluriel près',
    () async {
      final a = await labels.findOrCreate(LabelKind.tag, 'sans gluten');
      expect(a.name, 'Sans gluten');
      final b = await labels.findOrCreate(LabelKind.tag, 'Sans  GLUTEN ');
      expect(b.id, a.id);
      final plats = await labels.findOrCreate(LabelKind.category, 'plat');
      expect(
        plats.name,
        'Plats',
        reason: '« plat » retrouve la catégorie par défaut',
      );

      // Même nom, parents différents : deux éléments.
      final desserts = await labels.findOrCreate(
        LabelKind.category,
        'Desserts',
      );
      final goutes = await labels.findOrCreate(LabelKind.category, 'Goûters');
      final g1 = await labels.findOrCreate(
        LabelKind.category,
        'Gâteaux',
        parentId: desserts.id,
      );
      final g2 = await labels.findOrCreate(
        LabelKind.category,
        'Gâteaux',
        parentId: goutes.id,
      );
      expect(g1.id, isNot(g2.id));
    },
  );

  test('renommer : refusé si le nom existe déjà au même endroit', () async {
    final a = await labels.findOrCreate(LabelKind.tag, 'Fait maison');
    expect(await labels.rename(a.id, 'rapide'), isFalse);
    expect(await labels.rename(a.id, ' '), isFalse);
    expect(await labels.rename(a.id, 'fait main'), isTrue);
    expect(await names(LabelKind.tag), contains('Fait main'));
  });

  test('supprimer : sous-catégories avec, retiré des recettes', () async {
    final plats = await labels.findOrCreate(LabelKind.category, 'Plats');
    final viandes = await labels.findOrCreate(
      LabelKind.category,
      'Viandes',
      parentId: plats.id,
    );
    final recipe = await recipes.save(
      (await recipes.create()).copyWith(labelIds: [viandes.id]),
    );
    expect(await labels.watchUsage().first, {viandes.id: 1});

    await labels.delete(plats.id);
    expect((await names(LabelKind.category)), isNot(contains('Plats')));
    expect(await names(LabelKind.category), isNot(contains('Viandes')));
    final after = (await recipes.getRecipe(recipe.id))!;
    expect(after.labelIds, isEmpty);
    expect(after.updatedAt.isBefore(recipe.updatedAt), isFalse);
    // Suppression douce.
    expect((await labels.getAll()).where((l) => l.isDeleted).length, 2);
    // Retapé, l'élément revient.
    final back = await labels.findOrCreate(LabelKind.category, 'plats');
    expect(back.id, plats.id);
    expect(back.isDeleted, isFalse);
  });

  test('fusionner : recettes sans doublon, sous-catégories déplacées ou fusionnées', () async {
    final desserts = await labels.findOrCreate(LabelKind.category, 'Desserts');
    final goutes = await labels.findOrCreate(LabelKind.category, 'Goûters');
    final gateauxD = await labels.findOrCreate(
      LabelKind.category,
      'Gâteaux',
      parentId: desserts.id,
    );
    final gateauxG = await labels.findOrCreate(
      LabelKind.category,
      'Gâteaux',
      parentId: goutes.id,
    );
    final tartes = await labels.findOrCreate(
      LabelKind.category,
      'Tartes',
      parentId: desserts.id,
    );
    final both = await recipes.save(
      (await recipes.create()).copyWith(labelIds: [desserts.id, goutes.id]),
    );
    final deepOne = await recipes.save(
      (await recipes.create()).copyWith(labelIds: [gateauxD.id]),
    );
    final deepTwo = await recipes.save(
      (await recipes.create()).copyWith(labelIds: [gateauxG.id, tartes.id]),
    );

    await labels.merge(desserts.id, goutes.id);

    final all = {for (final l in await labels.getAll()) l.id: l};
    expect(all[desserts.id]!.isDeleted, isTrue);
    // « Gâteaux » (Desserts) a été fusionné avec « Gâteaux » (Goûters) ;
    // « Tartes » a été déplacée sous Goûters.
    expect(all[gateauxD.id]!.isDeleted, isTrue);
    expect(all[gateauxG.id]!.isDeleted, isFalse);
    expect(all[tartes.id]!.parentId, goutes.id);

    expect((await recipes.getRecipe(both.id))!.labelIds, [goutes.id]);
    expect((await recipes.getRecipe(deepOne.id))!.labelIds, [gateauxG.id]);
    expect((await recipes.getRecipe(deepTwo.id))!.labelIds.toSet(), {
      gateauxG.id,
      tartes.id,
    });
  });

  test('fusionner deux familles différentes ne fait rien', () async {
    final tag = await labels.findOrCreate(LabelKind.tag, 'Rapide');
    final season = await labels.findOrCreate(LabelKind.season, 'Hiver');
    await labels.merge(tag.id, season.id);
    expect((await labels.getAll()).where((l) => l.isDeleted), isEmpty);
  });

  test('icône et couleur', () async {
    final plats = await labels.findOrCreate(LabelKind.category, 'Plats');
    await labels.setStyle(plats.id, icon: 'cake', color: 'caramel');
    final after = (await labels.getAll()).firstWhere((l) => l.id == plats.id);
    expect((after.icon, after.color), ('cake', 'caramel'));
  });

  test(
    'l’ordre d’une recette dans une collection est conservé à l’enregistrement',
    () async {
      final noel = await labels.findOrCreate(LabelKind.collection, 'Noël');
      final a = await recipes.save(
        (await recipes.create()).copyWith(title: 'A', labelIds: [noel.id]),
      );
      final b = await recipes.save(
        (await recipes.create()).copyWith(title: 'B', labelIds: [noel.id]),
      );
      Future<Map<String, int>> order() async => {
        for (final r in await db.select(db.recipeLabels).get())
          r.recipeId: r.sortIndex,
      };
      expect(await order(), {a.id: 0, b.id: 1});
      // Retoucher A ne la renvoie pas en fin de collection.
      await recipes.save(
        (await recipes.getRecipe(a.id))!.copyWith(title: 'A+'),
      );
      expect(await order(), {a.id: 0, b.id: 1});
    },
  );
}
