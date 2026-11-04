import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Pourquoi une page n'a pas pu être lue.
///
/// Le scanner est celui des services Google Play, appelé par un canal Android maison
/// (`PageScanner.kt`) qui télécharge le module à la demande.
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
  /// [onDownload] reçoit l'avancement (0 à 100) quand Google télécharge le
  /// scanner, et `null` quand il s'ouvre.
  Future<List<String>?> scan({void Function(int? percent)? onDownload});

  /// Sans le scanner de Google : une photo prise avec l'appareil photo, ou une
  /// ou plusieurs images de la galerie ; `null` si on annule.
  Future<List<String>?> pick({required bool camera});

  /// Le texte des pages, dans l'ordre.
  Future<String> read(List<String> images);
}

class MlKitPageScanner implements PageScanner {
  const MlKitPageScanner();

  static const _channel = MethodChannel('recettes/scanner');

  @override
  Future<List<String>?> scan({void Function(int? percent)? onDownload}) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'status' || call.arguments is! String) return;
      final status = call.arguments as String;
      if (status.startsWith('download:')) {
        onDownload?.call(int.tryParse(status.substring('download:'.length)));
      } else {
        onDownload?.call(null);
      }
    });
    try {
      final pages = await _channel.invokeListMethod<String>('scan', {
        'pageLimit': 5,
      });
      return pages == null || pages.isEmpty ? null : pages;
    } on PlatformException catch (e) {
      throw PageScanException(
        PageScanError.unavailable,
        [e.code, e.message].whereType<String>().join(' : '),
      );
    } on MissingPluginException catch (e) {
      throw PageScanException(PageScanError.unavailable, '$e');
    }
  }

  @override
  Future<List<String>?> pick({required bool camera}) async {
    final picker = ImagePicker();
    // Assez de détails pour lire le texte, sans garder une photo énorme.
    const maxSide = 3000.0;
    if (camera) {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: maxSide,
        maxHeight: maxSide,
      );
      return photo == null ? null : [photo.path];
    }
    final images = await picker.pickMultiImage(
      maxWidth: maxSide,
      maxHeight: maxSide,
    );
    return images.isEmpty ? null : [for (final image in images) image.path];
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
