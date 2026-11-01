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
    now = now.add(const Duration(minutes: 9));
    gate.touch();
    now = now.add(const Duration(minutes: 9));
    expect(gate.tryAcquire(), isFalse, reason: 'rafraîchi il y a 9 min');
    now = now.add(const Duration(minutes: 2));
    expect(gate.tryAcquire(), isTrue, reason: 'oublié depuis plus de 10 min');
  });
}
