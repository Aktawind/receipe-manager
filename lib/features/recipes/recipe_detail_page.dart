import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/durations.dart';
import '../../core/widgets/formatted_text.dart';
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

/// Hauteur de la barre système (navigation Android) à ne pas recouvrir.
double _bottomInset(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom;

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
          icon: recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
          tooltip: recipe.isFavorite
              ? l10n.removeFromFavorites
              : l10n.addToFavorites,
          onPressed: () => ref
              .read(recipeRepositoryProvider)
              .setFavorite(recipe.id, !recipe.isFavorite),
        ),
        const SizedBox(width: 8),
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
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                40 + _bottomInset(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    recipe: recipe,
                    onCooked: () => _markCooked(context, ref),
                    onStatus: (status) => ref
                        .read(recipeRepositoryProvider)
                        .setStatus(recipe.id, status),
                    onRating: (rating) => ref
                        .read(recipeRepositoryProvider)
                        .setRating(recipe.id, rating),
                  ),
                  _IngredientsSection(recipe: recipe),
                  _EquipmentSection(recipe: recipe),
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
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    40 + _bottomInset(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        recipe: recipe,
                        onCooked: () => _markCooked(context, ref),
                        onStatus: (status) => ref
                            .read(recipeRepositoryProvider)
                            .setStatus(recipe.id, status),
                        onRating: (rating) => ref
                            .read(recipeRepositoryProvider)
                            .setRating(recipe.id, rating),
                      ),
                      _IngredientsSection(recipe: recipe),
                      _EquipmentSection(recipe: recipe),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                32,
                12,
                32,
                40 + _bottomInset(context),
              ),
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
      _NotesSection(recipe: recipe, onEdit: () => _edit(context)),
      _AboutSection(recipe: recipe),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.recipe,
    required this.onCooked,
    required this.onStatus,
    required this.onRating,
  });

  final Recipe recipe;
  final VoidCallback onCooked;
  final ValueChanged<RecipeStatus?> onStatus;
  final ValueChanged<int?> onRating;

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

    final labels = [
      if (recipe.course.isNotEmpty) recipe.course,
      if (recipe.category.isNotEmpty) recipe.category,
    ];

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
        if (recipe.description.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            recipe.description.trim(),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.4,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _StatusRow(recipe: recipe, onCooked: onCooked, onStatus: onStatus),
        const SizedBox(height: 8),
        _StarRating(rating: recipe.rating, onChanged: onRating),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in labels)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _tint(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(label, style: theme.textTheme.labelMedium),
                ),
            ],
          ),
        ],
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
        if (recipe.servings case final servings?) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  recipe.servingsUnit.isEmpty
                      ? l10n.servingsLabel
                      : l10n.quantityLabel,
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
                  recipe.servingsUnit.isEmpty
                      ? l10n.personsShort(servings)
                      : '$servings ${recipe.servingsUnit}',
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
      children.add(
        _IngredientRow(
          line: line,
          optionalLabel: l10n.optionalIngredient,
          substitutesPrefix: l10n.substitutesPrefix,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionTitle(l10n.ingredients), ...children],
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.line,
    required this.optionalLabel,
    required this.substitutesPrefix,
  });

  final IngredientLine line;
  final String optionalLabel;
  final String substitutesPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final amount = IngredientText.formatAmount(line);
    final name = line.name.trim();
    // « 200 g de farine », « 1 yaourt nature », « Sel, selon le goût » : une
    // seule phrase, la quantité juste avant l'ingrédient.
    final connector = line.unit.isNotEmpty && name.isNotEmpty
        ? IngredientText.partitive(name)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (amount.isNotEmpty)
                  TextSpan(
                    text: '$amount ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                TextSpan(
                  text: amount.isEmpty ? _capitalize(name) : '$connector$name',
                ),
                if (line.note.isNotEmpty)
                  TextSpan(text: ', ${line.note}', style: muted),
                if (line.optional)
                  TextSpan(
                    text: ' · $optionalLabel',
                    style: muted.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            style: theme.textTheme.bodyLarge,
          ),
          if (line.substitutes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '$substitutesPrefix\u00a0: ${line.substitutes}',
                style: theme.textTheme.bodySmall?.merge(muted),
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
                      FormattedText(
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
  const _AboutSection({required this.recipe});

  final Recipe recipe;

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
        if (recipe.collections.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${l10n.collectionsLabel} : ${recipe.collections.join(' · ')}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (recipe.videoLinks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.videosLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final link in recipe.videoLinks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinkedText(link, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
        if (recipe.linkedRecipeIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.linkedRecipesLabel, style: theme.textTheme.titleSmall),
          for (final id in recipe.linkedRecipeIds) _LinkedRecipeTile(id: id),
        ],
        if (recipe.extraPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.morePhotos, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final name in recipe.extraPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox.square(
                        dimension: 110,
                        child: InkWell(
                          onTap: () => _showPhoto(context, name),
                          child: RecipePhoto(photo: name, decodeWidth: 330),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

void _showPhoto(BuildContext context, String name) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1,
        child: InteractiveViewer(child: RecipePhoto(photo: name)),
      ),
    ),
  );
}

/// Une recette utilisée par celle-ci (pâte, sauce) ; touche pour l'ouvrir.
class _LinkedRecipeTile extends ConsumerWidget {
  const _LinkedRecipeTile({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(id)).value;
    if (recipe == null || recipe.isDeleted) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.link),
      title: Text(recipe.title),
      onTap: () => context.push('/recettes/$id'),
    );
  }
}

/// Où en est la recette : son statut (qu'on change d'un geste) et le nombre de
/// fois où elle a été réalisée (un geste pour ajouter une fois).
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.recipe,
    required this.onCooked,
    required this.onStatus,
  });

  final Recipe recipe;
  final VoidCallback onCooked;
  final ValueChanged<RecipeStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String statusLabel(RecipeStatus status) => switch (status) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.validated => l10n.statusValidated,
      RecipeStatus.toImprove => l10n.statusToImprove,
    };
    final status = recipe.status;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        PopupMenuButton<int>(
          tooltip: l10n.statusLabel,
          onSelected: (index) => onStatus(
            index < RecipeStatus.values.length
                ? RecipeStatus.values[index]
                : null,
          ),
          itemBuilder: (context) => [
            for (final (index, value) in RecipeStatus.values.indexed)
              CheckedPopupMenuItem(
                value: index,
                checked: value == status,
                child: Text(statusLabel(value)),
              ),
            PopupMenuItem(
              value: RecipeStatus.values.length,
              child: Text(l10n.statusNone),
            ),
          ],
          child: Chip(
            avatar: Icon(
              status == null ? Icons.flag_outlined : Icons.flag,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(status == null ? l10n.statusLabel : statusLabel(status)),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        ActionChip(
          avatar: Icon(
            recipe.timesCooked > 0
                ? Icons.check_circle
                : Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            recipe.timesCooked > 0
                ? l10n.timesCooked(recipe.timesCooked)
                : l10n.neverCooked,
          ),
          tooltip: l10n.iCookedThis,
          onPressed: onCooked,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _EquipmentSection extends StatelessWidget {
  const _EquipmentSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final items = recipe.equipment.where((e) => e.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.equipment),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.kitchen_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(item.trim(), style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cinq étoiles : un appui note de 1 à 5, un appui sur l'étoile déjà choisie
/// retire la note.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onChanged});

  final int? rating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          InkResponse(
            radius: 20,
            onTap: () => onChanged(rating == star ? null : star),
            child: Tooltip(
              message: rating == star ? l10n.clearRating : l10n.rateStars(star),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  star <= (rating ?? 0) ? Icons.star : Icons.star_border,
                  size: 26,
                  color: scheme.tertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
