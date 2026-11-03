import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ingredient_scaling.dart';
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

/// Les multiples proposés pour une recette sans nombre de portions.
const _factorChoices = [0.5, 1.0, 1.5, 2.0, 3.0];

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

/// Choix du nombre de portions (ou d'un multiple) ; renvoie le nouveau
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

  int? get _servings {
    final servings = widget.recipe.servings;
    return servings != null && servings > 0 ? servings : null;
  }

  void _submitOther() {
    final value = IngredientText.parseQuantity(_other.text);
    if (value == null || value <= 0) return;
    final servings = _servings;
    Navigator.pop(
      context,
      servings == null ? value : value.round().clamp(1, 999) / servings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = widget.recipe;
    final servings = _servings;
    final List<(String, double)> choices;
    if (servings == null) {
      choices = [
        for (final f in _factorChoices)
          (l10n.scaleTimes(IngredientText.formatQuantity(f)), f),
      ];
    } else {
      final counts = {..._servingsChoices, servings}.toList()..sort();
      choices = [
        for (final count in counts)
          (servingsText(l10n, recipe, count), count / servings),
      ];
    }
    final title = servings == null
        ? l10n.scaleTitleFactor
        : recipe.servingsUnit.isEmpty
        ? l10n.servingsLabel
        : l10n.quantityLabel;

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (servings != null)
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
                labelText: servings == null
                    ? l10n.scaleOtherFactor
                    : l10n.scaleOther,
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

/// En tête des ingrédients recalculés : pour combien, et ce qui ne suit pas
/// les proportions.
class ScaleBanner extends StatelessWidget {
  const ScaleBanner({
    super.key,
    required this.recipe,
    required this.factor,
    required this.scaled,
    required this.hasMould,
    required this.onReset,
  });

  final Recipe recipe;
  final double factor;
  final List<ScaledIngredient> scaled;
  final bool hasMould;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notices = {for (final s in scaled) ?s.notice};
    final wanted = scaledServings(recipe, factor);
    final amount = wanted == null
        ? l10n.scaleTimes(IngredientText.formatQuantity(factor))
        : '${servingsText(l10n, recipe, wanted)} · '
              '${l10n.scaleRecipeFor(servingsText(l10n, recipe, recipe.servings!))}';
    final warnings = [
      if (recipe.cookMinutes != null) l10n.scaleCookWarning,
      if (notices.contains(ScaleNotice.leavening) ||
          notices.contains(ScaleNotice.seasoning))
        l10n.scaleSeasoningWarning,
      if (hasMould) l10n.scaleMouldWarning,
      if (notices.contains(ScaleNotice.rounded)) l10n.scaleRoundedWarning,
      if (notices.contains(ScaleNotice.manual)) l10n.scaleManualWarning,
    ];
    return Container(
      key: const ValueKey('scale-banner'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.scaledBanner(amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('scale-banner-reset'),
                tooltip: l10n.scaleReset,
                onPressed: onReset,
                icon: Icon(
                  Icons.restart_alt,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
