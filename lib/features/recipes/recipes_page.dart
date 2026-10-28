import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
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
            tooltip: view == RecipesView.grid
                ? l10n.viewAsList
                : l10n.viewAsGrid,
            icon: Icon(
              view == RecipesView.grid
                  ? Icons.view_list_outlined
                  : Icons.grid_view_outlined,
            ),
            onPressed: ref.read(recipesViewProvider.notifier).toggle,
          ),
        ],
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
              message: query.isEmpty ? null : l10n.noSearchResults(query),
            );
          }
          return view == RecipesView.grid
              ? _RecipeGrid(recipes: recipes)
              : _RecipeList(recipes: recipes);
        },
      ),
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
  const _RecipeGrid({required this.recipes});

  final List<Recipe> recipes;

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
          padding: const EdgeInsets.fromLTRB(_padding, 4, _padding, 96),
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

class _RecipeList extends StatelessWidget {
  const _RecipeList({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
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
          onTap: () => _openRecipe(context, recipe),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message});

  /// Message de recherche sans résultat ; `null` quand il n'y a aucune recette.
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
