import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/sync/sync_gate.dart';

void main() {
  late Directory dir;
  late DateTime now;
  late SyncGate gate;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('recettes-gate');
    now = DateTime.utc(2035, 1, 1, 10);
    gate = SyncGate(File('${dir.path}/sync.lock'), now: () => now);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('une seule synchro à la fois', () {
    expect(gate.tryAcquire(), isTrue);
    expect(gate.tryAcquire(), isFalse);
    gate.release();
    expect(gate.tryAcquire(), isTrue);
  });

  test('un verrou rafraîchi tient, un verrou oublié est ignoré', () {
    expect(gate.tryAcquire(), isTrue);
    now = now.add(const Duration(minutes: 2));
    gate.touch();
    now = now.add(const Duration(minutes: 2));
    expect(gate.tryAcquire(), isFalse, reason: 'rafraîchi il y a 2 min');
    now = now.add(const Duration(minutes: 2));
    expect(gate.tryAcquire(), isTrue, reason: 'oublié depuis plus de 3 min');
  });

  test(
    'l’application reprend son propre verrou, pas celui de l’arrière-plan',
    () {
      final file = File('${dir.path}/sync.lock');
      final app = SyncGate(file, owner: 'app-1', now: () => now);
      final background = SyncGate(file, owner: 'background-1', now: () => now);
      expect(app.tryAcquire(), isTrue);
      // Une synchro de l'application restée bloquée : la suivante passe.
      expect(app.tryAcquire(), isTrue);
      expect(background.tryAcquire(), isFalse);
      app.release();
      expect(background.tryAcquire(), isTrue);
      expect(app.tryAcquire(), isFalse);
      // Un ancien verrou (sans nom) reste respecté.
      file.writeAsStringSync('${now.millisecondsSinceEpoch}');
      expect(app.tryAcquire(), isFalse);
    },
  );
}
