import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/durations.dart';
import '../../core/platform/export_actions.dart';
import '../../data/app_services.dart';
import '../../domain/recipe.dart';
import '../../domain/recipe_export.dart';
import '../../l10n/app_localizations.dart';
import 'list/recipe_views.dart';
import 'recipe_pdf.dart';
import 'recipe_scale.dart';

/// Partager une recette : en texte, en PDF (fichier envoyé à une autre app),
/// ou l'imprimer.
enum RecipeShare { text, pdf, print }

/// Portions (pour [factor]) et temps de la recette : « 6 pers. »,
/// « Préparation 20 min »…
List<String> recipeExportInfo(
  AppLocalizations l10n,
  Recipe recipe,
  double factor,
) => [
  if (scaledServings(recipe, factor) case final count?)
    servingsText(l10n, recipe, count),
  if (recipe.prepMinutes case final m? when m > 0)
    '${l10n.prepTime} ${formatMinutes(l10n, m)}',
  if (recipe.cookMinutes case final m? when m > 0)
    '${l10n.cookTime} ${formatMinutes(l10n, m)}',
  if (recipe.restMinutes case final m? when m > 0)
    '${l10n.restTime} ${formatMinutes(l10n, m)}',
];

RecipeExportWords recipeExportWords(AppLocalizations l10n) => (
  ingredients: l10n.ingredients,
  steps: l10n.fieldSteps,
  notes: l10n.notes,
  source: l10n.shareSource,
  or: l10n.substitutesPrefix.toLowerCase(),
);

/// Partage [recipe] pour les portions choisies sur la fiche.
Future<void> shareRecipe(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
  RecipeShare how,
) async {
  final l10n = AppLocalizations.of(context);
  final export = ref.read(exportActionsProvider);
  final factor = ref.read(recipeScaleProvider(recipe.id));
  final title = recipeTitle(l10n, recipe);
  final info = recipeExportInfo(l10n, recipe, factor);
  final words = recipeExportWords(l10n);
  if (how == RecipeShare.text) {
    await export.shareText(
      RecipeExport.text(
        recipe,
        title: title,
        factor: factor,
        info: info,
        words: words,
      ),
      subject: title,
    );
    return;
  }
  final photoName = recipe.mainPhoto;
  final photoFile = photoName == null
      ? null
      : ref.read(photoStoreProvider).file(photoName);
  final photo = photoFile != null && await photoFile.exists()
      ? await photoFile.readAsBytes()
      : null;
  final pdf = await RecipePdf.build(
    title: title,
    info: info,
    description: recipe.description,
    ingredients: RecipeExport.ingredients(recipe, factor, or: words.or),
    steps: RecipeExport.steps(recipe),
    notes: recipe.notes,
    source: recipe.source,
    words: words,
    photo: photo,
  );
  if (how == RecipeShare.pdf) {
    await export.sharePdf(pdf, name: title);
  } else {
    await export.printPdf(pdf, name: title);
  }
}
