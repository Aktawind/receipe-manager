import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_filter.dart';
import '../../l10n/app_localizations.dart';
import 'list/filter_sheet.dart';
import 'list/recipe_views.dart';
import 'recipe_providers.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  final _searchController = TextEditingController();
  bool _searching = false;
  Timer? _remember;

  @override
  void dispose() {
    _remember?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _remember?.cancel();
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(recipeSearchProvider.notifier).set('');
  }

  void _onQueryChanged(String query) {
    ref.read(recipeSearchProvider.notifier).set(query);
    // Une recherche qu'on laisse affichée un instant est gardée dans
    // l'historique ; ce qu'on tape lettre à lettre ne l'est pas.
    _remember?.cancel();
    _remember = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) ref.read(searchHistoryProvider.notifier).add(query);
    });
  }

  void _useSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    ref.read(recipeSearchProvider.notifier).set(query);
  }

  Future<void> _createRecipe() async {
    final recipe = await ref.read(recipeRepositoryProvider).create();
    if (!mounted) return;
    context.push('/recettes/${recipe.id}/modifier?nouvelle=1');
  }

  @override
  Widget build(BuildContext context) {
    // Une recherche enregistrée peut remplir le texte cherché : le champ suit.
    ref.listen(recipeSearchProvider, (previous, next) {
      if (_searchController.text == next) return;
      _searchController.text = next;
      if (next.isNotEmpty && !_searching) setState(() => _searching = true);
    });
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(recipesViewProvider);
    final filter = ref.watch(recipeFilterProvider);
    final recipes = ref.watch(visibleRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchAnything,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                onSubmitted: (query) =>
                    ref.read(searchHistoryProvider.notifier).add(query),
              )
            : Text(l10n.navRecipes),
        actions: [
          if (_searching)
            IconButton(
              tooltip: l10n.closeSearch,
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else
            IconButton(
              tooltip: l10n.search,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          IconButton(
            tooltip: l10n.filterTitle,
            icon: Badge(
              isLabelVisible: filter.activeCount > 0,
              label: Text('${filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showRecipeFilterSheet(context),
          ),
          IconButton(
            key: const ValueKey('web-import-open'),
            tooltip: l10n.webImportMenu,
            icon: const Icon(Icons.add_link),
            onPressed: () => context.push('/recettes/importer'),
          ),
          const _DisplayMenu(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecipe,
        icon: const Icon(Icons.add),
        label: Text(l10n.newRecipe),
      ),
      body: _searching && ref.watch(recipeSearchProvider).trim().isEmpty
          ? _SearchHistoryList(
              onPick: _useSearch,
              fallback: _list(l10n, view, filter, recipes),
            )
          : _list(l10n, view, filter, recipes),
    );
  }

  Widget _list(
    AppLocalizations l10n,
    RecipesView view,
    RecipeFilter filter,
    AsyncValue<List<Recipe>> recipes,
  ) {
    return recipes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (recipes) {
        if (recipes.isEmpty) {
          final query = ref.watch(recipeSearchProvider).trim();
          return RecipesEmptyState(
            message: query.isNotEmpty
                ? l10n.noSearchResults(query)
                : filter.isActive
                ? l10n.filterNoRecipes
                : null,
          );
        }
        return Column(
          children: [
            _CountLine(shown: recipes.length),
            Expanded(
              child: switch (view) {
                RecipesView.grid => RecipeGrid(recipes: recipes),
                RecipesView.list => RecipeList(recipes: recipes),
                RecipesView.cards => RecipeCards(recipes: recipes),
              },
            ),
          ],
        );
      },
    );
  }
}

/// L'historique des recherches, affiché quand on ouvre la recherche sans rien
/// avoir tapé. Sans historique, c'est la liste des recettes.
class _SearchHistoryList extends ConsumerWidget {
  const _SearchHistoryList({required this.onPick, required this.fallback});

  final ValueChanged<String> onPick;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    if (history.isEmpty) return fallback;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(searchHistoryProvider.notifier);
    return ListView(
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.searchHistory,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: notifier.clear,
                child: Text(l10n.searchHistoryClear),
              ),
            ],
          ),
        ),
        for (final query in history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(query),
            trailing: IconButton(
              tooltip: l10n.searchHistoryRemove,
              icon: const Icon(Icons.close),
              onPressed: () => notifier.remove(query),
            ),
            onTap: () => onPick(query),
          ),
      ],
    );
  }
}

/// « 327 recettes », ou « 12 sur 327 recettes » quand la liste est filtrée.
class _CountLine extends ConsumerWidget {
  const _CountLine({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final total = ref.watch(recipesProvider).value?.length ?? shown;
    final filter = ref.watch(recipeFilterProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              shown == total
                  ? l10n.recipeCount(total)
                  : l10n.recipeCountOf(shown, total),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Un geste pour tout effacer, sans rouvrir le filtre.
          if (filter.isActive)
            TextButton.icon(
              key: const ValueKey('filters-clear'),
              onPressed: ref.read(recipeFilterProvider.notifier).clear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(l10n.filtersClearAll),
            ),
        ],
      ),
    );
  }
}

enum _DisplayChoice {
  list,
  grid,
  cards,
  sortTitle,
  sortAdded,
  sortViewed,
  sortDuration,
  sortRating,
  sortStatus,
  sortManual,
}

/// Vue (liste, grille, cartes), photos et tri.
class _DisplayMenu extends ConsumerWidget {
  const _DisplayMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(recipesViewProvider);
    final filter = ref.watch(recipeFilterProvider);
    final collection = ref.watch(singleCollectionFilterProvider);

    PopupMenuEntry<_DisplayChoice> header(String text) => PopupMenuItem(
      enabled: false,
      height: 32,
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );

    PopupMenuEntry<_DisplayChoice> choice(
      _DisplayChoice value,
      String text,
      bool checked,
    ) =>
        CheckedPopupMenuItem(value: value, checked: checked, child: Text(text));

    return PopupMenuButton<_DisplayChoice>(
      tooltip: l10n.displayOptions,
      icon: const Icon(Icons.tune),
      onSelected: (selected) {
        final views = ref.read(recipesViewProvider.notifier);
        final sort = ref.read(recipeFilterProvider.notifier);
        switch (selected) {
          case _DisplayChoice.list:
            views.set(RecipesView.list);
          case _DisplayChoice.grid:
            views.set(RecipesView.grid);
          case _DisplayChoice.cards:
            views.set(RecipesView.cards);
          case _DisplayChoice.sortTitle:
            sort.setSort(RecipeSort.title);
          case _DisplayChoice.sortAdded:
            sort.setSort(RecipeSort.added);
          case _DisplayChoice.sortViewed:
            sort.setSort(RecipeSort.viewed);
          case _DisplayChoice.sortDuration:
            sort.setSort(RecipeSort.duration);
          case _DisplayChoice.sortRating:
            sort.setSort(RecipeSort.rating);
          case _DisplayChoice.sortStatus:
            sort.setSort(RecipeSort.status);
          case _DisplayChoice.sortManual:
            sort.setSort(RecipeSort.manual);
        }
      },
      itemBuilder: (context) => [
        header(l10n.viewMode),
        choice(_DisplayChoice.list, l10n.viewList, view == RecipesView.list),
        choice(_DisplayChoice.grid, l10n.viewGrid, view == RecipesView.grid),
        choice(_DisplayChoice.cards, l10n.viewCards, view == RecipesView.cards),
        const PopupMenuDivider(),
        header(l10n.sortBy),
        choice(
          _DisplayChoice.sortTitle,
          l10n.sortTitle,
          filter.sort == RecipeSort.title,
        ),
        choice(
          _DisplayChoice.sortAdded,
          l10n.sortAdded,
          filter.sort == RecipeSort.added,
        ),
        choice(
          _DisplayChoice.sortViewed,
          l10n.sortViewed,
          filter.sort == RecipeSort.viewed,
        ),
        choice(
          _DisplayChoice.sortDuration,
          l10n.sortDuration,
          filter.sort == RecipeSort.duration,
        ),
        choice(
          _DisplayChoice.sortRating,
          l10n.sortRating,
          filter.sort == RecipeSort.rating,
        ),
        choice(
          _DisplayChoice.sortStatus,
          l10n.sortStatus,
          filter.sort == RecipeSort.status,
        ),
        if (collection != null)
          choice(
            _DisplayChoice.sortManual,
            l10n.sortManual,
            filter.sort == RecipeSort.manual,
          ),
      ],
    );
  }
}
