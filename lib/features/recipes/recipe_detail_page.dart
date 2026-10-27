import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../core/widgets/linked_text.dart';
import '../../data/app_services.dart';
import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import 'recipe_photo.dart';
import 'recipe_providers.dart';

/// Largeur à partir de laquelle la fiche passe sur deux colonnes (tablette).
const _wideBreakpoint = 840.0;

/// Largeur de la colonne de gauche (photo, infos, ingrédients) sur tablette.
const _widePaneWidth = 440.0;

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

String _capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

class _RecipeDetail extends ConsumerWidget {
  const _RecipeDetail({required this.recipe});

  final Recipe recipe;

  String _title(AppLocalizations l10n) =>
      recipe.title.trim().isEmpty ? l10n.untitledRecipe : recipe.title;

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

  void _edit(BuildContext context) =>
      context.push('/recettes/${recipe.id}/modifier');

  Widget _topButtons(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleButton(
          icon: Icons.edit_outlined,
          tooltip: l10n.edit,
          onPressed: () => _edit(context),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<_MenuAction>(
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
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
          child: const _CircleIcon(icon: Icons.more_vert),
        ),
      ],
    );
  }

  Widget _backButton(BuildContext context) => _CircleButton(
    icon: Icons.arrow_back,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: () => context.pop(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= _wideBreakpoint
        ? _buildWide(context, ref)
        : _buildNarrow(context, ref, width);
  }

  Widget _buildNarrow(BuildContext context, WidgetRef ref, double width) {
    final hasPhoto = recipe.mainPhoto != null;
    // Photo carrée sur toute la largeur ; sans photo, un bandeau plus bas.
    final heroHeight = hasPhoto ? width : 200.0;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            expandedHeight: heroHeight,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(child: _backButton(context)),
            ),
            actions: [_topButtons(context, ref), const SizedBox(width: 12)],
            flexibleSpace: FlexibleSpaceBar(
              background: RecipePhoto(
                photo: recipe.mainPhoto,
                decodeWidth: 1440,
                iconSize: 64,
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(_sheetRadius),
              child: _SheetTop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(recipe: recipe),
                  _IngredientsSection(recipe: recipe),
                  _StepsSection(recipe: recipe),
                  ..._secondarySections(context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWide(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: _widePaneWidth,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox.square(
                  dimension: _widePaneWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RecipePhoto(
                        photo: recipe.mainPhoto,
                        decodeWidth: 1320,
                        iconSize: 64,
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: _backButton(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(recipe: recipe),
                      _IngredientsSection(recipe: recipe),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 12, 32, 40),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SafeArea(child: _topButtons(context, ref)),
                ),
                _StepsSection(recipe: recipe),
                ..._secondarySections(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _secondarySections(BuildContext context, WidgetRef ref) {
    return [
      if (recipe.description.trim().isNotEmpty)
        _DescriptionSection(recipe: recipe),
      _NotesSection(recipe: recipe, onEdit: () => _edit(context)),
      _AboutSection(recipe: recipe, onCooked: () => _markCooked(context, ref)),
    ];
  }
}

const _sheetRadius = 28.0;

/// Le haut arrondi de la fiche blanche, qui recouvre le bas de la photo.
class _SheetTop extends StatelessWidget {
  const _SheetTop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: _sheetRadius,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_sheetRadius),
        ),
      ),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Un bouton rond posé sur la photo.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface.withValues(alpha: 0.92),
      ),
      child: Icon(icon, color: scheme.onSurface),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        foregroundColor: scheme.onSurface,
      ),
    );
  }
}

Color _tint(BuildContext context) =>
    Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

/// « Prêt en 12 h environ, dont 10 h de repos », ou `null` s'il n'y a rien
/// d'utile à ajouter aux cartes de temps.
String? _readyIn(AppLocalizations l10n, Recipe recipe) {
  final total = recipe.totalMinutes;
  final given = [
    recipe.prepMinutes,
    recipe.cookMinutes,
    recipe.restMinutes,
  ].nonNulls.length;
  if (total == null || given < 2) return null;

  var minutes = total;
  var approximate = false;
  if (total >= 120) {
    final rounded = (total / 15).round() * 15;
    approximate = rounded != total;
    minutes = rounded;
  }
  final duration = formatMinutes(l10n, minutes);
  final ready = approximate
      ? l10n.readyInApprox(duration)
      : l10n.readyIn(duration);
  final rest = recipe.restMinutes;
  return rest == null || rest == 0
      ? ready
      : '$ready${l10n.ofWhichRest(formatMinutes(l10n, rest))}';
}

class _Header extends StatelessWidget {
  const _Header({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = recipe.title.trim().isEmpty
        ? l10n.untitledRecipe
        : recipe.title;
    final times = [
      (Icons.timer_outlined, l10n.prepTime, recipe.prepMinutes),
      (Icons.local_fire_department_outlined, l10n.cookTime, recipe.cookMinutes),
      (Icons.bedtime_outlined, l10n.restTime, recipe.restMinutes),
    ].where((t) => t.$3 != null).toList();
    final ready = _readyIn(l10n, recipe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        if (times.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (index, time) in times.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TimeCard(
                    icon: time.$1,
                    label: time.$2,
                    value: formatMinutes(l10n, time.$3!),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (ready != null) ...[
          const SizedBox(height: 10),
          Text(
            ready,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (recipe.servings case final servings?) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.servingsLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _tint(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  l10n.personsShort(servings),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _tint(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines = recipe.ingredients.where((l) => !l.isBlank).toList();
    if (lines.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (final (index, line) in lines.indexed) {
      if (line.isSection) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 20, bottom: 4),
            child: Row(
              children: [
                Text(
                  _capitalize(line.name),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Divider(height: 1)),
              ],
            ),
          ),
        );
        continue;
      }
      // Un trait entre deux ingrédients, pas après un titre de groupe.
      if (index > 0 && !lines[index - 1].isSection) {
        children.add(const Divider(height: 1, thickness: 0.5));
      }
      children.add(
        _IngredientRow(line: line, optionalLabel: l10n.optionalIngredient),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionTitle(l10n.ingredients), ...children],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.line, required this.optionalLabel});

  final IngredientLine line;
  final String optionalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final amount = IngredientText.formatAmount(line);
    // Sans quantité (« sel, selon le goût »), la précision passe à droite.
    final noteOnRight = amount.isEmpty && line.note.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: _capitalize(line.name),
                    children: [
                      if (line.optional)
                        TextSpan(
                          text: ' · $optionalLabel',
                          style: muted.copyWith(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                if (!noteOnRight && line.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.note,
                      style: theme.textTheme.bodySmall?.merge(muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Quantité alignée au bord droit ; plafonnée pour qu'une longue
          // précision n'écrase pas le nom.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: Text(
              noteOnRight ? line.note : amount,
              textAlign: TextAlign.right,
              style: noteOnRight
                  ? theme.textTheme.bodyMedium?.merge(muted)
                  : theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final steps = recipe.steps.where((s) => s.text.trim().isNotEmpty).toList();
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.fieldSteps),
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (step.title.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            step.title.trim().toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      Text(
                        step.text,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.descriptionTitle),
        Text(
          recipe.description,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
      ],
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.recipe, required this.onEdit});

  final Recipe recipe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hasNotes = recipe.notes.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.notes),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _tint(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.notes,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasNotes ? recipe.notes : l10n.noteEmpty,
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  color: hasNotes ? null : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                child: Text(hasNotes ? l10n.editNotes : l10n.addNote),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.recipe, required this.onCooked});

  final Recipe recipe;
  final VoidCallback onCooked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = recipe.source.trim();
    final links = findLinks(source);
    final host = links.isEmpty ? '' : links.first.host.toLowerCase();
    final isVideo =
        host.contains('youtube') ||
        host.contains('youtu.be') ||
        host.contains('vimeo') ||
        host.contains('dailymotion');
    final (icon, label) = links.isEmpty
        ? (Icons.menu_book_outlined, l10n.sourceLabel)
        : isVideo
        ? (Icons.play_circle_outline, l10n.sourceVideo)
        : (Icons.language, l10n.sourceWebsite);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.sectionAbout),
        if (source.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _tint(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      LinkedText(source, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
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
              onPressed: onCooked,
              icon: const Icon(Icons.check),
              label: Text(l10n.iCookedThis),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.addedOn(
            MaterialLocalizations.of(context)
                .formatMediumDate(recipe.createdAt),
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
