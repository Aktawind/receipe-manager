/// Rubriques de la fiche recette : ingrédients, préparation, notes, matériel,
/// statut et informations.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/formatted_text.dart';
import '../../../core/widgets/linked_text.dart';
import '../../../domain/ingredient_scaling.dart';
import '../../../domain/ingredient_text.dart';
import '../../../domain/recipe.dart';
import '../../../l10n/app_localizations.dart';
import '../../classification/label_chips.dart';
import '../../equipment/equipment_providers.dart';
import '../recipe_photo.dart';
import '../recipe_scale.dart';
import 'detail_header.dart';

class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.text, {super.key});

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

class DetailIngredientsSection extends ConsumerWidget {
  const DetailIngredientsSection({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines = recipe.ingredients.where((l) => !l.isBlank).toList();
    if (lines.isEmpty) return const SizedBox.shrink();
    final factor = ref.watch(recipeScaleProvider(recipe.id));
    final scaled = factor == 1 ? null : IngredientScaling.scale(lines, factor);

    final children = <Widget>[];
    for (final (index, line) in lines.indexed) {
      if (line.isSection) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 20, bottom: 4),
            child: Row(
              children: [
                Text(
                  capitalize(line.name),
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
        DetailIngredientRow(
          line: line,
          scaled: scaled?[index],
          optionalLabel: l10n.optionalIngredient,
          substitutesPrefix: l10n.substitutesPrefix,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [DetailSectionTitle(l10n.ingredients), ...children],
    );
  }
}

class DetailIngredientRow extends StatelessWidget {
  const DetailIngredientRow({
    super.key,
    required this.line,
    this.scaled,
    required this.optionalLabel,
    required this.substitutesPrefix,
  });

  final IngredientLine line;

  /// La ligne recalculée pour d'autres portions ; `null` telle qu'enregistrée.
  final ScaledIngredient? scaled;

  final String optionalLabel;
  final String substitutesPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final scaled = this.scaled;
    final amount = IngredientText.formatAmount(scaled?.scaledLine ?? line);
    final extras = <TextSpan>[];
    if (scaled != null) {
      final exact = scaled.exact;
      if (scaled.notice == ScaleNotice.rounded && exact != null) {
        extras.add(
          TextSpan(
            text: ' · ${l10n.scaleExact(IngredientText.formatQuantity(exact))}',
            style: muted,
          ),
        );
      }
      final hint = switch (scaled.notice) {
        ScaleNotice.leavening => l10n.scaleNoticeLeavening,
        ScaleNotice.seasoning => l10n.scaleNoticeSeasoning,
        ScaleNotice.manual => l10n.scaleNoticeManual,
        _ => null,
      };
      if (hint != null) {
        extras.add(
          TextSpan(
            text: ' · $hint',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    }
    final name = line.name.trim();
    // « 200 g de farine », « 1 yaourt nature », « Sel, selon le goût » : une
    // seule phrase, la quantité juste avant l'ingrédient.
    final connector = line.unit.isNotEmpty && name.isNotEmpty
        ? IngredientText.partitive(name)
        : '';

    final linkedId = line.linkedRecipeId;
    final linkStyle = TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final sentence = Text.rich(
      TextSpan(
        children: [
          if (amount.isNotEmpty)
            TextSpan(
              text: '$amount ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (amount.isNotEmpty && connector.isNotEmpty)
            TextSpan(text: connector),
          TextSpan(
            text: amount.isEmpty ? capitalize(name) : name,
            style: linkedId == null ? null : linkStyle,
          ),
          if (linkedId != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          if (line.note.isNotEmpty)
            TextSpan(text: ', ${line.note}', style: muted),
          if (line.optional)
            TextSpan(
              text: ' · $optionalLabel',
              style: muted.copyWith(fontStyle: FontStyle.italic),
            ),
          ...extras,
        ],
      ),
      style: theme.textTheme.bodyLarge?.copyWith(height: 1.25),
    );

    return Padding(
      // Des lignes serrées : une liste d'ingrédients se lit d'un coup d'œil.
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (linkedId == null)
            sentence
          else
            InkWell(
              onTap: () => context.push('/recettes/$linkedId'),
              child: sentence,
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

class DetailStepsSection extends StatelessWidget {
  const DetailStepsSection({super.key, required this.recipe});

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
        DetailSectionTitle(l10n.fieldSteps),
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

class DetailNotesSection extends StatelessWidget {
  const DetailNotesSection({
    super.key,
    required this.recipe,
    required this.onEdit,
  });

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
        DetailSectionTitle(l10n.notes),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: detailTint(context),
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
              if (hasNotes) ...[
                const SizedBox(height: 8),
                Text(
                  recipe.notes,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                ),
              ],
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

class DetailAboutSection extends StatelessWidget {
  const DetailAboutSection({super.key, required this.recipe});

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
        DetailSectionTitle(l10n.sectionAbout),
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
                    color: detailTint(context),
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
        if (recipe.labelIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          RecipeLabelChips(labelIds: recipe.labelIds),
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
                          onTap: () => showRecipePhoto(context, name),
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

/// Où en est la recette : son statut, qu'on change d'un geste.
class DetailStatusRow extends StatelessWidget {
  const DetailStatusRow({
    super.key,
    required this.recipe,
    required this.onStatus,
  });

  final Recipe recipe;
  final ValueChanged<RecipeStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String statusLabel(RecipeStatus status) => switch (status) {
      RecipeStatus.toTest => l10n.statusToTest,
      RecipeStatus.toRetest => l10n.statusToRetest,
      RecipeStatus.toImprove => l10n.statusToImprove,
      RecipeStatus.validated => l10n.statusValidated,
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
      ],
    );
  }
}

class DetailEquipmentSection extends ConsumerWidget {
  const DetailEquipmentSection({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (recipe.equipmentIds.isEmpty) return const SizedBox.shrink();
    final names = {
      for (final item in ref.watch(equipmentProvider).value ?? const [])
        item.id: item.name,
    };
    final items = [for (final id in recipe.equipmentIds) ?names[id]];
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DetailSectionTitle(l10n.equipment),
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
                Expanded(child: Text(item, style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Le fond teinté des cartes de la fiche (temps, notes, informations).
Color detailTint(BuildContext context) =>
    Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);

String capitalize(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
