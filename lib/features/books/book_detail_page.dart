import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/book.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/list/recipe_views.dart';
import '../recipes/recipe_photo.dart';
import '../recipes/recipe_providers.dart';
import '../shopping/recipe_picker.dart';
import 'book_cover.dart';
import 'book_edit_sheet.dart';
import 'book_providers.dart';

/// Le numéro d'une page pour trier (« 42-43 » → 42) ; sans page : à la fin.
int _pageOrder(String page) =>
    int.tryParse(RegExp(r'\d+').firstMatch(page)?.group(0) ?? '') ?? 1 << 30;

/// La fiche d'un livre : sa couverture, ce qu'on en sait, et ses recettes
/// dans l'ordre des pages.
class BookDetailPage extends ConsumerWidget {
  const BookDetailPage({super.key, required this.bookId});

  final String bookId;

  Future<void> _spot(BuildContext context, WidgetRef ref, Book book) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _SpotDialog(),
    );
    if (result == null) return;
    final repository = ref.read(recipeRepositoryProvider);
    final created = await repository.create();
    await repository.save(
      created.copyWith(
        title: result.$1,
        bookId: () => book.id,
        bookPage: result.$2,
        status: () => RecipeStatus.toTest,
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.bookSpotted(result.$1))));
  }

  Future<void> _link(BuildContext context, WidgetRef ref, Book book) async {
    final ids = await pickRecipes(context);
    if (ids == null || ids.isEmpty) return;
    await ref.read(recipeRepositoryProvider).linkToBook(book.id, {
      for (final id in ids) id: '',
    });
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Book book) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(recipeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repository.deleteBook(book);
    if (context.mounted) context.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: false,
          content: Text(l10n.bookDeleted(book.title)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => repository.restoreBook(book),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = ref.watch(bookProvider(bookId));
    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: ref.watch(booksProvider).isLoading
              ? const CircularProgressIndicator()
              : Text(l10n.bookNotFoundHere),
        ),
      );
    }
    final recipes =
        [
          for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[])
            if (r.bookId == book.id) r,
        ]..sort((a, b) {
          final byPage = _pageOrder(a.bookPage)
              .compareTo(_pageOrder(b.bookPage));
          return byPage != 0 ? byPage : a.title.compareTo(b.title);
        });
    final details = [
      if (book.publisher.isNotEmpty) book.publisher,
      if (book.year != null) '${book.year}',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            key: const ValueKey('book-edit'),
            tooltip: l10n.bookEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showBookEditSheet(context, book: book),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('book-menu'),
            onSelected: (action) {
              if (action == 'delete') _delete(context, ref, book);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const ValueKey('book-delete'),
                value: 'delete',
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.bookDelete),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        // Marge du bas : barre de navigation Android.
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCover(cover: book.cover, width: 110, radius: 8),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: theme.textTheme.titleLarge),
                      if (book.authors.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(book.authors, style: theme.textTheme.bodyLarge),
                      ],
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          details,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (book.isbn.isNotEmpty)
                        Text(
                          l10n.bookIsbnShort(book.isbn),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (book.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(book.notes, style: theme.textTheme.bodyMedium),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
            child: Text(
              l10n.bookRecipes(recipes.length),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: const ValueKey('book-spot'),
                  onPressed: () => _spot(context, ref, book),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l10n.bookSpot),
                ),
                TextButton.icon(
                  key: const ValueKey('book-link'),
                  onPressed: () => _link(context, ref, book),
                  icon: const Icon(Icons.link),
                  label: Text(l10n.bookLinkRecipes),
                ),
              ],
            ),
          ),
          if (recipes.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l10n.bookNoRecipes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final r in recipes)
            ListTile(
              key: ValueKey('book-recipe-${r.id}'),
              leading: SizedBox.square(
                dimension: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RecipePhoto(
                    photo: r.mainPhoto,
                    decodeWidth: 144,
                    iconSize: 22,
                  ),
                ),
              ),
              title: Text(recipeTitle(l10n, r)),
              subtitle: Text(
                [
                  if (r.bookPage.isNotEmpty) l10n.bookPageShort(r.bookPage),
                  if (r.status == RecipeStatus.toTest) l10n.statusToTest,
                ].join(' · '),
              ),
              onTap: () => openRecipe(context, r),
            ),
        ],
      ),
    );
  }
}

/// Une recette repérée : son titre et sa page, sans tout recopier.
class _SpotDialog extends StatefulWidget {
  const _SpotDialog();

  @override
  State<_SpotDialog> createState() => _SpotDialogState();
}

class _SpotDialogState extends State<_SpotDialog> {
  final _title = TextEditingController();
  final _page = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bookSpot),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.bookSpotHint),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('spot-title'),
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.fieldTitle),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('spot-page'),
            controller: _page,
            decoration: InputDecoration(labelText: l10n.fieldBookPage),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('spot-ok'),
          onPressed: _title.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                  _title.text.trim(),
                  _page.text.trim(),
                )),
          child: Text(l10n.validate),
        ),
      ],
    );
  }
}
