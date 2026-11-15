import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Partager un texte ou un PDF, imprimer un PDF (canal `recettes/export`,
/// `ExportActions.kt`). Remplacé dans les tests.
abstract class ExportActions {
  Future<void> shareText(String text, {String subject = ''});

  /// Ouvre l'impression d'Android (qui propose aussi « Enregistrer au format
  /// PDF ») pour [pdf], nommé [name].
  Future<void> printPdf(Uint8List pdf, {required String name});

  /// Envoie [pdf] à une autre app (messagerie, mail…), en fichier « [name].pdf ».
  Future<void> sharePdf(Uint8List pdf, {required String name});
}

class AndroidExportActions implements ExportActions {
  AndroidExportActions();

  static const _channel = MethodChannel('recettes/export');

  @override
  Future<void> shareText(String text, {String subject = ''}) =>
      _call('shareText', {'text': text, 'subject': subject});

  @override
  Future<void> printPdf(Uint8List pdf, {required String name}) async {
    final file = File(
      '${Directory.systemTemp.path}/recettes_courses_'
      '${DateTime.now().microsecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(pdf, flush: true);
    await _call('printPdf', {'path': file.path, 'name': name});
  }

  @override
  Future<void> sharePdf(Uint8List pdf, {required String name}) async {
    // Le nom du fichier est celui que voit la personne qui le reçoit.
    final folder = Directory('${Directory.systemTemp.path}/exports');
    await folder.create(recursive: true);
    final clean = name.replaceAll(RegExp(r'[\\/:*?"<>|\n]'), ' ').trim();
    final file = File(
      '${folder.path}/${clean.isEmpty ? 'recette' : clean}.pdf',
    );
    await file.writeAsBytes(pdf, flush: true);
    await _call('sharePdf', {'path': file.path, 'name': name});
  }

  Future<void> _call(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      debugPrint('ExportActions: pas d\'Android');
    }
  }
}

final exportActionsProvider = Provider<ExportActions>(
  (ref) => AndroidExportActions(),
);
