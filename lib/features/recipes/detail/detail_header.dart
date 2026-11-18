/// Haut de la fiche recette : photo, titre, note, personnes et temps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/durations.dart';
import '../../../domain/recipe.dart';
import '../../../l10n/app_localizations.dart';
import '../rating_stars.dart';
import '../recipe_photo.dart';
import '../recipe_scale.dart';
import 'detail_sections.dart';

const detailSheetRadius = 28.0;

/// Le haut arrondi de la fiche blanche, qui recouvre le bas de la photo.
class DetailSheetTop extends StatelessWidget {
  const DetailSheetTop({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: detailSheetRadius,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(detailSheetRadius),
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
class DetailCircleIcon extends StatelessWidget {
  const DetailCircleIcon({super.key, required this.icon});

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

class DetailCircleButton extends StatelessWidget {
  const DetailCircleButton({
    super.key,
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

class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.recipe,
    required this.onStatus,
    required this.onRating,
  });

  final Recipe recipe;
  final ValueChanged<RecipeStatus?> onStatus;
  final ValueChanged<double?> onRating;

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
        DetailStatusRow(recipe: recipe, onStatus: onStatus),
        const SizedBox(height: 8),
        DetailStarRating(rating: recipe.rating, onChanged: onRating),
        if (times.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (index, time) in times.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: DetailTimeCard(
                    icon: time.$1,
                    label: time.$2,
                    value: formatMinutes(l10n, time.$3!),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (recipe.servings case final servings? when servings > 0) ...[
          const SizedBox(height: 16),
          DetailServingsRow(recipe: recipe),
        ],
      ],
    );
  }
}

/// Le nombre de portions, qu'on change d'un appui : les quantités des
/// ingrédients suivent.
class DetailServingsRow extends ConsumerWidget {
  const DetailServingsRow({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final servings = recipe.servings!;
    final factor = ref.watch(recipeScaleProvider(recipe.id));
    final scale = ref.read(recipeScaleProvider(recipe.id).notifier);
    final wanted = scaledServings(recipe, factor) ?? servings;
    final changed = wanted != servings;
    final row = Row(
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
        IconButton(
          key: const ValueKey('servings-less'),
          tooltip: l10n.scaleLess,
          icon: const Icon(Icons.remove),
          onPressed: wanted > 1
              ? () => scale.set((wanted - 1) / servings)
              : null,
        ),
        Material(
          color: detailTint(context),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            key: const ValueKey('servings-pill'),
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              final chosen = await showScaleDialog(context, recipe, factor);
              if (chosen != null) scale.set(chosen);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(
                servingsText(l10n, recipe, wanted),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: changed ? theme.colorScheme.primary : null,
                  fontWeight: changed ? FontWeight.w800 : null,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('servings-more'),
          tooltip: l10n.scaleMore,
          icon: const Icon(Icons.add),
          onPressed: () => scale.set((wanted + 1) / servings),
        ),
      ],
    );
    return row;
  }
}

class DetailTimeCard extends StatelessWidget {
  const DetailTimeCard({
    super.key,
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
        color: detailTint(context),
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

void showRecipePhoto(BuildContext context, String name) {
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

/// Cinq étoiles : un appui sur la moitié gauche d'une étoile donne la
/// demi-étoile (4,5), sur la moitié droite l'étoile entière ; un appui qui
/// redonne la note déjà choisie la retire.
class DetailStarRating extends StatefulWidget {
  const DetailStarRating({
    super.key,
    required this.rating,
    required this.onChanged,
  });

  final double? rating;
  final ValueChanged<double?> onChanged;

  @override
  State<DetailStarRating> createState() => _DetailStarRatingState();
}

class _DetailStarRatingState extends State<DetailStarRating> {
  /// L'appui en cours tombe sur la moitié gauche de l'étoile. Sans position
  /// (lecteur d'écran) : l'étoile entière.
  var _leftHalf = false;

  static const _size = 48.0;

  void _tap(int star) {
    final value = _leftHalf ? star - 0.5 : star.toDouble();
    _leftHalf = false;
    widget.onChanged(widget.rating == value ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final rating = widget.rating;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          InkResponse(
            radius: 22,
            onTapDown: (details) =>
                _leftHalf = details.localPosition.dx < _size / 2,
            onTapCancel: () => _leftHalf = false,
            onTap: () => _tap(star),
            child: Tooltip(
              message: rating == star ? l10n.clearRating : l10n.rateStars(star),
              // 26 + 2 × 11 = 48 : une zone facile à toucher.
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  starIcon(star, rating),
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
