import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/default_aisles.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('Réglages → Rayons : ajouter, renommer, supprimer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await tester.tap(find.text('Réglages').last);
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('settings-aisles')));
    await tester.tap(find.byKey(const ValueKey('settings-aisles')));
    await settle(tester);
    expect(find.text('Fruits et légumes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('aisle-add')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Bio');
    await tester.tap(find.text('Valider'));
    await settle(tester);

    await tester.tap(find.text('Boulangerie'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Pains');
    await tester.tap(find.text('Valider'));
    await settle(tester);

    final delete = find.byKey(
      ValueKey('aisle-delete-${DefaultAisles.idFor('Hygiène')}'),
    );
    await tester.ensureVisible(delete);
    await settle(tester);
    await tester.tap(delete);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('aisle-delete-confirm')));
    await settle(tester);

    final aisles = (await tester.runAsync(app.services.shopping.getAllAisles))!;
    final active = [
      for (final a in aisles..sort((a, b) => a.position.compareTo(b.position)))
        if (!a.isDeleted) a.name,
    ];
    expect(active, contains('Pains'));
    expect(active, isNot(contains('Boulangerie')));
    expect(active, isNot(contains('Hygiène')));
    expect(active.last, 'Bio');
  });
}
