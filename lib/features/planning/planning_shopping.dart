import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/app_services.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../shopping/add_to_shopping_sheet.dart';

/// Les courses de la semaine : choisir les repas (recettes et notes), puis
/// leurs ingrédients dans la feuille « Ajouter aux courses ». Les restes sont
/// décochés (déjà cuisinés).
Future<void> addWeekToShopping(
  BuildContext context,
  WidgetRef ref, {
  required List<PlannedMeal> meals,
  required List<MealSlot> slots,
}) async {
  if (meals.isEmpty) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(persist: false, content: Text(l10n.planningNothingToShop)),
    );
    return;
  }
  final chosen = await showDialog<List<PlannedMeal>>(
    context: context,
    builder: (context) => _MealsDialog(meals: meals, slots: slots),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  final repository = ref.read(recipeRepositoryProvider);
  final locale = Localizations.localeOf(context).toString();
  final slotNames = {for (final s in slots) s.id: s.name};
  final entries = <ShoppingEntry>[];
  final notes = <String>[];
  for (final meal in chosen) {
    if (!meal.isRecipe) {
      if (meal.note.trim().isNotEmpty) notes.add(meal.note.trim());
      continue;
    }
    final recipe = await repository.getRecipe(meal.recipeId!);
    if (recipe == null || recipe.isDeleted) continue;
    entries.add((
      recipe: recipe,
      factor: _factorOf(recipe, meal),
      label:
          '${DateFormat.MMMMEEEEd(locale).format(meal.day)} · '
          '${slotNames[meal.slotId] ?? ''}',
    ));
  }
  if (!context.mounted || (entries.isEmpty && notes.isEmpty)) return;
  await showAddToShoppingSheet(context, entries: entries, notes: notes);
}

/// Les personnes du repas par rapport à celles de la recette.
double _factorOf(Recipe recipe, PlannedMeal meal) {
  final servings = recipe.servings;
  final wanted = meal.servings;
  if (servings == null || servings <= 0 || wanted == null) return 1;
  return wanted / servings;
}

class _MealsDialog extends StatefulWidget {
  const _MealsDialog({required this.meals, required this.slots});

  final List<PlannedMeal> meals;
  final List<MealSlot> slots;

  @override
  State<_MealsDialog> createState() => _MealsDialogState();
}

class _MealsDialogState extends State<_MealsDialog> {
  final _chosen = <String>{};

  List<PlannedMeal> get _ordered {
    final position = {for (final (i, s) in widget.slots.indexed) s.id: i};
    return [...widget.meals]..sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      if (byDay != 0) return byDay;
      final bySlot = (position[a.slotId] ?? 99).compareTo(
        position[b.slotId] ?? 99,
      );
      return bySlot != 0 ? bySlot : a.position.compareTo(b.position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final slotNames = {for (final s in widget.slots) s.id: s.name};
    final meals = _ordered;
    final selectable = [
      for (final m in meals)
        if (!m.isLeftovers) m.id,
    ];
    final all = selectable.isNotEmpty && selectable.every(_chosen.contains);
    DateTime? lastDay;
    final rows = <Widget>[];
    for (final meal in meals) {
      if (meal.day != lastDay) {
        lastDay = meal.day;
        final title = DateFormat.MMMMEEEEd(locale).format(meal.day);
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 2),
            child: Text(
              title[0].toUpperCase() + title.substring(1),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      final name = meal.isRecipe
          ? (meal.recipeTitle.trim().isEmpty
                ? l10n.untitledRecipe
                : meal.recipeTitle)
          : meal.note;
      rows.add(
        CheckboxListTile(
          key: ValueKey('week-shop-${meal.id}'),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: _chosen.contains(meal.id),
          title: Text(name),
          subtitle: Text(
            [
              slotNames[meal.slotId] ?? '',
              if (meal.isLeftovers) l10n.leftovers,
            ].join(' · '),
          ),
          onChanged: (on) => setState(() {
            on == true ? _chosen.add(meal.id) : _chosen.remove(meal.id);
          }),
        ),
      );
    }
    return AlertDialog(
      title: Text(l10n.weekToShopping),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('week-shop-all'),
                onPressed: () => setState(() {
                  all ? _chosen.clear() : _chosen.addAll(selectable);
                }),
                icon: Icon(all ? Icons.remove_done : Icons.done_all),
                label: Text(all ? l10n.uncheckAll : l10n.checkAll),
              ),
            ),
            Expanded(child: ListView(children: rows)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('week-shop-ok'),
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final m in meals)
                    if (_chosen.contains(m.id)) m,
                ]),
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}
