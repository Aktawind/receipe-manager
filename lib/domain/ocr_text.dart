/// Remise en forme du texte lu sur une photo de page (livre, fiche) avant
/// son analyse comme une recette collée.
///
/// La lecture rend une ligne par ligne imprimée : un ingrédient ou une étape
/// trop longs pour la largeur de la page arrivent en plusieurs morceaux. Une
/// ligne qui commence par une minuscule continue la précédente, et un mot
/// coupé en fin de ligne (« prépa- / ration ») est recollé.
abstract final class OcrText {
  static String clean(String text) {
    final lines = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = fixLine(raw.trim());
      if (line.isEmpty) {
        // Un blanc sépare deux paragraphes : on le garde.
        if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
        continue;
      }
      if (lines.isNotEmpty &&
          lines.last.isNotEmpty &&
          _continues(lines.last, line)) {
        final previous = lines.removeLast();
        lines.add(
          previous.endsWith('-') &&
                  RegExp(r'\p{Ll}-$', unicode: true).hasMatch(previous)
              ? '${previous.substring(0, previous.length - 1)}$line'
              : '$previous $line',
        );
      } else {
        lines.add(line);
      }
    }
    return lines.join('\n').trim();
  }

  /// [line] prolonge [previous] : elle commence par une minuscule (ou une
  /// parenthèse, une virgule), et la précédente ne finit pas une rubrique.
  static bool _continues(String previous, String line) {
    if (previous.endsWith(':')) return false;
    final startsLower = RegExp(r'^\p{Ll}', unicode: true).hasMatch(line);
    // « un », « une » en tête : souvent un nouvel ingrédient (« une pincée »).
    final startsArticle = RegExp(r'^(un|une)\s').hasMatch(line);
    if (previous.endsWith('-') && startsLower) return true;
    if (RegExp(r'^[(,;)]').hasMatch(line)) return true;
    if (startsLower && !startsArticle) return true;
    // Une ligne longue sans ponctuation finale : un paragraphe coupé par la
    // largeur de la page, même si la suite commence par une majuscule.
    return previous.length >= 38 &&
        !RegExp(r'[.!?:;»)]$').hasMatch(previous) &&
        !RegExp(
          r'^([-*•]|\d+[.)]|étape\b)',
          caseSensitive: false,
        ).hasMatch(line);
  }

  /// Confusions fréquentes de la lecture : « l00 g » pour « 100 g »,
  /// « 2O cl » pour « 20 cl », « 1/2 » collé à l'unité.
  static String fixLine(String line) {
    var text = line;
    // Un « l » ou un « O » au milieu de chiffres, ou juste avant une unité.
    text = text.replaceAllMapped(
      RegExp(
        r'(?<![\p{L}])([0-9lIO]{2,4})(?=\s?(g|kg|cl|ml|dl|l|min|°)\b)',
        unicode: true,
      ),
      (m) => RegExp(r'\d').hasMatch(m.group(1)!)
          ? m.group(1)!.replaceAll(RegExp('[lI]'), '1').replaceAll('O', '0')
          : m.group(1)!,
    );
    // « 2OO g » → « 200 g » quand un chiffre précède.
    text = text.replaceAllMapped(RegExp(r'(?<=\d)O|O(?=\d)'), (m) => '0');
    // Puces lues comme des lettres en tête de ligne (« • », « - »).
    text = text.replaceFirst(RegExp(r'^[•·▪■□●◦]\s*'), '- ');
    return text;
  }
}
