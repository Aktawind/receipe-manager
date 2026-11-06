import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/shopping_export.dart';

/// La liste de courses en PDF, sur **une seule page A4** : le titre, puis les
/// rayons en colonnes, avec une case à cocher par produit. Les colonnes et la
/// taille du texte sont choisies pour que tout tienne sur la page.
abstract final class ShoppingPdf {
  static const _margin = 32.0;
  static const _titleHeight = 40.0;

  /// Le plan de mise en page : nombre de colonnes et taille du texte.
  static ({int columns, double fontSize}) layoutFor(
    List<ShoppingSection> sections,
  ) {
    final usable = PdfPageFormat.a4.height - 2 * _margin - _titleHeight;
    final rows = [
      for (final s in sections) ...[1.6, for (final _ in s.items) 1.0],
    ];
    for (final columns in [2, 3]) {
      for (var size = 12.0; size >= 7; size -= 0.5) {
        if (_fits(rows, columns, usable / (size * 1.55))) {
          return (columns: columns, fontSize: size);
        }
      }
    }
    return (columns: 3, fontSize: 6.5);
  }

  /// Les lignes ([rows] : hauteur de chacune, en lignes) tiennent-elles dans
  /// [columns] colonnes de [capacity] lignes, un rayon n'étant coupé qu'en
  /// dernier recours ?
  static bool _fits(List<double> rows, int columns, double capacity) =>
      _split(rows, columns, capacity) != null;

  /// Le début de chaque colonne dans [rows], ou `null` si ça ne tient pas.
  static List<int>? _split(List<double> rows, int columns, double capacity) {
    final starts = <int>[0];
    var used = 0.0;
    for (var i = 0; i < rows.length; i++) {
      if (used + rows[i] > capacity) {
        if (starts.length == columns) return null;
        // Un titre de rayon ne reste jamais seul en bas d'une colonne.
        final start = i > 0 && rows[i - 1] > 1 ? i - 1 : i;
        starts.add(start);
        used = 0;
        for (var j = start; j <= i; j++) {
          used += rows[j];
        }
      } else {
        used += rows[i];
      }
    }
    return starts;
  }

  /// Le texte avec les seuls caractères de la police du PDF (Helvetica,
  /// Latin-1) : apostrophes et guillemets typographiques remplacés, « œ » écrit
  /// « oe », emojis retirés.
  static String safe(String text) {
    const replacements = {
      '’': "'",
      '‘': "'",
      '‚': ',',
      '“': '"',
      '”': '"',
      '„': '"',
      '–': '-',
      '—': '-',
      '…': '...',
      'œ': 'oe',
      'Œ': 'Oe',
      '€': 'EUR',
      '\u202f': ' ',
    };
    final out = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (replacements[char] case final r?) {
        out.write(r);
      } else if (rune <= 0xFF) {
        out.write(char);
      }
    }
    return out.toString();
  }

  /// Les lignes de la colonne [c] ([starts] : début de chaque colonne).
  static List<pw.Widget> _column(
    List<pw.Widget> entries,
    List<int> starts,
    int c,
  ) {
    if (c >= starts.length) return const [];
    final end = c + 1 < starts.length ? starts[c + 1] : entries.length;
    return entries.sublist(starts[c], end);
  }

  static Future<Uint8List> build(
    String title,
    List<ShoppingSection> sections,
  ) async {
    final (:columns, :fontSize) = layoutFor(sections);
    // Une ligne par élément : titre de rayon, ou produit.
    final entries = <pw.Widget>[];
    final heights = <double>[];
    for (final section in sections) {
      entries.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(top: fontSize * 0.5, bottom: 2),
          child: pw.Text(
            safe(section.name.toUpperCase()),
            style: pw.TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
      heights.add(1.6);
      for (final item in section.items) {
        entries.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: fontSize * 0.85,
                  height: fontSize * 0.85,
                  margin: pw.EdgeInsets.only(
                    top: fontSize * 0.15,
                    right: fontSize * 0.5,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.7),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    safe(ShoppingExport.line(item)),
                    style: pw.TextStyle(fontSize: fontSize),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
              ],
            ),
          ),
        );
        heights.add(1);
      }
    }
    final usable = PdfPageFormat.a4.height - 2 * _margin - _titleHeight;
    final starts =
        _split(heights, columns, usable / (fontSize * 1.55)) ??
        [for (var c = 0; c < columns; c++) (entries.length * c) ~/ columns];
    final document = pw.Document(title: safe(title));
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              height: _titleHeight,
              child: pw.Text(
                safe(title),
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++)
                    pw.Expanded(
                      child: pw.Padding(
                        padding: pw.EdgeInsets.only(
                          right: c == columns - 1 ? 0 : 16,
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: _column(entries, starts, c),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return document.save();
  }
}
