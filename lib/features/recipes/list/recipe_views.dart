/// Les trois présentations de la liste des recettes (grille, liste, cartes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/durations.dart';
import '../../../domain/label.dart';
import '../../../domain/recipe.dart';
import '../../../l10n/app_localizations.dart';
import '../../classification/labels_providers.dart';
import '../recipe_photo.dart';
import '../recipe_providers.dart';

void openRecipe(BuildContext context, Recipe recipe) =>
    context.push('/recettes/${recipe.id}');

String recipeTitle(AppLocalizations l10n, Recipe recipe) =>
    recipe.title.trim().isEmpty ? l10n.untitledRecipe : recipe.title;

String? recipeSummary(AppLocalizations l10n, Recipe recipe) {
  final parts = [
    if (recipe.totalMinutes case final total?) formatMinutes(l10n, total),
    if (recipe.servings case final servings?)
      recipe.servingsUnit.isEmpty
          ? l10n.servingsCount(servings)
          : '$servings ${recipe.servingsUnit}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class RecipeGrid extends ConsumerWidget {
  const RecipeGrid({super.key, required this.recipes});

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
            final summary = recipeSummary(l10n, recipe);
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => openRecipe(context, recipe),
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
                            recipeTitle(l10n, recipe),
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

class RecipeList extends ConsumerWidget {
  const RecipeList({super.key, required this.recipes});

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
        final summary = recipeSummary(l10n, recipe);
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
          title: Text(recipeTitle(l10n, recipe)),
          subtitle: summary == null ? null : Text(summary),
          trailing: recipe.isFavorite
              ? Icon(
                  Icons.favorite,
                  size: 18,
                  color: Theme.of(context).colorScheme.tertiary,
                )
              : null,
          onTap: () => openRecipe(context, recipe),
        );
      },
    );
  }
}

/// Une carte par recette : photo carrée, titre, durée et portions, note,
/// statut et classement.
class RecipeCards extends ConsumerWidget {
  const RecipeCards({super.key, required this.recipes});

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
            final summary = recipeSummary(l10n, recipe);
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
                onTap: () => openRecipe(context, recipe),
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
                                    recipeTitle(l10n, recipe),
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

class RecipesEmptyState extends StatelessWidget {
  const RecipesEmptyState({super.key, this.message});

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
