import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('Réglages → Matériel : ajouter, renommer, supprimer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);

    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.text('Matériel'));
    await tester.tap(find.text('Matériel'));
    await settle(tester);
    expect(find.text('Aucun matériel pour l’instant'), findsOneWidget);

    await tester.tap(find.text('Ajouter un matériel'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Moule à cake');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.text('Moule à cake'), findsOneWidget);
    expect(find.text('Utilisé dans aucune recette'), findsOneWidget);

    // Un doublon n'en crée pas un second.
    await tester.tap(find.text('Ajouter un matériel'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'moule a cake');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.byIcon(Icons.kitchen_outlined), findsOneWidget);

    // Renommer en touchant la ligne.
    await tester.tap(find.text('Moule à cake'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Moule à gâteau');
    await tester.tap(find.text('Valider'));
    await settle(tester);
    expect(find.text('Moule à gâteau'), findsOneWidget);

    await tester.tap(find.byTooltip('Supprimer'));
    await settle(tester);
    await tester.tap(find.text('Supprimer').last);
    await settle(tester);
    expect(find.text('Aucun matériel pour l’instant'), findsOneWidget);
  });
}
