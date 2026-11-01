/// L'horloge de l'appareil, corrigée par ce qu'il a vu des autres appareils.
///
/// Les dates de modification ordonnent les changements entre appareils. Si
/// l'horloge d'un appareil retarde, ses modifications paraîtraient plus
/// anciennes que celles qu'il vient de recevoir et seraient écartées à tort.
/// [now] ne renvoie donc jamais une date antérieure à la plus récente vue :
/// une modification faite après avoir reçu une autre est toujours plus récente.
class HybridClock {
  HybridClock({DateTime Function()? source, this._lastSeen})
    : _source = source ?? DateTime.now;

  final DateTime Function() _source;
  DateTime? _lastSeen;
  DateTime? _last;

  /// La plus récente date de modification reçue d'un autre appareil.
  DateTime? get lastSeen => _lastSeen;

  /// À appeler pour chaque date de modification reçue.
  void observe(DateTime moment) {
    final current = _lastSeen;
    if (current == null || moment.isAfter(current)) _lastSeen = moment;
  }

  /// La date à donner à une modification qui a lieu maintenant : strictement
  /// croissante, et postérieure à tout ce qui a été reçu.
  DateTime now() {
    var moment = _source();
    final floor = [
      ?_lastSeen,
      ?_last,
    ].fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    if (floor != null && !moment.isAfter(floor)) {
      moment = floor.add(const Duration(milliseconds: 1));
    }
    return _last = moment;
  }
}
