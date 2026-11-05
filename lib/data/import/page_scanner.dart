import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/ocr_layout.dart';

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
      final pages = <List<OcrLine>>[];
      for (final path in images) {
        final lines = await _readPage(recognizer, path);
        if (lines.isNotEmpty) pages.add(lines);
      }
      final text = pages.isEmpty ? '' : OcrLayout.recipeText(pages);
      if (text.trim().isEmpty) {
        throw const PageScanException(PageScanError.noText);
      }
      return text;
    } on PlatformException catch (e) {
      debugPrint('TextRecognizer: $e');
      throw PageScanException(PageScanError.unavailable, e.message ?? e.code);
    } finally {
      unawaited(recognizer.close().catchError((Object _) {}));
    }
  }

  /// Les lignes d'une page, remise droite. Une photo prise sur le côté ou à
  /// l'envers se lit mal : si la lecture est pauvre, l'image est tournée d'un
  /// quart de tour à la fois et la meilleure lecture est gardée.
  static Future<List<OcrLine>> _readPage(
    TextRecognizer recognizer,
    String path,
  ) async {
    var best = await _recognize(recognizer, InputImage.fromFilePath(path));
    if (_isGood(best)) return OcrLayout.upright(best);
    final Uint8List bytes;
    try {
      bytes = await File(path).readAsBytes();
    } on FileSystemException {
      return OcrLayout.upright(best);
    }
    for (final turns in const [1, 2, 3]) {
      final rotated = await _rotate(bytes, turns);
      if (rotated == null) break;
      final lines = await _recognize(recognizer, rotated);
      if (_score(lines) > _score(best)) best = lines;
      if (_isGood(best)) break;
    }
    return OcrLayout.upright(best);
  }

  static Future<List<RawOcrLine>> _recognize(
    TextRecognizer recognizer,
    InputImage image,
  ) async {
    final result = await recognizer.processImage(image);
    return [
      for (final (index, block) in result.blocks.indexed)
        for (final line in block.lines)
          if (line.text.trim().isNotEmpty)
            RawOcrLine(
              line.text,
              [
                for (final p in line.cornerPoints)
                  (x: p.x.toDouble(), y: p.y.toDouble()),
              ],
              angle: line.angle,
              block: index,
              confidence: line.confidence,
            ),
    ];
  }

  /// Une lecture bien orientée : des lignes droites, lues avec assurance.
  static bool _isGood(List<RawOcrLine> lines) {
    if (lines.length < 5) return false;
    final angles = [for (final l in lines) l.angle ?? 0.0]..sort();
    final angle = angles[angles.length ~/ 2].abs();
    return angle < 20 && _confidence(lines) >= 0.7;
  }

  static double _confidence(List<RawOcrLine> lines) {
    final known = [
      for (final l in lines)
        if (l.confidence != null) l.confidence!,
    ];
    return known.isEmpty ? 0.8 : known.reduce((a, b) => a + b) / known.length;
  }

  /// Le texte lu, pondéré par l'assurance de la lecture.
  static double _score(List<RawOcrLine> lines) {
    var letters = 0;
    for (final l in lines) {
      letters += RegExp(r'\p{L}', unicode: true).allMatches(l.text).length;
    }
    return letters * _confidence(lines);
  }

  /// L'image tournée de [turns] quarts de tour (sens horaire), en PNG dans
  /// le dossier temporaire ; `null` si elle ne peut pas être décodée.
  static Future<InputImage?> _rotate(Uint8List bytes, int turns) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final source = (await codec.getNextFrame()).image;
      final w = source.width.toDouble();
      final h = source.height.toDouble();
      final sideways = turns.isOdd;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas
        ..translate(sideways ? h / 2 : w / 2, sideways ? w / 2 : h / 2)
        ..rotate(turns * math.pi / 2)
        ..translate(-w / 2, -h / 2)
        ..drawImage(source, ui.Offset.zero, ui.Paint());
      final image = await recorder.endRecording().toImage(
        sideways ? source.height : source.width,
        sideways ? source.width : source.height,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      source.dispose();
      image.dispose();
      if (png == null) return null;
      final file = File(
        '${Directory.systemTemp.path}/recettes_page_${turns}_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return InputImage.fromFilePath(file.path);
    } on Object catch (e) {
      debugPrint('Rotation: $e');
      return null;
    }
  }
}
