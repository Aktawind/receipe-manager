import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/platform/export_actions.dart';
import 'package:recettes/core/platform/speech_input.dart';
import 'package:recettes/domain/shopping.dart';

import '../helpers/test_app.dart';

/// Un micro qui « entend » les phrases données, une par une, puis attend
/// qu'on l'arrête.
class _FakeSpeech implements SpeechInput {
  _FakeSpeech(this.phrases);

  final List<String> phrases;
  void Function(SpeechStop)? _onStop;
  var stopped = false;

  @override
  Future<void> start({
    required void Function(String text) onResult,
    void Function(String text)? onPartial,
    void Function()? onListening,
    required void Function(SpeechStop reason) onStop,
  }) async {
    _onStop = onStop;
    onListening?.call();
    for (final phrase in phrases) {
      onPartial?.call(phrase);
      onResult(phrase);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  Future<void> stop() async {
    stopped = true;
    _onStop?.call(SpeechStop.user);
  }
}

class _FakeExport implements ExportActions {
  String? text;
  String? subject;
  Uint8List? pdf;
  String? pdfName;

  @override
  Future<void> shareText(String text, {String subject = ''}) async {
    this.text = text;
    this.subject = subject;
  }

  @override
  Future<void> printPdf(Uint8List pdf, {required String name}) async {
    this.pdf = pdf;
    pdfName = name;
  }
}

Future<void> _openNewList(WidgetTester tester, String name) async {
  await tester.tap(find.text('Courses').last);
  await settle(tester);
  await tester.tap(find.byKey(const ValueKey('shopping-new-list')));
  await settle(tester);
  await tester.enterText(find.byType(TextField).last, name);
  await tester.tap(find.text('Valider'));
  await settle(tester);
}

Future<void> _type(WidgetTester tester, String line) async {
  await tester.enterText(
    find.byKey(const ValueKey('shopping-add-field')),
    line,
  );
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
}

Future<ShoppingList> _onlyList(TestApp app, WidgetTester tester) async =>
    (await tester.runAsync(() => app.services.shopping.getAllLists()))!.single;

void main() {
  testWidgets('une liste : ajouter, fusionner, cocher, retirer les cochés', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    expect(find.text('Courses'), findsWidgets);

    await _openNewList(tester, 'Semaine');
    expect(find.text('Semaine'), findsOneWidget);
    expect(find.text('La liste est vide'), findsOneWidget);

    await _type(tester, '2 kg de pommes de terre');
    await _type(tester, '200 g de beurre');
    await _type(tester, 'Beurre 50 g');
    await _type(tester, 'jambons');
    await _type(tester, '4 Jambon');
    var list = await _onlyList(app, tester);
    expect(
      [for (final i in list.items) '${i.amount} ${i.name}'.trim()],
      ['2 kg Pommes de terre', '250 g Beurre', '4 Jambons'],
    );

    // Cocher : le produit passe dans le panier.
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('shopping-item-${list.items[1].id}')),
        matching: find.byType(Checkbox),
      ),
    );
    await settle(tester);
    expect(find.text('Dans le panier (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('shopping-remove-checked')));
    await settle(tester);
    list = await _onlyList(app, tester);
    expect(list.items, hasLength(2));
    expect(find.text('1 produit retiré'), findsOneWidget);

    // Annuler remet le beurre, toujours dans le panier.
    await tester.tap(find.text('Annuler'));
    await settle(tester);
    list = await _onlyList(app, tester);
    expect(list.items, hasLength(3));
    expect(list.inCart.single.name, 'Beurre');
  });

  testWidgets('dictée continue : une phrase, un produit, jusqu’à l’arrêt', (
    tester,
  ) async {
    usePhoneSize(tester);
    final speech = _FakeSpeech([
      '5 jambons',
      'du beurre',
      'deux kilos de pommes de terre',
    ]);
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [speechInputProvider.overrideWithValue(speech)],
      ),
    ))!;
    await app.pump(tester);
    await _openNewList(tester, 'Semaine');
    await tester.tap(find.byKey(const ValueKey('shopping-dictate')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle(tester);
    // Le micro reste ouvert.
    expect(find.byKey(const ValueKey('shopping-listening')), findsOneWidget);
    expect(find.text('Ajouté : deux kilos de pommes de terre'), findsOneWidget);
    final list = await _onlyList(app, tester);
    expect(
      [for (final i in list.items) '${i.amount} ${i.name}'.trim()],
      ['5 Jambons', 'Beurre', '2 kg Pommes de terre'],
    );

    await tester.tap(find.byKey(const ValueKey('shopping-dictation-stop')));
    await settle(tester);
    expect(speech.stopped, isTrue);
    expect(find.byKey(const ValueKey('shopping-listening')), findsNothing);
  });

  testWidgets(
    'modifier un produit : quantité, rayon sous la quantité, commentaire',
    (tester) async {
      usePhoneSize(tester);
      final app = (await tester.runAsync(TestApp.create))!;
      await app.pump(tester);
      await _openNewList(tester, 'Semaine');
      await _type(tester, '250 g de beurre');

      // Toucher la ligne coche le produit ; ✎ ouvre sa fiche.
      await tester.tap(find.textContaining('Beurre', findRichText: true));
      await settle(tester);
      expect((await _onlyList(app, tester)).items.single.checked, isTrue);
      await tester.tap(find.textContaining('Beurre', findRichText: true));
      await settle(tester);
      expect((await _onlyList(app, tester)).items.single.checked, isFalse);
      final id = (await _onlyList(app, tester)).items.single.id;
      await tester.tap(find.byKey(ValueKey('shopping-item-edit-$id')));
      await settle(tester);
      // Plus de « Ce que j'achète » ni de « Format » ; le rayon suit la quantité.
      expect(find.byKey(const ValueKey('shopping-item-to-buy')), findsNothing);
      expect(find.byKey(const ValueKey('shopping-item-format')), findsNothing);
      final amountY = tester
          .getTopLeft(find.byKey(const ValueKey('shopping-item-amount')))
          .dy;
      final aisleY = tester
          .getTopLeft(find.byKey(const ValueKey('shopping-item-aisle')))
          .dy;
      final noteY = tester
          .getTopLeft(find.byKey(const ValueKey('shopping-item-note')))
          .dy;
      expect(amountY < aisleY && aisleY < noteY, isTrue);

      await tester.enterText(
        find.byKey(const ValueKey('shopping-item-amount')),
        '300 g',
      );
      await tester.enterText(
        find.byKey(const ValueKey('shopping-item-note')),
        'doux',
      );
      await tester.tap(find.byKey(const ValueKey('shopping-item-save')));
      await settle(tester);

      final item = (await _onlyList(app, tester)).items.single;
      expect((item.amount, item.note), ('300 g', 'doux'));
      expect(find.text('doux'), findsOneWidget);
    },
  );

  testWidgets('les recettes d’origine apparaissent sous le produit', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    final shopping = app.services.shopping;
    await tester.runAsync(() async {
      final list = await shopping.createList('Semaine');
      await shopping.save(
        list.copyWith(
          items: const [
            ShoppingItem(
              id: 'b',
              name: 'Beurre',
              quantity: 250,
              unit: 'g',
              sources: [
                ShoppingSource(
                  recipeId: 'q',
                  recipeTitle: 'Quiche',
                  quantity: 100,
                  unit: 'g',
                ),
                ShoppingSource(
                  recipeId: 'c',
                  recipeTitle: 'Crêpes',
                  quantity: 150,
                  unit: 'g',
                ),
              ],
            ),
          ],
        ),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Courses').last);
    await settle(tester);
    expect(find.text('1 produit à acheter'), findsOneWidget);
    await tester.tap(find.text('Semaine'));
    await settle(tester);
    expect(find.text('Quiche, Crêpes'), findsOneWidget);

    // La fiche donne ce que demande chaque recette.
    await tester.tap(find.byKey(const ValueKey('shopping-item-edit-b')));
    await settle(tester);
    expect(find.text('Pour les recettes'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shopping-item-source-0')),
        matching: find.text('100 g'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shopping-item-source-1')),
        matching: find.text('Crêpes'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('réutiliser une liste : mêmes produits, tous à acheter', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await _openNewList(tester, 'Semaine');
    await _type(tester, 'lait');
    final list = await _onlyList(app, tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('shopping-item-${list.items.single.id}')),
        matching: find.byType(Checkbox),
      ),
    );
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('shopping-list-menu')));
    await settle(tester);
    await tester.tap(find.text('Réutiliser la liste'));
    await settle(tester);
    expect(find.text('Semaine (nouvelle)'), findsOneWidget);
    final lists = (await tester.runAsync(app.services.shopping.getAllLists))!;
    final copy = lists.firstWhere((l) => l.name == 'Semaine (nouvelle)');
    expect(copy.items.single.name, 'Lait');
    expect(copy.items.single.checked, isFalse);
  });

  testWidgets(
    'les produits sont rangés par rayon ; un rayon choisi est retenu',
    (tester) async {
      usePhoneSize(tester);
      final app = (await tester.runAsync(TestApp.create))!;
      await app.pump(tester);
      await _openNewList(tester, 'Semaine');
      await _type(tester, 'tomates');
      await _type(tester, 'beurre');
      await _type(tester, 'sauce soja');
      await _type(tester, 'kombucha');
      expect(find.text('Fruits et légumes'), findsOneWidget);
      expect(find.text('Produits frais'), findsOneWidget);
      expect(find.text('Épicerie salée'), findsOneWidget);
      expect(find.text('Autres'), findsOneWidget);
      // Dans l'ordre des rayons.
      final y = {
        for (final name in [
          'Fruits et légumes',
          'Produits frais',
          'Épicerie salée',
          'Autres',
        ])
          name: tester.getTopLeft(find.text(name)).dy,
      };
      expect(y.values.toList(), [...y.values]..sort());

      // Kombucha → Boissons, à la main : retenu pour la prochaine fois.
      await tester.longPress(
        find.textContaining('Kombucha', findRichText: true),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('shopping-item-aisle')));
      await settle(tester);
      await tester.tap(find.text('Boissons').last);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('shopping-item-save')));
      await settle(tester);
      expect(find.text('Boissons'), findsOneWidget);
      expect(find.text('Autres'), findsNothing);
      final memory = (await tester.runAsync(
        app.services.shopping.getAllProductAisles,
      ))!;
      expect(memory.single.key, 'kombucha');

      // Une autre liste : le kombucha retourne dans Boissons.
      await goBack(tester);
      await tester.tap(find.byKey(const ValueKey('shopping-new-list')));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Fête');
      await tester.tap(find.text('Valider'));
      await settle(tester);
      await _type(tester, 'Kombuchas');
      expect(find.text('Boissons'), findsOneWidget);
    },
  );

  testWidgets('partager la liste en texte, l’imprimer en PDF', (tester) async {
    usePhoneSize(tester);
    final export = _FakeExport();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [exportActionsProvider.overrideWithValue(export)],
      ),
    ))!;
    await app.pump(tester);
    await _openNewList(tester, 'Semaine');
    await _type(tester, '2 kg de pommes de terre');
    await _type(tester, 'beurre');

    await tester.tap(find.byKey(const ValueKey('shopping-list-menu')));
    await settle(tester);
    await tester.tap(find.text('Partager la liste'));
    await settle(tester);
    expect(export.subject, 'Semaine');
    expect(
      export.text,
      'Semaine\n\nFRUITS ET LÉGUMES\n- 2 kg Pommes de terre\n\n'
      'PRODUITS FRAIS\n- Beurre',
    );

    await tester.tap(find.byKey(const ValueKey('shopping-list-menu')));
    await settle(tester);
    await tester.tap(find.text('Imprimer ou enregistrer en PDF'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await settle(tester);
    expect(export.pdfName, 'Semaine');
    expect(String.fromCharCodes(export.pdf!.take(4)), '%PDF');
  });
}
