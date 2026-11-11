import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/text_search.dart';
import '../../data/app_services.dart';
import '../../domain/planning.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';
import '../recipes/recipe_providers.dart';
import '../recipes/recipe_scale.dart';

/// Ajouter un repas au créneau [slot] du jour [day] : une recette (avec le
/// nombre de personnes) ou une note libre. Avec [meal], le modifie (personnes,
/// note).
Future<void> showMealSheet(
  BuildContext context, {
  required DateTime day,
  required MealSlot slot,
  PlannedMeal? meal,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => _MealSheet(day: day, slot: slot, meal: meal),
);

class _MealSheet extends ConsumerStatefulWidget {
  const _MealSheet({required this.day, required this.slot, this.meal});

  final DateTime day;
  final MealSlot slot;
  final PlannedMeal? meal;

  @override
  ConsumerState<_MealSheet> createState() => _MealSheetState();
}

class _MealSheetState extends ConsumerState<_MealSheet> {
  late var _isNote = widget.meal != null && !widget.meal!.isRecipe;
  late final _note = TextEditingController(text: widget.meal?.note ?? '');
  var _query = '';
  Recipe? _recipe;
  late int? _servings = widget.meal?.servings;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _editing => widget.meal != null;

  Future<void> _save() async {
    final planning = ref.read(planningRepositoryProvider);
    final navigator = Navigator.of(context);
    final meal = widget.meal;
    if (meal != null) {
      await planning.update(
        meal.copyWith(
          servings: () => meal.isRecipe ? _servings : null,
          note: _note.text.trim(),
        ),
      );
    } else if (_isNote) {
      if (_note.text.trim().isEmpty) return;
      await planning.add(
        day: widget.day,
        slotId: widget.slot.id,
        note: _note.text,
      );
    } else {
      final recipe = _recipe;
      if (recipe == null) return;
      await planning.add(
        day: widget.day,
        slotId: widget.slot.id,
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        servings: _servings ?? recipe.servings,
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final day = MaterialLocalizations.of(context).formatFullDate(widget.day);
    final recipes = ref.watch(recipesProvider).value ?? const <Recipe>[];
    final key = normalizeForSearch(_query.trim());
    final shown = [
      for (final r in recipes)
        if (key.isEmpty || normalizeForSearch(r.title).contains(key)) r,
    ];
    final recipeChosen = _editing ? widget.meal!.isRecipe : _recipe != null;
    // La recette du repas : ses portions s'appellent peut-être « cake ».
    final recipe =
        _recipe ??
        recipes.where((r) => r.id == widget.meal?.recipeId).firstOrNull;
    final unitLabel = recipe != null && recipe.servingsUnit.isNotEmpty
        ? l10n.quantityLabel
        : l10n.servingsLabel;
    String countText(int? count) {
      if (count == null) return '–';
      return recipe == null
          ? l10n.personsShort(count)
          : servingsText(l10n, recipe, count);
    }

    final canSave = _editing
        ? true
        : _isNote
        ? _note.text.trim().isNotEmpty
        : _recipe != null;

    Widget servingsRow() => Row(
      children: [
        Expanded(child: Text(unitLabel)),
        IconButton(
          key: const ValueKey('meal-servings-less'),
          tooltip: l10n.fewerServings,
          onPressed: (_servings ?? 0) > 1
              ? () => setState(() => _servings = _servings! - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          countText(_servings),
          key: const ValueKey('meal-servings'),
          style: theme.textTheme.titleMedium,
        ),
        IconButton(
          key: const ValueKey('meal-servings-more'),
          tooltip: l10n.moreServings,
          onPressed: () => setState(() => _servings = (_servings ?? 0) + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editing
                ? (widget.meal!.isRecipe
                      ? l10n.editMealQuantities
                      : l10n.editMealNote)
                : l10n.addMealTo(widget.slot.name),
            style: theme.textTheme.titleLarge,
          ),
          Text(day, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          if (!_editing)
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(l10n.mealRecipe),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                  label: Text(l10n.mealNote),
                ),
              ],
              selected: {_isNote},
              onSelectionChanged: (value) =>
                  setState(() => _isNote = value.single),
            ),
          const SizedBox(height: 12),
          if (_isNote || _editing && !widget.meal!.isRecipe)
            TextField(
              key: const ValueKey('meal-note'),
              controller: _note,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.mealNote,
                hintText: l10n.mealNoteHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            )
          else if (_editing)
            servingsRow()
          else ...[
            TextField(
              key: const ValueKey('meal-recipe-search'),
              decoration: InputDecoration(
                hintText: l10n.searchRecipes,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: ListView(
                children: [
                  for (final recipe in shown)
                    ListTile(
                      key: ValueKey('meal-recipe-${recipe.id}'),
                      dense: true,
                      selected: _recipe?.id == recipe.id,
                      leading: Icon(
                        _recipe?.id == recipe.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(
                        recipe.title.trim().isEmpty
                            ? l10n.untitledRecipe
                            : recipe.title,
                      ),
                      onTap: () => setState(() {
                        _recipe = recipe;
                        _servings = recipe.servings;
                      }),
                    ),
                ],
              ),
            ),
            if (recipeChosen) servingsRow(),
          ],
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('meal-save'),
            onPressed: canSave ? _save : null,
            child: Text(_editing ? l10n.save : l10n.addMeal),
          ),
        ],
      ),
    );
  }
}
