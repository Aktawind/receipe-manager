/// Corrections des confusions de la lecture d'une page (OCR), ligne par
/// ligne, avant que `OcrLayout` n'en reconstitue la recette.
abstract final class OcrText {
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
