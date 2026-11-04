import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../domain/label.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../classification/label_picker.dart';
import '../classification/labels_providers.dart';
import 'filter_dialogs.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';
import 'saved_searches.dart';

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
            onPressed: () => _showFilterSheet(context),
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
          return _EmptyState(
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
                RecipesView.grid => _RecipeGrid(recipes: recipes),
                RecipesView.list => _RecipeList(recipes: recipes),
                RecipesView.cards => _RecipeCards(recipes: recipes),
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

/// Le filtre : « Favoris », « Statut », puis une ligne par
/// famille de classement, qui ouvre une liste à cocher. Statuts, catégories
/// (principales seulement), saisons et origines : l'un ou l'autre ; collections :
/// toutes celles qui sont cochées ; critères différents : tous ensemble.
Future<void> _showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  Future<void> _chooseStatuses(BuildContext context, WidgetRef ref) async {
    final chosen = await showDialog<Set<RecipeStatus>>(
      context: context,
      builder: (context) =>
          _StatusDialog(initial: ref.read(recipeFilterProvider).statuses),
    );
    if (chosen != null) {
      ref.read(recipeFilterProvider.notifier).setStatuses(chosen);
    }
  }

  Future<void> _chooseTimes(BuildContext context, WidgetRef ref) async {
    final chosen = await showTimeLimitsDialog(
      context,
      ref.read(recipeFilterProvider).times,
    );
    if (chosen != null) {
      ref.read(recipeFilterProvider.notifier).setTimes(chosen);
    }
  }

  Future<void> _chooseEquipment(BuildContext context, WidgetRef ref) async {
    final chosen = await showEquipmentFilterDialog(
      context,
      ref.read(recipeFilterProvider).equipmentIds,
    );
    if (chosen != null) {
      ref.read(recipeFilterProvider.notifier).setEquipment(chosen);
    }
  }

  Future<void> _chooseIngredients(BuildContext context, WidgetRef ref) async {
    final chosen = await showIngredientFilterPage(
      context,
      ref.read(recipeFilterProvider).ingredients,
    );
    if (chosen != null) {
      ref.read(recipeFilterProvider.notifier).setIngredients(chosen);
    }
  }

  Future<void> _chooseLabels(
    BuildContext context,
    WidgetRef ref,
    LabelKind kind,
    List<Label> all,
    Set<String> relevant,
  ) async {
    final filter = ref.read(recipeFilterProvider);
    final ofKind = {
      for (final l in all)
        if (l.kind == kind) l.id,
    };
    // Les catégories se filtrent par les principales : choisir « Plats »
    // retient aussi ses sous-catégories.
    final byId = {for (final l in all) l.id: l};
    final visible = kind == LabelKind.category
        ? {
            for (final id in relevant)
              if (byId[id]?.parentId == null) id,
          }
        : relevant;
    final chosen = await pickLabels(
      context,
      kind: kind,
      selected: [
        for (final id in filter.labelIds)
          if (ofKind.contains(id)) id,
      ],
      allowCreate: false,
      visibleIds: visible,
    );
    if (chosen != null) {
      ref.read(recipeFilterProvider.notifier).replaceLabels(ofKind, chosen);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(recipeFilterProvider);
    final all = ref.watch(labelsProvider).value ?? const <Label>[];
    final usage = ref.watch(labelUsageProvider).value ?? const {};
    final byId = {for (final l in all) l.id: l};

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

    String statusName(RecipeStatus status) => switch (status) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.toRetest => l10n.statusToRetest,
      RecipeStatus.toImprove => l10n.statusToImprove,
      RecipeStatus.validated => l10n.statusValidated,
    };

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(l10n.filterTitle, style: theme.textTheme.titleLarge),
                Wrap(
                  spacing: 8,
                  children: [
                    if (filter.isActive)
                      TextButton(
                        onPressed: ref
                            .read(recipeFilterProvider.notifier)
                            .clear,
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
          ),
          // L'en-tête reste en haut ; seules les lignes défilent.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SavedSearchesSection(),
                  const Divider(height: 1),
                  SwitchListTile(
                    key: const ValueKey('filter-favorites'),
                    secondary: const Icon(Icons.star_outline),
                    title: Text(l10n.quickFavorites),
                    value: filter.quick == QuickFilter.favorites,
                    onChanged: (on) => ref
                        .read(recipeFilterProvider.notifier)
                        .setQuick(on ? QuickFilter.favorites : QuickFilter.all),
                  ),
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l10n.statusLabel),
                    subtitle: Text(
                      filter.statuses.isEmpty
                          ? l10n.filterNone
                          : [
                              for (final status in RecipeStatus.values)
                                if (filter.statuses.contains(status))
                                  statusName(status),
                            ].join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseStatuses(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text(l10n.filterDuration),
                    subtitle: Text(
                      filter.times.isActive
                          ? [
                              if (filter.times.total case final m?)
                                '${l10n.filterDurationTotal} ${formatMinutes(l10n, m)}',
                              if (filter.times.prep case final m?)
                                '${l10n.filterDurationPrep} ${formatMinutes(l10n, m)}',
                              if (filter.times.cook case final m?)
                                '${l10n.filterDurationCook} ${formatMinutes(l10n, m)}',
                            ].join(' · ')
                          : l10n.filterNone,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseTimes(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restaurant_menu),
                    title: Text(l10n.filterIngredients),
                    subtitle: Text(
                      filter.ingredients.isActive
                          ? [
                              if (filter.ingredients.all.isNotEmpty)
                                l10n.ingredientsSumAll(
                                  filter.ingredients.all.join(', '),
                                ),
                              if (filter.ingredients.any.isNotEmpty)
                                l10n.ingredientsSumAny(
                                  filter.ingredients.any.join(', '),
                                ),
                              if (filter.ingredients.none.isNotEmpty)
                                l10n.ingredientsSumNone(
                                  filter.ingredients.none.join(', '),
                                ),
                            ].join(' · ')
                          : l10n.filterNone,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseIngredients(context, ref),
                  ),
                  ListTile(
                    leading: const Icon(Icons.kitchen_outlined),
                    title: Text(l10n.filterEquipment),
                    subtitle: Text(
                      filter.equipmentIds.isEmpty
                          ? l10n.filterNone
                          : l10n.filterEquipmentSelected(
                              filter.equipmentIds.length,
                            ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _chooseEquipment(context, ref),
                  ),
                  for (final kind in LabelKind.values)
                    () {
                      final selected = [
                        for (final l in all)
                          if (l.kind == kind && filter.labelIds.contains(l.id))
                            l,
                      ];
                      return ListTile(
                        leading: Icon(kind.icon),
                        title: Text(kind.title(l10n)),
                        subtitle: Text(
                          selected.isEmpty
                              ? l10n.filterNone
                              : selected
                                    .map((l) => labelPath(l, byId))
                                    .join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _chooseLabels(context, ref, kind, all, relevant),
                      );
                    }(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liste à cocher des statuts (l'un ou l'autre).
class _StatusDialog extends StatefulWidget {
  const _StatusDialog({required this.initial});

  final Set<RecipeStatus> initial;

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  late final Set<RecipeStatus> _chosen = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String name(RecipeStatus status) => switch (status) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.toRetest => l10n.statusToRetest,
      RecipeStatus.toImprove => l10n.statusToImprove,
      RecipeStatus.validated => l10n.statusValidated,
    };
    return AlertDialog(
      title: Text(l10n.statusLabel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in RecipeStatus.values)
              CheckboxListTile(
                value: _chosen.contains(status),
                title: Text(name(status)),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _chosen.add(status);
                  } else {
                    _chosen.remove(status);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _chosen),
          child: Text(l10n.validate),
        ),
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

class _RecipeGrid extends ConsumerWidget {
  const _RecipeGrid({required this.recipes});

  final List<Recipe> recipes;

  /// Hauteur du bloc texte sous la photo carrée.
  static const _textHeight = 76.0;
  static const _spacing = 12.0;
  static const _padding = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            mainAxisExtent: cellWidth + _textHeight,
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

class _RecipeList extends ConsumerWidget {
  const _RecipeList({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 56,
              child: RecipePhoto(
                photo: recipe.mainPhoto,
                decodeWidth: 168,
                iconSize: 24,
              ),
            ),
          ),
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
  const _RecipeCards({required this.recipes});

  final List<Recipe> recipes;

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
      RecipeStatus.toRetest => l10n.statusToRetest,
      RecipeStatus.toImprove => l10n.statusToImprove,
      RecipeStatus.validated => l10n.statusValidated,
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
            mainAxisExtent: 132,
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
