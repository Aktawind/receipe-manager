/// Normalise un texte pour la recherche : minuscules, sans accents.
String normalizeForSearch(String input) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    if (index < 0) {
      buffer.write(char);
    } else if (char == 'œ') {
      buffer.write('oe');
    } else if (char == 'æ') {
      buffer.write('ae');
    } else {
      buffer.write(to[index]);
    }
  }
  return buffer.toString();
}

/// Met la première lettre en majuscule : « moule à cake » → « Moule à cake ».
String capitalizeFirst(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}
