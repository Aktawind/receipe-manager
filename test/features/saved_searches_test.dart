import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('enregistrer une recherche, effacer, la retrouver d’un geste', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      Future<void> add(String title, int prep) async {
        final created = await app.services.recipes.create();
        await app.services.recipes.save(
          created.copyWith(title: title, prepMinutes: () => prep),
        );
      }

      await add('Omelette', 10);
      await add('Pot-au-feu', 180);
    });
    await app.pump(tester);

    Future<void> openFilters() async {
      await tester.tap(find.byTooltip('Filtrer'));
      await settle(tester);
    }

    // Une durée limite, puis on l'enregistre.
    await openFilters();
    await tester.ensureVisible(find.text('Durée'));
    await tester.tap(find.text('Durée'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('limit-total')));
    await settle(tester);
    await tester.tap(find.text('30 min').last);
    await settle(tester);
    await tester.tap(find.text('Valider'));
    await settle(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('saved-search-save')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('saved-search-save')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Express');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.widgetWithText(InputChip, 'Express'), findsOneWidget);
    // Dans la base (synchronisée), plus sur l'appareil.
    final saved = (await tester.runAsync(
      app.services.recipes.getAllSavedSearches,
    ))!;
    expect(saved.single.name, 'Express');
    expect(saved.single.filter.times.total, 30);

    // Tout effacer : les deux recettes reviennent.
    await tester.tap(find.text('Tout effacer'));
    await settle(tester);
    await tester.tap(find.text('Terminé'));
    await settle(tester);
    expect(find.text('Pot-au-feu'), findsOneWidget);

    // Un appui sur « Express » : la recherche revient, le filtre se ferme.
    await openFilters();
    await tester.tap(find.widgetWithText(InputChip, 'Express'));
    await settle(tester);
    expect(find.text('Omelette'), findsOneWidget);
    expect(find.text('Pot-au-feu'), findsNothing);
    expect(find.text('Effacer les filtres'), findsOneWidget);
  });
}
