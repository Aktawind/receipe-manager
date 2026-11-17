import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/core/logging/error_log.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('journal'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('noter, relire (la plus récente d’abord), effacer', () {
    final file = File('${dir.path}/${ErrorLog.fileName}');
    final log = ErrorLog(file)
      ..add('Synchro', Exception('Drive injoignable'), StackTrace.current)
      ..add('Partage', 'fichier refusé');
    // Relu par une autre instance (redémarrage de l'app).
    final entries = ErrorLog(file).read();
    expect([for (final e in entries) e.where], ['Partage', 'Synchro']);
    expect(entries.last.message, contains('Drive injoignable'));
    expect(entries.last.stack, isNotEmpty);
    final text = ErrorLog.text(entries, header: 'Journal');
    expect(text, startsWith('Journal\n\n'));
    expect(text, contains('Partage\nfichier refusé'));
    log.clear();
    expect(ErrorLog(file).read(), isEmpty);
  });

  test('le journal ne garde que les dernières erreurs', () {
    final file = File('${dir.path}/${ErrorLog.fileName}');
    final log = ErrorLog(file);
    final long = 'x' * 3000;
    for (var i = 0; i < 400; i++) {
      log.add('Test', '$i $long');
    }
    final entries = log.read();
    expect(entries.length, lessThanOrEqualTo(ErrorLog.maxEntries * 2));
    expect(entries.first.message, startsWith('399 '));
  });

  test('une ligne abîmée est ignorée', () {
    final file = File('${dir.path}/${ErrorLog.fileName}')
      ..writeAsStringSync('pas du json\n');
    ErrorLog(file).add('Test', 'ok');
    expect([for (final e in ErrorLog(file).read()) e.message], ['ok']);
  });
}
