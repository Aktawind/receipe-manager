import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../data/app_services.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Largeur à partir de laquelle ingrédients et étapes sont côte à côte.
const _twoColumnsBreakpoint = 840.0;

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recipe = ref.watch(recipeProvider(recipeId));
    return recipe.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
      data: (recipe) => recipe == null || recipe.isDeleted
          ? Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(l10n.recipeNotFound)),
            )
          : _RecipeDetail(recipe: recipe),
    );
  }
}

enum _MenuAction { duplicate, delete }

class _RecipeDetail extends ConsumerWidget {
  const _RecipeDetail({required this.recipe});

  final Recipe recipe;

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    _MenuAction action,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(recipeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _MenuAction.duplicate:
        final copy = await repository.duplicate(
          recipe.id,
          titleSuffix: l10n.duplicateSuffix,
        );
        if (copy != null && context.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.recipeDuplicated)),
          );
          context.pushReplacement('/recettes/${copy.id}');
        }
      case _MenuAction.delete:
        await repository.moveToTrash(recipe.id);
        if (!context.mounted) return;
        context.pop();
        messenger.showSnackBar(
          SnackBar(
            persist: false,
            content: Text(l10n.recipeMovedToTrash(_title(l10n))),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => repository.restore(recipe.id),
            ),
          ),
        );
    }
  }

  Future<void> _markCooked(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(recipeRepositoryProvider);
    await repository.incrementTimesCooked(recipe.id, 1);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // With an action, a SnackBar stays until dismissed unless told not to.
        persist: false,
        content: Text(l10n.cookedCountIncremented(recipe.timesCooked + 1)),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () => repository.incrementTimesCooked(recipe.id, -1),
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) =>
      recipe.title.trim().isEmpty ? l10n.untitledRecipe : recipe.title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= _twoColumnsBreakpoint;

    final ingredients = _Section(
      title: l10n.ingredients,
      child: _IngredientList(lines: recipe.ingredients),
    );
    final steps = _Section(
      title: l10n.steps,
      child: _StepList(steps: recipe.steps),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: recipe.mainPhoto == null ? null : 280,
            flexibleSpace: recipe.mainPhoto == null
                ? null
                : FlexibleSpaceBar(
                    background: RecipePhoto(
                      photo: recipe.mainPhoto,
                      decodeWidth: 1440,
                    ),
                  ),
            actions: [
              IconButton(
                tooltip: l10n.edit,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    context.push('/recettes/${recipe.id}/modifier'),
              ),
              PopupMenuButton<_MenuAction>(
                onSelected: (action) => _onMenu(context, ref, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MenuAction.duplicate,
                    child: ListTile(
                      leading: const Icon(Icons.copy_outlined),
                      title: Text(l10n.duplicate),
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.delete,
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.delete),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.list(
              children: [
                Text(_title(l10n), style: theme.textTheme.headlineSmall),
                if (recipe.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(recipe.description, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 16),
                _Facts(recipe: recipe),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      l10n.timesCooked(recipe.timesCooked),
                      style: theme.textTheme.bodyMedium,
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _markCooked(context, ref),
                      icon: const Icon(Icons.check),
                      label: Text(l10n.iCookedThis),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: ingredients),
                      const SizedBox(width: 32),
                      Expanded(flex: 3, child: steps),
                    ],
                  )
                else ...[
                  ingredients,
                  steps,
                ],
                if (recipe.tips.trim().isNotEmpty)
                  _Section(
                    title: l10n.tips,
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          recipe.tips,
                          style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (recipe.notes.trim().isNotEmpty)
                  _Section(title: l10n.notes, child: Text(recipe.notes)),
                if (recipe.source.trim().isNotEmpty)
                  _Section(
                    title: l10n.source,
                    child: SelectableText(recipe.source),
                  ),
                const SizedBox(height: 24),
                Text(
                  l10n.addedOn(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(recipe.createdAt),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final facts = [
      if (recipe.servings case final s?)
        (Icons.people_outline, l10n.servingsCount(s)),
      if (recipe.prepMinutes case final m?)
        (Icons.content_cut, '${l10n.prepTime} ${formatMinutes(l10n, m)}'),
      if (recipe.cookMinutes case final m?)
        (
          Icons.local_fire_department_outlined,
          '${l10n.cookTime} ${formatMinutes(l10n, m)}',
        ),
      if (recipe.restMinutes case final m?)
        (Icons.hourglass_empty, '${l10n.restTime} ${formatMinutes(l10n, m)}'),
      if (recipe.totalMinutes case final m?)
        (Icons.schedule, '${l10n.totalTime} ${formatMinutes(l10n, m)}'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in facts)
          Chip(avatar: Icon(icon, size: 18), label: Text(label)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _IngredientList extends StatelessWidget {
  const _IngredientList({required this.lines});

  final List<IngredientLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines.where((l) => !l.isBlank))
          if (line.isSection)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(line.name, style: theme.textTheme.titleSmall),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: IngredientText.format(
                          IngredientLine(
                            id: line.id,
                            name: line.name,
                            quantity: line.quantity,
                            unit: line.unit,
                            note: line.note,
                          ),
                        ),
                        children: [
                          if (line.optional)
                            TextSpan(
                              text: ' · ${l10n.optionalIngredient}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = steps.where((s) => s.text.trim().isNotEmpty).toList();
    return Column(
      children: [
        for (final (index, step) in visible.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(step.text, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
