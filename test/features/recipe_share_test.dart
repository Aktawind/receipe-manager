import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/platform/export_actions.dart';
import 'package:recettes/domain/ingredient_text.dart';
import 'package:recettes/domain/step_text.dart';

import '../helpers/test_app.dart';

class _FakeExport implements ExportActions {
  String? text;
  String? subject;
  Uint8List? shared;
  String? sharedName;
  Uint8List? printed;

  @override
  Future<void> shareText(String text, {String subject = ''}) async {
    this.text = text;
    this.subject = subject;
  }

  @override
  Future<void> sharePdf(Uint8List pdf, {required String name}) async {
    shared = pdf;
    sharedName = name;
  }

  @override
  Future<void> printPdf(Uint8List pdf, {required String name}) async {
    printed = pdf;
  }
}

void main() {
  testWidgets('partager une recette en texte, en PDF, l’imprimer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final export = _FakeExport();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [exportActionsProvider.overrideWithValue(export)],
      ),
    ))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final quiche = await repo.create();
      await repo.save(
        quiche.copyWith(
          title: 'Quiche',
          servings: () => 4,
          ingredients: IngredientText.parseList('200 g de lardons\n3 œufs'),
          steps: StepText.parse('Battre les œufs.\n\nCuire 35 min.'),
        ),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Quiche'));
    await settle(tester);

    // Pour 8 personnes : le partage suit les portions de la fiche.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('servings-more')));
      await settle(tester);
    }

    Future<void> menu(String key) async {
      await tester.tap(find.byKey(const ValueKey('recipe-menu')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await settle(tester);
    }

    await menu('recipe-share-text');
    expect(export.subject, 'Quiche');
    expect(export.text, startsWith('Quiche\n8 pers.'));
    expect(export.text, contains('- 400 g de lardons'));
    expect(export.text, contains('1. Battre les œufs.'));

    await menu('recipe-share-pdf');
    expect(export.sharedName, 'Quiche');
    expect(utf8.decode(export.shared!.sublist(0, 5)), '%PDF-');

    await menu('recipe-print');
    expect(utf8.decode(export.printed!.sublist(0, 5)), '%PDF-');
  });
}
