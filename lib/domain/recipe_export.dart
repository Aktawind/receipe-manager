import 'ingredient_scaling.dart';
import 'ingredient_text.dart';
import 'recipe.dart';

/// Les mots du partage, dans la langue de l'app.
typedef RecipeExportWords = ({
  String ingredients,
  String steps,
  String notes,
  String source,
  String or,
});

/// Une ligne d'ingrédients à partager : un titre de groupe (« Pâte ») ou un
/// ingrédient (« 250 g de farine »).
typedef ExportIngredient = ({bool section, String text});

/// Une recette prête à partager : en texte (messagerie, mail) ou en PDF.
abstract final class RecipeExport {
  /// Les ingrédients pour [factor] (portions choisies sur la fiche) ; une
  /// recette liée est écrite par son nom, sans crochets.
  static List<ExportIngredient> ingredients(
    Recipe recipe,
    double factor, {
    required String or,
  }) => [
    for (final line in recipe.ingredients)
      if (line.isSection)
        (section: true, text: line.name.trim())
      else if (!line.isBlank)
        (section: false, text: _line(line, factor, or)),
  ];

  static String _line(IngredientLine line, double factor, String or) {
    final scaled = IngredientScaling.scaleLine(line, factor);
    final text = IngredientText.format(
      IngredientLine(
        id: line.id,
        name: line.name,
        quantity: scaled.quantity,
        unit: line.unit,
        note: line.note,
        optional: line.optional,
      ),
    );
    final subs = line.substitutes.trim();
    return subs.isEmpty ? text : '$text ($or ${subs.toLowerCase()})';
  }

  /// Les étapes : le titre de partie éventuel, et le texte sur une ligne.
  static List<({String title, String text})> steps(Recipe recipe) => [
    for (final s in recipe.steps)
      if (s.text.trim().isNotEmpty || s.title.trim().isNotEmpty)
        (
          title: s.title.trim(),
          text: s.text.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim(),
        ),
  ];

  /// Le texte à partager : le titre, [info] (portions, temps), la
  /// description, les ingrédients, les étapes numérotées, les notes et la
  /// source.
  static String text(
    Recipe recipe, {
    required String title,
    required double factor,
    required List<String> info,
    required RecipeExportWords words,
  }) {
    final out = StringBuffer(title);
    if (info.isNotEmpty) out.write('\n${info.join(' · ')}');
    final description = recipe.description.trim();
    if (description.isNotEmpty) out.write('\n\n$description');

    final lines = ingredients(recipe, factor, or: words.or);
    if (lines.isNotEmpty) {
      out.write('\n\n${words.ingredients.toUpperCase()}');
      for (final line in lines) {
        out.write(line.section ? '\n${line.text} :' : '\n- ${line.text}');
      }
    }

    final allSteps = steps(recipe);
    if (allSteps.isNotEmpty) {
      out.write('\n\n${words.steps.toUpperCase()}');
      var number = 0;
      for (final step in allSteps) {
        if (step.title.isNotEmpty) out.write('\n${step.title} :');
        if (step.text.isNotEmpty) out.write('\n${++number}. ${step.text}');
      }
    }

    final notes = recipe.notes.trim();
    if (notes.isNotEmpty) {
      out.write('\n\n${words.notes.toUpperCase()}\n$notes');
    }
    final source = recipe.source.trim();
    if (source.isNotEmpty) out.write('\n\n${words.source} : $source');
    return out.toString();
  }
}
