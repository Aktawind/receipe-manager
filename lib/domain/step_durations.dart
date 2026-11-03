import '../core/format/text_search.dart';

/// Les durées citées dans une étape de préparation (« cuire 20 minutes »,
/// « 1 h 30 », « une demi-heure »), pour lancer un minuteur d'un appui.
abstract final class StepDurations {
  static const _number = r'(\d+(?:[.,]\d+)?)';

  // « 1 h 30 », « 1h30 », « 2 heures », « 1 heure 15 min », « 1 h 30 min ».
  static final _hours = RegExp(
    '\\b$_number\\s?(?:h|heures?)(?:\\s?(\\d{1,2})(?:\\s?(?:min(?:utes?)?|mn))?)?'
    r'(?:\s+et\s+(demie|quart))?(?![a-z])',
  );

  // « 20 minutes », « 10 à 15 min », « 5-8 mn ».
  static final _minutes = RegExp(
    '\\b$_number(?:\\s?(?:a|-|–|ou)\\s?\\d+)?\\s?(?:minutes?|min|mn)(?![a-z])',
  );

  // « 30 secondes », « 45 s ».
  static final _seconds = RegExp(
    '\\b$_number(?:\\s?(?:a|-|–|ou)\\s?\\d+)?\\s?(?:secondes?|sec|s)(?![a-z])',
  );

  static final _words = <RegExp, Duration>{
    RegExp(r"\bun quart d'heure\b"): const Duration(minutes: 15),
    RegExp(r"\btrois quarts d'heure\b"): const Duration(minutes: 45),
    RegExp(r'\bune demi-heure\b'): const Duration(minutes: 30),
    RegExp(r'\bune heure et demie\b'): const Duration(minutes: 90),
    RegExp(r'\bune heure\b(?! et demie)'): const Duration(hours: 1),
  };

  /// Les durées de [text], dans l'ordre où elles apparaissent, sans doublon.
  /// Pour une fourchette (« 10 à 15 min »), la plus courte : on vérifie la
  /// cuisson au premier signal.
  static List<Duration> find(String text) {
    final normalized = normalizeForSearch(text).replaceAll('’', "'");
    final found = <(int, Duration)>[];
    final taken = <(int, int)>[];

    bool overlaps(Match m) => taken.any((t) => m.start < t.$2 && m.end > t.$1);

    void add(Match m, Duration d) {
      if (d <= Duration.zero || d > const Duration(hours: 48)) return;
      taken.add((m.start, m.end));
      found.add((m.start, d));
    }

    for (final entry in _words.entries) {
      for (final m in entry.key.allMatches(normalized)) {
        if (!overlaps(m)) add(m, entry.value);
      }
    }
    for (final m in _hours.allMatches(normalized)) {
      if (overlaps(m)) continue;
      var minutes = (_parse(m.group(1)!) * 60).round();
      if (m.group(2) != null) minutes += int.parse(m.group(2)!);
      if (m.group(3) == 'demie') minutes += 30;
      if (m.group(3) == 'quart') minutes += 15;
      add(m, Duration(minutes: minutes));
    }
    for (final m in _minutes.allMatches(normalized)) {
      if (overlaps(m)) continue;
      add(m, Duration(seconds: (_parse(m.group(1)!) * 60).round()));
    }
    for (final m in _seconds.allMatches(normalized)) {
      if (overlaps(m)) continue;
      add(m, Duration(seconds: _parse(m.group(1)!).round()));
    }

    found.sort((a, b) => a.$1.compareTo(b.$1));
    final result = <Duration>[];
    for (final (_, d) in found) {
      if (!result.contains(d)) result.add(d);
    }
    return result;
  }

  static double _parse(String value) =>
      double.parse(value.replaceAll(',', '.'));
}
