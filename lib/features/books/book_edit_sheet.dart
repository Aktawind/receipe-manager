import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/logging/error_log.dart';
import '../../data/app_services.dart';
import '../../domain/book.dart';
import '../../domain/isbn.dart';
import '../../l10n/app_localizations.dart';
import 'book_cover.dart';

/// Ce que l'on sait d'un livre avant de l'enregistrer (scan du code-barres).
typedef BookDraft = ({
  String title,
  String authors,
  String publisher,
  int? year,
  String isbn,
  String? cover,
});

/// La fiche d'un livre à remplir : nouveau ([book] `null`, éventuellement
/// pré-rempli par [draft]) ou à modifier. Renvoie le livre enregistré.
Future<Book?> showBookEditSheet(
  BuildContext context, {
  Book? book,
  BookDraft? draft,
}) => showModalBottomSheet<Book>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => _BookEditSheet(book: book, draft: draft),
);

class _BookEditSheet extends ConsumerStatefulWidget {
  const _BookEditSheet({required this.book, required this.draft});

  final Book? book;
  final BookDraft? draft;

  @override
  ConsumerState<_BookEditSheet> createState() => _BookEditSheetState();
}

class _BookEditSheetState extends ConsumerState<_BookEditSheet> {
  late final _title = TextEditingController(
    text: widget.book?.title ?? widget.draft?.title ?? '',
  );
  late final _authors = TextEditingController(
    text: widget.book?.authors ?? widget.draft?.authors ?? '',
  );
  late final _publisher = TextEditingController(
    text: widget.book?.publisher ?? widget.draft?.publisher ?? '',
  );
  late final _year = TextEditingController(
    text: '${widget.book?.year ?? widget.draft?.year ?? ''}',
  );
  late final _isbn = TextEditingController(
    text: widget.book?.isbn ?? widget.draft?.isbn ?? '',
  );
  late final _notes = TextEditingController(text: widget.book?.notes ?? '');
  late String? _cover = widget.book?.cover ?? widget.draft?.cover;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _authors, _publisher, _year, _isbn, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (picked == null) return;
      final name = await ref.read(photoStoreProvider).add(File(picked.path));
      setState(() => _cover = name);
    } on Object catch (error, stack) {
      ErrorLog.current.add('Couverture du livre', error, stack);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.photoError('$error'))),
      );
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    final repository = ref.read(recipeRepositoryProvider);
    final isbn = Isbn.normalize(_isbn.text) ?? _isbn.text.trim();
    final year = int.tryParse(_year.text.trim());
    final existing = widget.book;
    final Book saved;
    if (existing == null) {
      final created = await repository.createBook(
        title: title,
        authors: _authors.text,
        publisher: _publisher.text,
        year: year,
        isbn: isbn,
        cover: _cover,
      );
      saved = created.copyWith(notes: _notes.text.trim());
      if (saved.notes.isNotEmpty) await repository.saveBook(saved);
    } else {
      saved = existing.copyWith(
        title: title,
        authors: _authors.text.trim(),
        publisher: _publisher.text.trim(),
        year: () => year,
        isbn: isbn,
        cover: () => _cover,
        notes: _notes.text.trim(),
      );
      await repository.saveBook(saved);
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget field(
      String key,
      TextEditingController controller,
      String label, {
      TextInputType? keyboard,
      int maxLines = 1,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey('book-$key'),
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: keyboard == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(labelText: label),
        onChanged: key == 'title' ? (_) => setState(() {}) : null,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.book == null ? l10n.bookAdd : l10n.bookEdit,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(cover: _cover, width: 80),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        key: const ValueKey('book-cover-camera'),
                        onPressed: () => _pickCover(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(l10n.takePhoto),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickCover(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(l10n.chooseFromGallery),
                      ),
                      if (_cover != null)
                        TextButton.icon(
                          onPressed: () => setState(() => _cover = null),
                          icon: const Icon(Icons.hide_image_outlined),
                          label: Text(l10n.bookCoverRemove),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            field('title', _title, l10n.bookTitle),
            field('authors', _authors, l10n.bookAuthors),
            Row(
              children: [
                Expanded(
                  child: field('publisher', _publisher, l10n.bookPublisher),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: field(
                    'year',
                    _year,
                    l10n.bookYear,
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            field('isbn', _isbn, l10n.bookIsbn, keyboard: TextInputType.number),
            field('notes', _notes, l10n.bookNotes, maxLines: 4),
            FilledButton(
              key: const ValueKey('book-save'),
              onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
