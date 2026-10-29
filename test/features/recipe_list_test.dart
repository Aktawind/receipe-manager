import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/label.dart';

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
  bool tablet = false,
  bool collection = false,
}) async {
  if (tablet) {
    // Toutes les pastilles d'accès rapide tiennent sans faire défiler la rangée.
    tester.view.physicalSize = const Size(2400, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  } else {
    usePhoneSize(tester);
  }
  final app = (await tester.runAsync(TestApp.create))!;
  await tester.runAsync(() => seed(app, collection: collection));
  await app.pump(tester);
  return app;
}

Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Filtrer'));
  await settle(tester);
}

Future<void> tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  await tester.ensureVisible(chip);
  await tester.pump();
  await tester.tap(chip);
  await settle(tester);
}

Future<void> done(WidgetTester tester) async {
  await tester.tap(find.text('Terminé'));
  await settle(tester);
}

void main() {
  testWidgets(
    'filtrer par classement : une catégorie inclut ses sous-catégories',
    (tester) async {
      await setUpLibrary(tester);
      expect(find.text('Axoa'), findsOneWidget);
      expect(find.text('Boulgour'), findsOneWidget);
      expect(find.text('Cake citron'), findsOneWidget);

      await openFilters(tester);
      await tapChip(tester, 'Plats'); // Plats = Viandes + Salades
      await done(tester);
      expect(find.text('Axoa'), findsOneWidget);
      expect(find.text('Boulgour'), findsOneWidget);
      expect(find.text('Cake citron'), findsNothing);

      // Familles différentes : les deux conditions (Plats ET Hiver).
      await openFilters(tester);
      await tapChip(tester, 'Hiver');
      await done(tester);
      expect(find.text('Axoa'), findsOneWidget);
      expect(find.text('Boulgour'), findsNothing);

      // Même famille : l'un ou l'autre (Hiver OU Été).
      await openFilters(tester);
      await tapChip(tester, 'Été');
      await done(tester);
      expect(find.text('Axoa'), findsOneWidget);
      expect(find.text('Boulgour'), findsOneWidget);

      await openFilters(tester);
      await tester.tap(find.text('Tout effacer'));
      await settle(tester);
      await done(tester);
      expect(find.text('Cake citron'), findsOneWidget);
    },
  );

  testWidgets('accès rapides : favoris et récemment consultées', (
    tester,
  ) async {
    await setUpLibrary(tester, tablet: true);

    await tester.tap(find.text('Favoris'));
    await settle(tester);
    expect(find.text('Boulgour'), findsOneWidget);
    expect(find.text('Axoa'), findsNothing);

    // Aucune fiche ouverte : rien de récent.
    await tester.tap(find.text('Récemment consultées'));
    await settle(tester);
    expect(find.text('Axoa'), findsNothing);
    expect(find.text('Boulgour'), findsNothing);

    // On ouvre « Axoa » : elle devient la première récente.
    await tester.tap(find.text('Toutes'));
    await settle(tester);
    await tester.tap(find.text('Axoa'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    await tester.tap(find.text('Récemment consultées'));
    await settle(tester);
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Cake citron'), findsNothing);
  });

  testWidgets('vues : cartes, liste, sans photos', (tester) async {
    await setUpLibrary(tester);

    Future<void> choose(String text) async {
      await tester.tap(find.byTooltip('Affichage'));
      await settle(tester);
      await tester.tap(find.text(text), warnIfMissed: false);
      await settle(tester);
    }

    await choose('Cartes');
    expect(find.text('Axoa'), findsOneWidget);
    expect(find.text('Plats › Viandes'), findsOneWidget);

    await choose('Liste');
    expect(find.byType(ListTile), findsNWidgets(3));

    await choose('Afficher les photos');
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(
      tester.widget<ListTile>(find.byType(ListTile).first).leading,
      isNull,
    );
  });

  orderPageTests();

  testWidgets('ordre d’une collection : la liste suit l’ordre choisi', (
    tester,
  ) async {
    await setUpLibrary(tester, collection: true);

    await openFilters(tester);
    await tapChip(tester, 'Noël');
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
