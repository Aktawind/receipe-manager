import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/text_search.dart';
import '../../domain/book.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';
import 'book_add.dart';
import 'book_cover.dart';
import 'book_providers.dart';

enum _BookSort { title, author, recipes }

/// L'onglet « Livres » : la bibliothèque de livres de cuisine, en couvertures.
class BooksPage extends ConsumerStatefulWidget {
  const BooksPage({super.key});

  @override
  ConsumerState<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends ConsumerState<BooksPage> {
  final _search = TextEditingController();
  var _sort = _BookSort.title;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final books = ref.watch(booksProvider).value;
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final counts = <String, int>{};
    for (final r in recipes) {
      if (r.bookId case final id?) counts[id] = (counts[id] ?? 0) + 1;
    }
    final query = normalizeForSearch(_search.text.trim());
    final shown = [
      for (final b in books ?? const <Book>[])
        if (query.isEmpty ||
            normalizeForSearch('${b.title} ${b.authors}').contains(query))
          b,
    ];
    switch (_sort) {
      case _BookSort.title:
        break;
      case _BookSort.author:
        shown.sort(
          (a, b) => normalizeForSearch(
            a.authors.isEmpty ? '~' : a.authors,
          ).compareTo(normalizeForSearch(b.authors.isEmpty ? '~' : b.authors)),
        );
      case _BookSort.recipes:
        shown.sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navBooks),
        actions: [
          PopupMenuButton<_BookSort>(
            key: const ValueKey('books-sort'),
            tooltip: l10n.booksSort,
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _BookSort.title,
                child: Text(l10n.booksSortTitle),
              ),
              PopupMenuItem(
                value: _BookSort.author,
                child: Text(l10n.booksSortAuthor),
              ),
              PopupMenuItem(
                value: _BookSort.recipes,
                child: Text(l10n.booksSortRecipes),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Pas d'animation partagée : les onglets gardent chacun leur bouton.
        heroTag: null,
        key: const ValueKey('books-add'),
        onPressed: () => addBook(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.bookAdd),
      ),
      body: books == null
          ? const Center(child: CircularProgressIndicator())
          : books.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.booksEmpty,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      key: const ValueKey('books-search'),
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l10n.booksSearch,
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  // Marge du bas : bouton flottant et barre de navigation.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    96 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.48,
                        ),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final book = shown[i];
                      final count = counts[book.id] ?? 0;
                      return InkWell(
                        key: ValueKey('book-${book.id}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/livres/${book.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // La couverture prend la place que laisse le
                            // texte (qui peut être agrandi).
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) => Align(
                                  alignment: Alignment.bottomLeft,
                                  child: BookCover(
                                    cover: book.cover,
                                    width: math.min(
                                      constraints.maxWidth,
                                      constraints.maxHeight / 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              l10n.bookRecipeCount(count),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
