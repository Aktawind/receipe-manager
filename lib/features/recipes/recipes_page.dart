import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../classification/labels_providers.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() {
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(recipeSearchProvider.notifier).set('');
  }

  Future<void> _createRecipe() async {
    final recipe = await ref.read(recipeRepositoryProvider).create();
    if (!mounted) return;
    context.push('/recettes/${recipe.id}/modifier?nouvelle=1');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(recipesViewProvider);
    final showPhotos = ref.watch(showPhotosProvider);
    final filter = ref.watch(recipeFilterProvider);
    final recipes = ref.watch(visibleRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchRecipes,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onChanged: ref.read(recipeSearchProvider.notifier).set,
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
              isLabelVisible: filter.labelIds.isNotEmpty,
              label: Text('${filter.labelIds.length}'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => _showFilterSheet(context),
          ),
          const _DisplayMenu(),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: _QuickFilters(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRecipe,
        icon: const Icon(Icons.add),
        label: Text(l10n.newRecipe),
      ),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (recipes) {
          if (recipes.isEmpty) {
            final query = ref.watch(recipeSearchProvider).trim();
            return _EmptyState(
              message: query.isNotEmpty
                  ? l10n.noSearchResults(query)
                  : filter.isActive
                  ? l10n.filterNoRecipes
                  : null,
            );
          }
          return switch (view) {
            RecipesView.grid => _RecipeGrid(
              recipes: recipes,
              showPhotos: showPhotos,
            ),
            RecipesView.list => _RecipeList(
              recipes: recipes,
              showPhotos: showPhotos,
            ),
            RecipesView.cards => _RecipeCards(
              recipes: recipes,
              showPhotos: showPhotos,
            ),
          };
        },
      ),
    );
  }
}

/// Accès rapides (toutes, favoris, récentes) et filtres de classement actifs.
class _QuickFilters extends ConsumerWidget {
  const _QuickFilters();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(recipeFilterProvider);
    final controller = ref.read(recipeFilterProvider.notifier);
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final byId = {for (final l in all) l.id: l};

    Widget quick(QuickFilter value, String label, [IconData? icon]) =>
        ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 18),
          label: Text(label),
          selected: filter.quick == value,
          onSelected: (_) => controller.setQuick(value),
        );

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          quick(QuickFilter.all, l10n.quickAll),
          const SizedBox(width: 8),
          quick(QuickFilter.favorites, l10n.quickFavorites, Icons.favorite),
          const SizedBox(width: 8),
          quick(QuickFilter.recent, l10n.quickRecent, Icons.history),
          const SizedBox(width: 8),
          quick(QuickFilter.added, l10n.quickAdded, Icons.fiber_new),
          for (final id in filter.labelIds)
            if (byId[id] case final label?) ...[
              const SizedBox(width: 8),
              InputChip(
                label: Text(labelPath(label, byId)),
                onDeleted: () => controller.toggleLabel(id),
              ),
            ],
          if (filter.labelIds.isNotEmpty) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: Text(l10n.filterClear),
              onPressed: controller.clear,
            ),
          ],
        ],
      ),
    );
  }
}

enum _DisplayChoice {
  list,
  grid,
  cards,
  photos,
  sortTitle,
  sortAdded,
  sortViewed,
  sortManual,
}

/// Vue (liste, grille, cartes), photos et tri.
class _DisplayMenu extends ConsumerWidget {
  const _DisplayMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(recipesViewProvider);
    final showPhotos = ref.watch(showPhotosProvider);
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
          case _DisplayChoice.photos:
            ref.read(showPhotosProvider.notifier).set(!showPhotos);
          case _DisplayChoice.sortTitle:
            sort.setSort(RecipeSort.title);
          case _DisplayChoice.sortAdded:
            sort.setSort(RecipeSort.added);
          case _DisplayChoice.sortViewed:
            sort.setSort(RecipeSort.viewed);
          case _DisplayChoice.sortManual:
            sort.setSort(RecipeSort.manual);
        }
      },
      itemBuilder: (context) => [
        header(l10n.viewMode),
        choice(_DisplayChoice.list, l10n.viewList, view == RecipesView.list),
        choice(_DisplayChoice.grid, l10n.viewGrid, view == RecipesView.grid),
        choice(_DisplayChoice.cards, l10n.viewCards, view == RecipesView.cards),
        CheckedPopupMenuItem(
          value: _DisplayChoice.photos,
          checked: showPhotos,
          child: Text(l10n.showPhotos),
        ),
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

/// Le filtre par classement : pour chaque famille, les éléments utilisés. Même
/// famille = l'un ou l'autre ; familles différentes = les deux.
Future<void> _showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => _FilterSheet(controller: scroll),
    ),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(recipeFilterProvider);
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final usage = ref.watch(labelUsageProvider).value ?? const {};
    final byId = {for (final l in all) l.id: l};
    final notifier = ref.read(recipeFilterProvider.notifier);

    // Un élément est proposé s'il sert, s'il est déjà choisi, ou si l'une de
    // ses sous-catégories sert (« Plats » quand seules « Viandes »… servent).
    final relevant = <String>{
      for (final l in all)
        if ((usage[l.id] ?? 0) > 0 || filter.labelIds.contains(l.id)) l.id,
    };
    for (final id in relevant.toList()) {
      var parent = byId[id]?.parentId;
      while (parent != null && relevant.add(parent)) {
        parent = byId[parent]?.parentId;
      }
    }

    return ListView(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(l10n.filterTitle, style: theme.textTheme.titleLarge),
            Wrap(
              spacing: 8,
              children: [
                if (filter.labelIds.isNotEmpty)
                  TextButton(
                    onPressed: notifier.clear,
                    child: Text(l10n.filterClear),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.filterDone),
                ),
              ],
            ),
          ],
        ),
        for (final kind in LabelKind.values) ...[
          () {
            // Seuls les éléments qui servent (ou qui sont déjà choisis).
            final labels = [
              for (final l in all)
                if (l.kind == kind && relevant.contains(l.id)) l,
            ];
            if (labels.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Text(
                    kind.title(l10n),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  // Les zones tactiles des pastilles (48) ne se chevauchent pas.
                  runSpacing: 16,
                  children: [
                    for (final label in labels)
                      FilterChip(
                        label: Text(labelPath(label, byId)),
                        selected: filter.labelIds.contains(label.id),
                        onSelected: (_) => notifier.toggleLabel(label.id),
                      ),
                  ],
                ),
              ],
            );
          }(),
        ],
      ],
    );
  }
}

void _openRecipe(BuildContext context, Recipe recipe) =>
    context.push('/recettes/${recipe.id}');

String _recipeTitle(AppLocalizations l10n, Recipe recipe) =>
    recipe.title.trim().isEmpty ? l10n.untitledRecipe : recipe.title;

String? _recipeSummary(AppLocalizations l10n, Recipe recipe) {
  final parts = [
    if (recipe.totalMinutes case final total?) formatMinutes(l10n, total),
    if (recipe.servings case final servings?)
      recipe.servingsUnit.isEmpty
          ? l10n.servingsCount(servings)
          : '$servings ${recipe.servingsUnit}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _RecipeGrid extends StatelessWidget {
  const _RecipeGrid({required this.recipes, required this.showPhotos});

  final List<Recipe> recipes;
  final bool showPhotos;

  /// Hauteur du bloc texte sous la photo carrée.
  static const _textHeight = 76.0;
  static const _spacing = 12.0;
  static const _padding = 12.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // La photo est un carré : la hauteur d'une carte vient de sa largeur.
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 8);
        final cellWidth =
            (constraints.maxWidth - 2 * _padding - (columns - 1) * _spacing) /
            columns;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            _padding,
            4,
            _padding,
            96 + MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: showPhotos ? cellWidth + _textHeight : _textHeight,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final summary = _recipeSummary(l10n, recipe);
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _openRecipe(context, recipe),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showPhotos)
                      AspectRatio(
                        aspectRatio: 1,
                        child: RecipePhoto(
                          photo: recipe.mainPhoto,
                          decodeWidth: 480,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recipeTitle(l10n, recipe),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (summary != null)
                            Text(
                              summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes, required this.showPhotos});

  final List<Recipe> recipes;
  final bool showPhotos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: 96 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final summary = _recipeSummary(l10n, recipe);
        return ListTile(
          leading: showPhotos
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 56,
                    child: RecipePhoto(
                      photo: recipe.mainPhoto,
                      decodeWidth: 168,
                      iconSize: 24,
                    ),
                  ),
                )
              : null,
          title: Text(_recipeTitle(l10n, recipe)),
          subtitle: summary == null ? null : Text(summary),
          trailing: recipe.isFavorite
              ? Icon(
                  Icons.favorite,
                  size: 18,
                  color: Theme.of(context).colorScheme.tertiary,
                )
              : null,
          onTap: () => _openRecipe(context, recipe),
        );
      },
    );
  }
}

/// Une carte par recette : photo carrée, titre, durée et portions, note,
/// statut et classement.
class _RecipeCards extends ConsumerWidget {
  const _RecipeCards({required this.recipes, required this.showPhotos});

  final List<Recipe> recipes;
  final bool showPhotos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final byId = {for (final l in all) l.id: l};
    final links = ref.watch(recipeLabelLinksProvider).value ?? const {};

    String statusText(RecipeStatus status) => switch (status) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.validated => l10n.statusValidated,
      RecipeStatus.toImprove => l10n.statusToImprove,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 2 : 1;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            12,
            4,
            12,
            96 + MediaQuery.paddingOf(context).bottom,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: showPhotos ? 132 : 104,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final summary = _recipeSummary(l10n, recipe);
            final names = [
              for (final id in links[recipe.id]?.keys ?? const <String>[])
                if (byId[id] case final label?
                    when label.kind == LabelKind.category)
                  labelPath(label, byId),
            ];
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _openRecipe(context, recipe),
                child: Row(
                  children: [
                    if (showPhotos)
                      AspectRatio(
                        aspectRatio: 1,
                        child: RecipePhoto(
                          photo: recipe.mainPhoto,
                          decodeWidth: 400,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _recipeTitle(l10n, recipe),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                if (recipe.isFavorite)
                                  Icon(
                                    Icons.favorite,
                                    size: 18,
                                    color: scheme.tertiary,
                                  ),
                              ],
                            ),
                            if (summary != null)
                              Text(summary, style: theme.textTheme.bodySmall),
                            if (names.isNotEmpty)
                              Text(
                                names.first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.primary,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (recipe.rating case final rating?) ...[
                                  for (var i = 1; i <= 5; i++)
                                    Icon(
                                      i <= rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      size: 16,
                                      color: scheme.tertiary,
                                    ),
                                  const SizedBox(width: 8),
                                ],
                                if (recipe.status case final status?)
                                  Flexible(
                                    child: Text(
                                      statusText(status),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  /// Message de recherche ou de filtre sans résultat ; `null` quand il n'y a
  /// aucune recette.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              message == null ? Icons.menu_book_outlined : Icons.search_off,
              size: 72,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? l10n.recipesEmptyTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.recipesEmptyHint,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
