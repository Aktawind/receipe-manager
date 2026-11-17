import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Une erreur notée dans le journal.
typedef ErrorEntry = ({
  DateTime at,
  String where,
  String message,
  String stack,
});

/// Le journal des erreurs : un fichier sur l'appareil (aucun service
/// externe), consultable dans Réglages et exportable en texte. Il garde les
/// [maxEntries] dernières erreurs.
class ErrorLog {
  ErrorLog(this._file);

  /// Un journal en mémoire seulement (tests, ou avant l'ouverture de l'app).
  ErrorLog.memory() : _file = null;

  static const fileName = 'journal-erreurs.jsonl';
  static const maxEntries = 200;

  /// Le journal de l'app, ouvert au démarrage (voir `main.dart`).
  static ErrorLog current = ErrorLog.memory();

  final File? _file;
  final _memory = <ErrorEntry>[];

  /// Note une erreur ; [where] dit d'où elle vient (« Synchro », « Partage »…).
  /// N'échoue jamais : un journal qui plante ne doit rien casser.
  void add(String where, Object error, [StackTrace? stack]) {
    final text = '$error';
    debugPrint(
      '$where : ${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
    );
    final entry = (
      at: DateTime.now(),
      where: where,
      message: '$error',
      stack: _shortStack(stack),
    );
    _memory.add(entry);
    if (_memory.length > maxEntries) _memory.removeAt(0);
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(
        '${jsonEncode({'at': entry.at.toUtc().toIso8601String(), 'where': entry.where, 'message': entry.message, 'stack': entry.stack})}\n',
        mode: FileMode.append,
        flush: true,
      );
      _trim(file);
    } on Object catch (e) {
      debugPrint('Journal des erreurs : $e');
    }
  }

  /// Les erreurs notées, la plus récente d'abord.
  List<ErrorEntry> read() {
    final file = _file;
    if (file == null) return _memory.reversed.toList();
    try {
      if (!file.existsSync()) return const [];
      return [
        for (final line in file.readAsLinesSync().reversed) ?_parse(line),
      ];
    } on Object {
      return const [];
    }
  }

  void clear() {
    _memory.clear();
    try {
      final file = _file;
      if (file != null && file.existsSync()) file.deleteSync();
    } on Object catch (e) {
      debugPrint('Journal des erreurs : $e');
    }
  }

  /// Le journal en texte, pour l'envoyer (messagerie, mail).
  static String text(List<ErrorEntry> entries, {required String header}) {
    final out = StringBuffer(header);
    for (final e in entries) {
      out
        ..write('\n\n')
        ..write('${e.at.toLocal().toIso8601String().substring(0, 19)} · ')
        ..write('${e.where}\n${e.message}');
      if (e.stack.isNotEmpty) out.write('\n${e.stack}');
    }
    return out.toString();
  }

  static ErrorEntry? _parse(String line) {
    try {
      final m = jsonDecode(line) as Map<String, Object?>;
      return (
        at: DateTime.parse(m['at']! as String),
        where: m['where'] as String? ?? '',
        message: m['message'] as String? ?? '',
        stack: m['stack'] as String? ?? '',
      );
    } on Object {
      return null;
    }
  }

  /// Les premières lignes de la pile : assez pour retrouver d'où ça vient.
  static String _shortStack(StackTrace? stack) {
    if (stack == null) return '';
    return stack
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(8)
        .join('\n');
  }

  void _trim(File file) {
    // Au-delà d'environ deux fois la limite, on ne garde que les dernières.
    if (file.lengthSync() < 400 * 1024) return;
    final lines = file.readAsLinesSync();
    if (lines.length <= maxEntries) return;
    file.writeAsStringSync(
      '${lines.sublist(lines.length - maxEntries).join('\n')}\n',
      flush: true,
    );
  }
}
