import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/book.dart';
import '../../domain/book_sources.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';
import 'book_providers.dart';

/// « Retrouver mes livres » : ouvre la liste des livres cités dans le champ
/// « Source » des recettes.
Future<void> showBookLinks(BuildContext context) =>
    context.push('/livres/sources');

/// Les livres cités dans « Source », à cocher : chacun devient un livre de la
/// bibliothèque (ou rejoint celui qui porte déjà ce titre), et ses recettes y
/// sont rattachées avec leur page.
class BookLinksPage extends ConsumerStatefulWidget {
  const BookLinksPage({super.key});

  @override
  ConsumerState<BookLinksPage> createState() => _BookLinksPageState();
}

class _BookLinksPageState extends ConsumerState<BookLinksPage> {
  List<SourceBook>? _found;

  /// Les titres décochés (tout est coché au départ).
  final _skipped = <String>{};
  var _saving = false;

  Future<void> _apply() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _saving = true);
    final repository = ref.read(recipeRepositoryProvider);
    var books = 0;
    var recipes = 0;
    for (final s in _found!) {
      if (_skipped.contains(s.title)) continue;
      final Book book =
          s.existing ?? await repository.createBook(title: s.title);
      if (s.existing == null) books++;
      await repository.linkToBook(book.id, s.pages);
      recipes += s.pages.length;
    }
    router.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.bookLinksDone(books, recipes))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Calculé une fois : la liste ne bouge pas pendant qu'on coche.
    final recipes = ref.watch(recipesProvider).value;
    final books = ref.watch(booksProvider).value;
    if (_found == null && recipes != null && books != null) {
      _found = BookSources.find(recipes, books);
    }
    final found = _found;
    final chosen = found == null
        ? 0
        : found.where((s) => !_skipped.contains(s.title)).length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bookLinksTitle)),
      body: found == null
          ? const Center(child: CircularProgressIndicator())
          : found.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.bookLinksNone, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              // Marge du bas : le bouton et la barre de navigation.
              padding: EdgeInsets.only(
                bottom: 96 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.bookLinksHint,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                for (final s in found)
                  CheckboxListTile(
                    key: ValueKey('source-book-${s.title}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: !_skipped.contains(s.title),
                    title: Text(s.title),
                    subtitle: Text(
                      [
                        l10n.bookRecipeCount(s.pages.length),
                        if (s.existing != null) l10n.bookLinksExisting,
                      ].join(' · '),
                    ),
                    onChanged: (on) => setState(
                      () => on == true
                          ? _skipped.remove(s.title)
                          : _skipped.add(s.title),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: found == null || found.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  key: const ValueKey('book-links-apply'),
                  onPressed: _saving || chosen == 0 ? null : _apply,
                  icon: const Icon(Icons.link),
                  label: Text(l10n.bookLinksApply(chosen)),
                ),
              ),
            ),
    );
  }
}
