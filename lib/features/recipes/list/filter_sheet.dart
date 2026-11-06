/// Le panneau des filtres de la liste des recettes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/durations.dart';
import '../../../domain/label.dart';
import '../../../domain/recipe.dart';
import '../../../domain/recipe_filter.dart';
import '../../../l10n/app_localizations.dart';
import '../../classification/label_picker.dart';
import '../../classification/labels_providers.dart';
import '../filter_dialogs.dart';
import '../recipe_providers.dart';
import '../saved_searches.dart';

/// Le filtre : « Favoris », « Statut », puis une ligne par
/// famille de classement, qui ouvre une liste à cocher. Statuts, catégories
/// (principales seulement), saisons et origines : l'un ou l'autre ; collections :
/// toutes celles qui sont cochées ; critères différents : tous ensemble.
Future<void> showRecipeFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const RecipeFilterSheet(),
  );
}

class RecipeFilterSheet extends ConsumerWidget {
  const RecipeFilterSheet({super.key});

  Future<void> _chooseStatuses(BuildContext context, WidgetRef ref) async {
    final chosen = await showDialog<Set<RecipeStatus>>(
      context: context,
      builder: (context) =>
          StatusFilterDialog(initial: ref.read(recipeFilterProvider).statuses),
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
class StatusFilterDialog extends StatefulWidget {
  const StatusFilterDialog({super.key, required this.initial});

  final Set<RecipeStatus> initial;

  @override
  State<StatusFilterDialog> createState() => _StatusFilterDialogState();
}

class _StatusFilterDialogState extends State<StatusFilterDialog> {
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
