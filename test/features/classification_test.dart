import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/label.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('Réglages → Classement : sous-catégorie, renommer, supprimer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.text('Classement'));
    await tester.tap(find.text('Classement'));
    await settle(tester);
    expect(find.text('Origine culinaire'), findsOneWidget);
    expect(find.text('Saison'), findsOneWidget);

    await tester.tap(find.text('Catégories'));
    await settle(tester);
    expect(find.text('Plats'), findsOneWidget);
    expect(find.text('Desserts'), findsOneWidget);

    // Sous-catégorie : menu de la ligne « Plats ».
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Plats'),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Ajouter une sous-catégorie'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'viandes');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.text('Viandes'), findsOneWidget);

    // Un nom déjà pris est refusé au renommage.
    await tester.tap(find.text('Desserts'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'plats');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.text('Ce nom existe déjà ici'), findsOneWidget);
    expect(find.text('Desserts'), findsOneWidget);

    // Supprimer « Plats » emporte sa sous-catégorie.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Plats'),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect(find.textContaining('et ses sous-catégories'), findsOneWidget);
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect(find.text('Plats'), findsNothing);
    expect(find.text('Viandes'), findsNothing);
    expect(find.text('Desserts'), findsOneWidget);
  });

  testWidgets('formulaire : choisir ses catégories et créer une étiquette', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final repo = app.services.recipes;
    final id = (await tester.runAsync(() async {
      final created = await repo.create();
      return (await repo.save(created.copyWith(title: 'Quiche'))).id;
    }))!;
    await app.pump(tester);

    await tester.tap(find.text('Quiche'));
    await settle(tester);
    await tester.tap(find.byTooltip('Modifier'));
    await settle(tester);

    // Catégorie : on coche « Plats ».
    final categories = find.byKey(const ValueKey('classification-category'));
    await scrollTo(tester, categories);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pump();
    await tester.tap(categories);
    await settle(tester);
    await tester.tap(find.text('Plats'));
    await tester.tap(find.text('Valider'));
    await settle(tester);

    // Étiquette : « Rapide » existe, « Sans gluten » est créée au passage.
    final tags = find.byKey(const ValueKey('classification-tag'));
    await scrollTo(tester, tags);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 200));
    await tester.pump();
    await tester.tap(tags);
    await settle(tester);
    await tester.tap(find.text('Rapide'));
    await tester.enterText(
      find.byKey(const ValueKey('label-search')),
      'sans gluten',
    );
    await tester.pump();
    await tester.tap(find.text('Ajouter « sans gluten »'));
    await settle(tester);
    await tester.tap(find.text('Valider'));
    await settle(tester);

    await goBack(tester);
    final saved = (await tester.runAsync(() async {
      final recipe = (await repo.getRecipe(id))!;
      final all = {for (final l in await app.services.labels.getAll()) l.id: l};
      return [for (final labelId in recipe.labelIds) all[labelId]!];
    }))!;
    expect(saved.map((l) => l.name).toSet(), {
      'Plats',
      'Rapide',
      'Sans gluten',
    });
    expect(
      saved.firstWhere((l) => l.name == 'Sans gluten').kind,
      LabelKind.tag,
    );
  });
}
