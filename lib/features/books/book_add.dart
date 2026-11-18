import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging/error_log.dart';
import '../../core/platform/barcode_scanner.dart';
import '../../data/app_services.dart';
import '../../data/import/book_lookup.dart';
import '../../domain/isbn.dart';
import '../../l10n/app_localizations.dart';
import 'book_edit_sheet.dart';
import 'book_providers.dart';

/// « Ajouter un livre » : scanner le code-barres (la fiche se remplit) ou
/// tout saisir ; le livre enregistré s'ouvre.
Future<void> addBook(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final how = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('book-add-scan'),
            leading: const Icon(Icons.qr_code_scanner),
            title: Text(l10n.bookScan),
            subtitle: Text(l10n.bookScanHint),
            onTap: () => Navigator.pop(context, true),
          ),
          ListTile(
            key: const ValueKey('book-add-manual'),
            leading: const Icon(Icons.edit_outlined),
            title: Text(l10n.bookManual),
            onTap: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
  if (how == null || !context.mounted) return;
  final draft = how ? await _scan(context, ref) : _emptyDraft;
  if (draft == null || !context.mounted) return;
  final book = await showBookEditSheet(context, draft: draft);
  if (book != null && context.mounted) {
    await context.push('/livres/${book.id}');
  }
}

const BookDraft _emptyDraft = (
  title: '',
  authors: '',
  publisher: '',
  year: null,
  isbn: '',
  cover: null,
);

/// Lit le code-barres et cherche le livre ; `null` si on annule ou si le
/// livre est déjà là (il est alors ouvert).
Future<BookDraft?> _scan(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final String? code;
  try {
    code = await ref.read(barcodeScannerProvider).scan();
  } on Object catch (error, stack) {
    ErrorLog.current.add('Code-barres', error, stack);
    say(l10n.bookScanFailed);
    return null;
  }
  if (code == null) return null;
  final isbn = Isbn.normalize(code);
  if (isbn == null) {
    say(l10n.bookScanNotIsbn);
    return null;
  }
  final books = ref.read(booksProvider).value ?? const [];
  final known = books.where((b) => b.isbn == isbn).firstOrNull;
  if (known != null) {
    say(l10n.bookAlreadyThere(known.title));
    if (context.mounted) await context.push('/livres/${known.id}');
    return null;
  }

  if (!context.mounted) return null;
  // Pendant la recherche : une fenêtre d'attente.
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(l10n.bookSearching)),
        ],
      ),
    ),
  ).ignore();
  BookDraft draft = (
    title: '',
    authors: '',
    publisher: '',
    year: null,
    isbn: isbn,
    cover: null,
  );
  try {
    final lookup = ref.read(bookLookupProvider);
    final info = await lookup.find(isbn);
    if (info == null) {
      say(l10n.bookNotFound);
    } else {
      String? cover;
      final url = info.coverUrl;
      if (url != null) {
        try {
          final bytes = await lookup.download(url);
          if (bytes != null) {
            cover = '${const Uuid().v4()}.jpg';
            await ref.read(photoStoreProvider).write(cover, bytes);
          }
        } on Object catch (error, stack) {
          ErrorLog.current.add('Couverture du livre', error, stack);
        }
      }
      draft = (
        title: info.title,
        authors: info.authors,
        publisher: info.publisher,
        year: info.year,
        isbn: isbn,
        cover: cover,
      );
    }
  } on Object catch (error, stack) {
    ErrorLog.current.add('Recherche du livre', error, stack);
    say(l10n.bookLookupFailed);
  } finally {
    navigator.pop();
  }
  return draft;
}
