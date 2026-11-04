import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Pourquoi une page n'a pas pu être lue.
enum PageScanError {
  /// Le scanner de Google Play n'est pas disponible sur l'appareil.
  unavailable,

  /// Aucun texte lisible sur les pages.
  noText,
}

class PageScanException implements Exception {
  const PageScanException(this.error, [this.detail = '']);

  final PageScanError error;
  final String detail;

  @override
  String toString() => 'PageScanException($error, $detail)';
}

/// Photographier des pages (livre, fiche) et en lire le texte, sur
/// l'appareil et hors ligne. Remplacé dans les tests.
abstract class PageScanner {
  /// Ouvre le scanner (cadrage, redressement, plusieurs pages, import depuis
  /// la galerie) ; renvoie les images des pages, `null` si on annule.
  Future<List<String>?> scan();

  /// Le texte des pages, dans l'ordre.
  Future<String> read(List<String> images);
}

class MlKitPageScanner implements PageScanner {
  const MlKitPageScanner();

  @override
  Future<List<String>?> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: const {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: 5,
        isGalleryImport: true,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      return images == null || images.isEmpty ? null : images;
    } on PlatformException catch (e) {
      // Annulation : le scanner renvoie une erreur plutôt qu'un résultat vide.
      if (_isCancel(e)) return null;
      throw PageScanException(PageScanError.unavailable, e.message ?? e.code);
    } on MissingPluginException catch (e) {
      throw PageScanException(PageScanError.unavailable, '$e');
    } finally {
      unawaited(scanner.close().catchError((Object _) {}));
    }
  }

  static bool _isCancel(PlatformException e) {
    final text = '${e.code} ${e.message}'.toLowerCase();
    return text.contains('cancel') || text.contains('annul');
  }

  @override
  Future<String> read(List<String> images) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final pages = <String>[];
      for (final path in images) {
        final result = await recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        if (result.text.trim().isNotEmpty) pages.add(result.text.trim());
      }
      if (pages.isEmpty) throw const PageScanException(PageScanError.noText);
      return pages.join('\n\n');
    } on PlatformException catch (e) {
      debugPrint('TextRecognizer: $e');
      throw PageScanException(PageScanError.unavailable, e.message ?? e.code);
    } finally {
      unawaited(recognizer.close().catchError((Object _) {}));
    }
  }
}
