import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/recipe_export.dart';
import '../shopping/shopping_pdf.dart';

/// Une recette en PDF A4 (sur plusieurs pages si besoin) : la photo carrée et
/// le titre, les portions et les temps, puis les ingrédients, les étapes
/// numérotées, les notes et la source.
abstract final class RecipePdf {
  static String _safe(String text) => ShoppingPdf.safe(text);

  static Future<Uint8List> build({
    required String title,
    required List<String> info,
    required String description,
    required List<ExportIngredient> ingredients,
    required List<({String title, String text})> steps,
    required String notes,
    required String source,
    required RecipeExportWords words,
    Uint8List? photo,
  }) async {
    const body = pw.TextStyle(fontSize: 11, lineSpacing: 2);
    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        _safe(text.toUpperCase()),
        style: const pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );

    final image = photo == null ? null : _image(photo);
    final document = pw.Document(title: _safe(title));
    var number = 0;
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (image != null) ...[
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.SizedBox(
                    width: 130,
                    height: 130,
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(width: 16),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _safe(title),
                      style: const pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (info.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text(
                        _safe(info.join('  ·  ')),
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                    if (description.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text(_safe(description.trim()), style: body),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (ingredients.isNotEmpty) heading(words.ingredients),
          for (final line in ingredients)
            line.section
                ? pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                    child: pw.Text(
                      _safe(line.text),
                      style: const pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  )
                : pw.Bullet(
                    text: _safe(line.text),
                    style: body,
                    margin: const pw.EdgeInsets.only(bottom: 2),
                  ),
          if (steps.isNotEmpty) heading(words.steps),
          for (final step in steps) ...[
            if (step.title.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
                child: pw.Text(
                  _safe(step.title),
                  style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            if (step.text.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 22,
                      child: pw.Text(
                        '${++number}.',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(child: pw.Text(_safe(step.text), style: body)),
                  ],
                ),
              ),
          ],
          if (notes.trim().isNotEmpty) ...[
            heading(words.notes),
            pw.Text(_safe(notes.trim()), style: body),
          ],
          if (source.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              _safe('${words.source} : ${source.trim()}'),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ],
      ),
    );
    return document.save();
  }

  /// La photo, si le PDF sait la lire (JPEG, PNG) ; sinon pas de photo.
  static pw.ImageProvider? _image(Uint8List bytes) {
    try {
      return pw.MemoryImage(bytes);
    } on Object {
      return null;
    }
  }
}
