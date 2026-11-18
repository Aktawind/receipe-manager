import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/platform/barcode_scanner.dart';
import 'package:recettes/data/import/book_lookup.dart';

import '../helpers/test_app.dart';

class _FakeScanner implements BarcodeScanner {
  _FakeScanner(this.code);

  final String? code;

  @override
  Future<String?> scan() async => code;
}

class _FakeLookup extends BookLookup {
  final asked = <String>[];

  @override
  Future<BookInfo?> find(String isbn) async {
    asked.add(isbn);
    return (
      title: 'Le grand livre de la pâtisserie',
      authors: 'Christophe Felder',
      publisher: 'Hachette Pratique',
      year: 2014,
      isbn: isbn,
      coverUrl: null,
    );
  }
}

Future<void> _openBooks(WidgetTester tester) async {
  await tester.tap(find.text('Livres').last);
  await settle(tester);
}

void main() {
  testWidgets('ajouter un livre à la main, y noter une recette repérée', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await app.pump(tester);
    await _openBooks(tester);
    expect(find.byKey(const ValueKey('books-empty-sources')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('books-add')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('book-add-manual')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('book-title')),
      'Simplissime',
    );
    await tester.enterText(
      find.byKey(const ValueKey('book-authors')),
      'Jean-François Mallet',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('book-save')));
    await settle(tester);

    // La fiche du livre s'ouvre.
    expect(find.text('Jean-François Mallet'), findsOneWidget);
    expect(find.text('Aucune recette de ce livre pour l\'instant.'), findsOne);

    await tester.tap(find.byKey(const ValueKey('book-spot')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('spot-title')),
      'Poulet au curry',
    );
    await tester.enterText(find.byKey(const ValueKey('spot-page')), '86');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('spot-ok')));
    await settle(tester);
    expect(find.text('Poulet au curry'), findsOneWidget);
    expect(find.text('p. 86 · À tester'), findsOneWidget);

    final recipes = (await tester.runAsync(
      () => app.services.recipes.watchRecipes().first,
    ))!;
    expect(recipes.single.bookPage, '86');

    await goBack(tester);
    expect(find.text('Simplissime'), findsOneWidget);
    expect(find.text('1 recette'), findsOneWidget);
  });

  testWidgets('scanner le code-barres : la fiche se remplit toute seule', (
    tester,
  ) async {
    usePhoneSize(tester);
    final lookup = _FakeLookup();
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [
          barcodeScannerProvider.overrideWithValue(
            _FakeScanner('978-2-01-238671-6'),
          ),
          bookLookupProvider.overrideWithValue(lookup),
        ],
      ),
    ))!;
    await app.pump(tester);
    await _openBooks(tester);
    await tester.tap(find.byKey(const ValueKey('books-add')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('book-add-scan')));
    await settle(tester);

    expect(lookup.asked, ['9782012386716']);
    expect(find.text('Le grand livre de la pâtisserie'), findsOneWidget);
    expect(find.text('Hachette Pratique'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('book-save')));
    await settle(tester);
    expect(find.text('Christophe Felder'), findsOneWidget);
    expect(find.text('Hachette Pratique · 2014'), findsOneWidget);
    expect(find.text('ISBN 9782012386716'), findsOneWidget);

    // Scanné une seconde fois : le livre déjà là s'ouvre.
    await goBack(tester);
    await tester.tap(find.byKey(const ValueKey('books-add')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('book-add-scan')));
    await settle(tester);
    expect(lookup.asked, hasLength(1));
    expect(find.text('ISBN 9782012386716'), findsOneWidget);
  });

  testWidgets('un code-barres qui n’est pas un livre', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(
      () => TestApp.create(
        overrides: [
          barcodeScannerProvider.overrideWithValue(
            _FakeScanner('3017620422003'),
          ),
        ],
      ),
    ))!;
    await app.pump(tester);
    await _openBooks(tester);
    await tester.tap(find.byKey(const ValueKey('books-add')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('book-add-scan')));
    await settle(tester);
    expect(
      find.text('Ce code-barres n\'est pas celui d\'un livre (ISBN).'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('book-save')), findsNothing);
  });

  testWidgets('retrouver les livres cités dans « Source »', (tester) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      for (final (title, source) in [
        ('Tarte au citron', 'Le grand livre de la pâtisserie p. 42'),
        ('Éclairs', 'Grand livre de la patisserie, page 120'),
        ('Quiche', 'https://www.marmiton.org/quiche'),
        ('Gratin', 'Livre de mamie'),
      ]) {
        final r = await repo.create();
        await repo.save(r.copyWith(title: title, source: source));
      }
    });
    await app.pump(tester);
    await _openBooks(tester);
    await tester.tap(find.byKey(const ValueKey('books-empty-sources')));
    await settle(tester);

    expect(find.text('Le grand livre de la pâtisserie'), findsOneWidget);
    expect(find.text('2 recettes'), findsOneWidget);
    // Pas « Livre de mamie » cette fois-ci.
    await tester.tap(find.byKey(const ValueKey('source-book-Livre de mamie')));
    await tester.pump();
    expect(find.text('Relier 1 livre'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('book-links-apply')));
    await settle(tester);
    expect(find.text('1 livre créé, 2 recettes reliées'), findsOneWidget);
    expect(find.text('2 recettes'), findsOneWidget);

    final recipes = (await tester.runAsync(
      () => app.services.recipes.watchRecipes().first,
    ))!;
    final pages = {for (final r in recipes) r.title: (r.bookId, r.bookPage)};
    expect(pages['Tarte au citron']!.$2, '42');
    expect(pages['Éclairs']!.$2, '120');
    expect(pages['Tarte au citron']!.$1, pages['Éclairs']!.$1);
    expect(pages['Gratin']!.$1, isNull);
    expect(pages['Quiche']!.$1, isNull);
  });

  testWidgets('la recette montre son livre ; l’éditeur le choisit', (
    tester,
  ) async {
    usePhoneSize(tester);
    final app = (await tester.runAsync(TestApp.create))!;
    await tester.runAsync(() async {
      final repo = app.services.recipes;
      final book = await repo.createBook(title: 'Simplissime');
      await repo.createBook(title: 'Plenty');
      final r = await repo.create();
      await repo.save(
        r.copyWith(title: 'Curry', bookId: () => book.id, bookPage: '86'),
      );
    });
    await app.pump(tester);
    await tester.tap(find.text('Curry'));
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('recipe-book')));
    expect(find.text('Simplissime'), findsOneWidget);
    expect(find.text('p. 86'), findsOneWidget);

    // Dans l'éditeur : changer de livre.
    await tester.tap(find.byTooltip('Modifier'));
    await settle(tester);
    await scrollTo(tester, find.byKey(const ValueKey('field-book')));
    await tester.tap(find.byKey(const ValueKey('field-book')));
    await settle(tester);
    await tester.tap(find.text('Plenty').last);
    await settle(tester);
    await goBack(tester);

    final recipe = (await tester.runAsync(
      () => app.services.recipes.watchRecipes().first,
    ))!.single;
    final books = (await tester.runAsync(app.services.recipes.getAllBooks))!;
    expect(books.firstWhere((b) => b.id == recipe.bookId).title, 'Plenty');
    expect(recipe.bookPage, '86');

    // La carte du livre ouvre sa fiche.
    await scrollTo(tester, find.byKey(const ValueKey('recipe-book')));
    await tester.tap(find.byKey(const ValueKey('recipe-book')));
    await settle(tester);
    expect(find.byKey(ValueKey('book-recipe-${recipe.id}')), findsOne);
  });
}
