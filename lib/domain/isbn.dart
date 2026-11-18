/// Les numéros ISBN des livres (le code-barres au dos).
abstract final class Isbn {
  /// L'ISBN-13 de [text] (chiffres seuls, tirets et espaces acceptés ;
  /// un ISBN-10 est converti), ou `null` s'il n'est pas valide.
  static String? normalize(String text) {
    final raw = text.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
    if (raw.length == 13 && _valid13(raw)) return raw;
    if (raw.length == 10 && _valid10(raw)) {
      final base = '978${raw.substring(0, 9)}';
      return '$base${_check13(base)}';
    }
    return null;
  }

  static bool _valid13(String digits) {
    if (!RegExp(r'^\d{13}$').hasMatch(digits)) return false;
    // Un livre : 978 ou 979 (les autres codes EAN ne sont pas des livres).
    if (!digits.startsWith('978') && !digits.startsWith('979')) return false;
    return _check13(digits.substring(0, 12)) == digits[12];
  }

  static String _check13(String first12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(first12[i]) * (i.isEven ? 1 : 3);
    }
    return '${(10 - sum % 10) % 10}';
  }

  static bool _valid10(String text) {
    if (!RegExp(r'^\d{9}[\dX]$').hasMatch(text)) return false;
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      final v = text[i] == 'X' ? 10 : int.parse(text[i]);
      sum += v * (10 - i);
    }
    return sum % 11 == 0;
  }
}
