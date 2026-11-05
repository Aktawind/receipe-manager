import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/domain/ocr_text.dart';

void main() {
  test('confusions de lecture', () {
    expect(OcrText.fixLine('l00 g de sucre'), '100 g de sucre');
    expect(OcrText.fixLine('2O cl de lait'), '20 cl de lait');
    expect(OcrText.fixLine('25O g de beurre'), '250 g de beurre');
    expect(OcrText.fixLine('• 2 œufs'), '- 2 œufs');
    // Les mots ne sont pas touchés.
    expect(OcrText.fixLine('Il faut 10 min.'), 'Il faut 10 min.');
    expect(OcrText.fixLine('Oignons'), 'Oignons');
  });
}
