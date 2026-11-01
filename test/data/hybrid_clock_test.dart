import 'package:flutter_test/flutter_test.dart';
import 'package:recettes/data/sync/hybrid_clock.dart';

void main() {
  test('sans rien reçu, l’horloge suit celle de l’appareil', () {
    final clock = HybridClock(source: () => DateTime.utc(2026, 11, 1, 10));
    expect(clock.now(), DateTime.utc(2026, 11, 1, 10));
  });

  test('toujours strictement croissante, même si l’heure recule', () {
    var moment = DateTime.utc(2026, 11, 1, 10);
    final clock = HybridClock(source: () => moment);
    final first = clock.now();
    moment = DateTime.utc(2026, 11, 1, 9);
    expect(clock.now().isAfter(first), isTrue);
  });

  test('jamais antérieure à ce qui vient d’un autre appareil', () {
    final clock = HybridClock(source: () => DateTime.utc(2026, 11, 1, 10));
    clock.observe(DateTime.utc(2026, 11, 1, 12));
    clock.observe(DateTime.utc(2026, 11, 1, 11)); // plus ancienne : ignorée
    expect(clock.lastSeen, DateTime.utc(2026, 11, 1, 12));
    expect(clock.now().isAfter(DateTime.utc(2026, 11, 1, 12)), isTrue);
  });
}
