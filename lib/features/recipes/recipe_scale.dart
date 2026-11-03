import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ingredient_text.dart';
import '../../domain/recipe.dart';
import '../../l10n/app_localizations.dart';

/// Le multiple appliqué aux quantités d'une recette affichée (1 = telle
/// qu'enregistrée). Propre à la fiche ouverte : il revient à 1 quand on la
/// quitte.
final recipeScaleProvider = NotifierProvider.autoDispose
    .family<RecipeScale, double, String>(RecipeScale.new);

class RecipeScale extends Notifier<double> {
  RecipeScale(this.recipeId);

  final String recipeId;

  @override
  double build() => 1;

  void set(double factor) => state = factor > 0 ? factor : 1;
}

/// Les nombres de portions proposés d'un appui.
const _servingsChoices = [2, 4, 6, 8, 12];

/// « 4 pers. », « 12 blinis » : un nombre de portions de [recipe].
String servingsText(AppLocalizations l10n, Recipe recipe, int count) =>
    recipe.servingsUnit.isEmpty
    ? l10n.personsShort(count)
    : '$count ${recipe.servingsUnit}';

/// Les portions voulues pour [factor], quand la recette en a.
int? scaledServings(Recipe recipe, double factor) {
  final servings = recipe.servings;
  if (servings == null || servings <= 0) return null;
  return (servings * factor).round();
}

/// Choix du nombre de portions d'une recette qui en a ; renvoie le nouveau
/// multiple, `null` si rien n'a été choisi.
Future<double?> showScaleDialog(
  BuildContext context,
  Recipe recipe,
  double current,
) => showDialog<double>(
  context: context,
  builder: (context) => _ScaleDialog(recipe: recipe, current: current),
);

class _ScaleDialog extends StatefulWidget {
  const _ScaleDialog({required this.recipe, required this.current});

  final Recipe recipe;
  final double current;

  @override
  State<_ScaleDialog> createState() => _ScaleDialogState();
}

class _ScaleDialogState extends State<_ScaleDialog> {
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  int get _servings => widget.recipe.servings!;

  void _submitOther() {
    final value = IngredientText.parseQuantity(_other.text);
    if (value == null || value <= 0) return;
    Navigator.pop(context, value.round().clamp(1, 999) / _servings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = widget.recipe;
    final servings = _servings;
    final counts = {..._servingsChoices, servings}.toList()..sort();
    final choices = [
      for (final count in counts)
        (servingsText(l10n, recipe, count), count / servings),
    ];
    final title = recipe.servingsUnit.isEmpty
        ? l10n.servingsLabel
        : l10n.quantityLabel;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.scaleRecipeFor(servingsText(l10n, recipe, servings)),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, factor) in choices)
                  ChoiceChip(
                    key: ValueKey('scale-$factor'),
                    label: Text(label),
                    selected: (factor - widget.current).abs() < 1e-6,
                    onSelected: (_) => Navigator.pop(context, factor),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('scale-other'),
              controller: _other,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.scaleOther,
                suffixIcon: IconButton(
                  key: const ValueKey('scale-other-ok'),
                  icon: const Icon(Icons.check),
                  tooltip: MaterialLocalizations.of(context).okButtonLabel,
                  onPressed: _submitOther,
                ),
              ),
              onSubmitted: (_) => _submitOther(),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.current != 1)
          TextButton(
            key: const ValueKey('scale-reset'),
            onPressed: () => Navigator.pop(context, 1.0),
            child: Text(l10n.scaleReset),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
