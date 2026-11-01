import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/label.dart';
import 'package:recettes/domain/recipe.dart';

import '../helpers/test_app.dart';

/// Trois recettes classées : Axoa (Plats › Viandes, Hiver), Boulgour (Plats ›
/// Salades, Été, favorite) et Cake citron (Desserts, Hiver).
Future<void> seed(TestApp app, {bool collection = false}) async {
  final labels = app.services.labels;
  final recipes = app.services.recipes;
  final plats = await labels.findOrCreate(LabelKind.category, 'Plats');
  final desserts = await labels.findOrCreate(LabelKind.category, 'Desserts');
  final viandes = await labels.findOrCreate(
    LabelKind.category,
    'Viandes',
    parentId: plats.id,
  );
  final salades = await labels.findOrCreate(
    LabelKind.category,
    'Salades',
    parentId: plats.id,
  );
  final hiver = await labels.findOrCreate(LabelKind.season, 'Hiver');
  final ete = await labels.findOrCreate(LabelKind.season, 'Été');

  Future<void> add(String title, List<String> ids, {bool fav = false}) async {
    final created = await recipes.create();
    await recipes.save(
      created.copyWith(title: title, labelIds: ids, isFavorite: fav),
    );
  }

  // Écrire avant d'afficher l'écran : une base qu'écoutent déjà des flux se
  // débloque mal depuis un test de widget.
  final noel = collection
      ? await labels.findOrCreate(LabelKind.collection, 'Noël')
      : null;
  await add('Axoa', [viandes.id, hiver.id, ?noel?.id]);
  await add('Boulgour', [salades.id, ete.id, ?noel?.id], fav: true);
  await add('Cake citron', [desserts.id, hiver.id, ?noel?.id]);

  if (noel != null) {
    final ids = {
      for (final recipe in await recipes.getAllWithDetails())
        recipe.title: recipe.id,
    };
    await labels.setOrder(noel.id, [
      ids['Cake citron']!,
      ids['Boulgour']!,
      ids['Axoa']!,
    ]);
  }
}

Future<TestApp> setUpLibrary(
  WidgetTester tester, {
  bool collection = false,
}) async {
  usePhoneSize(tester);
  final app = (await tester.runAsync(TestApp.create))!;
  await tester.runAsync(() => seed(app, collection: collection));
  await app.pump(tester);
  return app;
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtrer'));
  await settle(tester);
}

/// Ouvre la liste d'une famille dans la fenêtre de filtre, coche ces éléments
/// et valide.
Future<void> pickFor(
  WidgetTester tester,
  String family,
  List<String> items,
) async {
  await tester.tap(find.text(family));
  await settle(tester);
  for (final item in items) {
    await tester.tap(find.widgetWithText(CheckboxListTile, item));
    await tester.pump();
  }
  await tester.tap(find.text('Valider'));
  await settle(tester);
}

/// Choisit « Afficher » : Toutes ou Favoris.
Future<void> showOnly(WidgetTester tester, String what) async {
  await tester.tap(find.text('Afficher'));
  await settle(tester);
  await tester.tap(find.text(what));
  await settle(tester);
}

Future<void> done(WidgetTester tester) async {
  await tester.tap(find.text('Terminé'));
  await settle(tester);
}

void main() {
  testWidgets('filtrer par classement : listes à cocher par famille', (
    tester,
  ) async {
    await setUpLibrary(tester);
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Boulgour'), findsOneWidget);
    expect(find.text('Cake citron'), findsOneWidget);

    // Catégories : « Plats » inclut ses sous-catégories (Viandes + Salades).
    await openFilters(tester);
    await pickFor(tester, 'Catégories', ['Plats']);
    await done(tester);
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Boulgour'), findsOneWidget);
    expect(find.text('Cake citron'), findsNothing);

    // Familles différentes : les deux conditions (Plats ET Hiver).
    await openFilters(tester);
    await pickFor(tester, 'Saison', ['Hiver']);
    await done(tester);
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Boulgour'), findsNothing);

    // Même famille (saisons) : l'une ou l'autre (Hiver OU Été).
    await openFilters(tester);
    await pickFor(tester, 'Saison', ['Été']);
    await done(tester);
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Boulgour'), findsOneWidget);

    await openFilters(tester);
    await tester.tap(find.text('Tout effacer'));
    await settle(tester);
    await done(tester);
    expect(find.text('Cake citron'), findsOneWidget);
  });

  testWidgets('collections : toutes celles qui sont cochées', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final labels = app.services.labels;
      final recipes = app.services.recipes;
      final vege = await labels.findOrCreate(
        LabelKind.collection,
        'Végétarien',
      );
      final paques = await labels.findOrCreate(LabelKind.collection, 'Pâques');
      Future<void> add(String title, List<String> ids) async {
        final created = await recipes.create();
        await recipes.save(created.copyWith(title: title, labelIds: ids));
      }

      await add('Gratin', [vege.id]);
      await add('Agneau', [paques.id]);
      await add('Tarte aux légumes', [vege.id, paques.id]);
    });
    await app.pump(tester);

    await openFilters(tester);
    await pickFor(tester, 'Collections', ['Végétarien']);
    await done(tester);
    expect(find.text('Gratin'), findsOneWidget);
    expect(find.text('Tarte aux légumes'), findsOneWidget);
    expect(find.text('Agneau'), findsNothing);

    // Végétarien ET Pâques : seulement la recette qui est dans les deux.
    await openFilters(tester);
    await pickFor(tester, 'Collections', ['Pâques']);
    await done(tester);
    expect(find.text('Tarte aux légumes'), findsOneWidget);
    expect(find.text('Gratin'), findsNothing);
    expect(find.text('Agneau'), findsNothing);
  });

  testWidgets('accès rapide : favoris ; plus de filtre « récemment »', (
    tester,
  ) async {
    await setUpLibrary(tester);

    await openFilters(tester);
    await tester.tap(find.text('Afficher'));
    await settle(tester);
    expect(find.text('Récemment consultées'), findsNothing);
    expect(find.text('Récemment ajoutées'), findsNothing);
    await tester.tap(find.text('Favoris'));
    await settle(tester);
    await done(tester);
    expect(find.text('Boulgour'), findsOneWidget);
    expect(find.text('Axoa'), findsNothing);

    await openFilters(tester);
    await showOnly(tester, 'Toutes');
    await done(tester);
    expect(find.text('Axoa'), findsOneWidget);
  });

  testWidgets(
    'recherche dans les ingrédients, faute de frappe tolérée, historique',
    (tester) async {
      usePhoneSize(tester);
      final app = (await tester.runAsync(TestApp.create))!;
      await tester.runAsync(() async {
        Future<void> add(String title, List<String> ingredients) async {
          final created = await app.services.recipes.create();
          await app.services.recipes.save(
            created.copyWith(
              title: title,
              ingredients: [
                for (final (i, name) in ingredients.indexed)
                  IngredientLine(id: '$title$i', name: name),
              ],
            ),
          );
        }

        await add('Brownie', ['chocolat noir', 'beurre', 'œufs']);
        await add('Blinis', ['yaourt nature', 'farine', 'œufs']);
        await add('Salade', ['tomates', 'basilic']);
      });
      await app.pump(tester);

      await tester.tap(find.byTooltip('Rechercher'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'oeuf');
      await settle(tester);
      expect(find.text('Brownie'), findsOneWidget);
      expect(find.text('Blinis'), findsOneWidget);
      expect(find.text('Salade'), findsNothing);

      // Une faute de frappe est tolérée ; les mots peuvent venir dans le désordre.
      await tester.enterText(find.byType(TextField), 'chocolta beurre');
      await settle(tester);
      expect(find.text('Brownie'), findsOneWidget);
      expect(find.text('Blinis'), findsNothing);

      // Laissée affichée un instant, la recherche entre dans l'historique.
      await tester.pump(const Duration(seconds: 2));
      expect(app.prefs.getStringList('search_history'), ['chocolta beurre']);
      await tester.tap(find.byTooltip('Fermer la recherche'));
      await settle(tester);
      await tester.tap(find.byTooltip('Rechercher'));
      await settle(tester);
      expect(find.text('Recherches récentes'), findsOneWidget);
      await tester.tap(find.text('chocolta beurre'));
      await settle(tester);
      expect(find.text('Brownie'), findsOneWidget);
    },
  );

  testWidgets('le nombre de recettes est en haut de la liste', (tester) async {
    await setUpLibrary(tester);
    expect(find.text('3 recettes'), findsOneWidget);

    await openFilters(tester);
    await pickFor(tester, 'Saison', ['Hiver']);
    await done(tester);
    expect(find.text('2 sur 3 recettes'), findsOneWidget);
  });

  testWidgets('catégories : seulement les principales dans le filtre', (
    tester,
  ) async {
    await setUpLibrary(tester);
    await openFilters(tester);
    await tester.tap(find.text('Catégories'));
    await settle(tester);
    expect(find.widgetWithText(CheckboxListTile, 'Plats'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Desserts'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Viandes'), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, 'Salades'), findsNothing);
  });

  testWidgets('statut : filtrer et trier', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      Future<void> add(String title, RecipeStatus? status) async {
        final created = await app.services.recipes.create();
        await app.services.recipes.save(
          created.copyWith(title: title, status: () => status),
        );
      }

      await add('Axoa', RecipeStatus.validated);
      await add('Blinis', RecipeStatus.toTest);
      await add('Cake', RecipeStatus.toRetest);
      await add('Dahl', null);
    });
    await app.pump(tester);

    await openFilters(tester);
    await pickFor(tester, 'Statut', ['À tester', 'À retester']);
    await done(tester);
    expect(find.text('Blinis'), findsOneWidget);
    expect(find.text('Cake'), findsOneWidget);
    expect(find.text('Axoa'), findsNothing);
    expect(find.text('Dahl'), findsNothing);

    await openFilters(tester);
    await tester.tap(find.text('Tout effacer'));
    await settle(tester);
    await done(tester);

    // Tri par statut : à tester, à retester, … validée, puis sans statut.
    await tester.tap(find.byTooltip('Affichage'));
    await settle(tester);
    await tester.tap(find.text('Statut').last, warnIfMissed: false);
    await settle(tester);
    double top(String title) {
      final p = tester.getTopLeft(find.text(title));
      return p.dy * 1000 + p.dx;
    }

    expect(top('Blinis') < top('Cake'), isTrue);
    expect(top('Cake') < top('Axoa'), isTrue);
    expect(top('Axoa') < top('Dahl'), isTrue);
  });

  testWidgets('la rangée de pastilles a disparu du haut de la liste', (
    tester,
  ) async {
    await setUpLibrary(tester);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Favoris'), findsNothing);
  });

  testWidgets('vues : cartes et liste, photos toujours affichées', (
    tester,
  ) async {
    await setUpLibrary(tester);

    Future<void> choose(String text) async {
      await tester.tap(find.byTooltip('Affichage'));
      await settle(tester);
      await tester.tap(find.text(text), warnIfMissed: false);
      await settle(tester);
    }

    await choose('Cartes');
    expect(find.text('Axoa'), findsOneWidget);

    await choose('Liste');
    expect(find.byType(ListTile), findsNWidgets(3));

    await tester.tap(find.byTooltip('Affichage'));
    await settle(tester);
    expect(find.text('Afficher les photos'), findsNothing);
  });

  orderPageTests();

  testWidgets('ordre d’une collection : la liste suit l’ordre choisi', (
    tester,
  ) async {
    await setUpLibrary(tester, collection: true);

    await openFilters(tester);
    await pickFor(tester, 'Collections', ['Noël']);
    await done(tester);
    await tester.tap(find.byTooltip('Affichage'));
    await settle(tester);
    await tester.tap(find.text('Ordre de la collection'), warnIfMissed: false);
    await settle(tester);

    // La grille a deux colonnes : on lit de gauche à droite, ligne par ligne.
    double top(String title) {
      final p = tester.getTopLeft(find.text(title));
      return p.dy * 1000 + p.dx;
    }

    expect(top('Cake citron') < top('Boulgour'), isTrue);
    expect(top('Boulgour') < top('Axoa'), isTrue);
  });
}

void orderPageTests() {
  testWidgets('page d’ordre : glisser une recette change l’ordre enregistré', (
    tester,
  ) async {
    final app = await setUpLibrary(tester, collection: true);
    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.text('Classement'));
    await tester.tap(find.text('Classement'));
    await settle(tester);
    await tester.tap(find.text('Collections'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await settle(tester);
    await tester.tap(find.text('Ordonner les recettes'), warnIfMissed: false);
    await settle(tester);

    List<String> titles() =>
        [
          for (final t in ['Cake citron', 'Boulgour', 'Axoa']) t,
        ]..sort(
          (a, b) => tester
              .getTopLeft(find.text(a))
              .dy
              .compareTo(tester.getTopLeft(find.text(b)).dy),
        );
    expect(titles(), ['Cake citron', 'Boulgour', 'Axoa']);

    // On glisse « Axoa » (dernière) tout en haut.
    final handles = find.byIcon(Icons.drag_handle);
    await tester.drag(handles.last, const Offset(0, -300));
    await settle(tester);
    expect(titles().first, 'Axoa');

    final order = await tester.runAsync(() async {
      final recipes = await app.services.recipes.getAllWithDetails();
      final collection = (await app.services.labels.getAll()).firstWhere(
        (l) => l.name == 'Noël' && l.kind == LabelKind.collection,
      );
      final ranks = {
        for (final r in recipes)
          r.title:
              (await app.services.database
                      .select(app.services.database.recipeLabels)
                      .get())
                  .firstWhere(
                    (l) => l.recipeId == r.id && l.labelId == collection.id,
                  )
                  .sortIndex,
      };
      return ranks;
    });
    expect(order!['Axoa'], 0);
  });
}
